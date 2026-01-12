---
name: data-management
description: Data management patterns for Ballee including zero-downtime migrations, backups, GDPR compliance, soft delete, and data versioning with Supabase. Use when handling data retention, user data requests, or schema migrations.
tools: Read, Glob, Grep, Bash
---

# Data Management Patterns

Patterns for data migrations, backups, retention, compliance, and versioning with Supabase.

## Quick Reference

```sql
-- Zero-downtime column rename (expand-contract)
-- Phase 1: Add new column
ALTER TABLE users ADD COLUMN full_name TEXT;

-- Phase 2: Backfill data
UPDATE users SET full_name = name WHERE full_name IS NULL;

-- Phase 3: Sync trigger (keeps both in sync during transition)
CREATE TRIGGER sync_name BEFORE INSERT OR UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION sync_user_name();

-- Phase 4: Deploy code using new column
-- Phase 5: Remove old column after all services migrated
```

## When to Use

- Renaming columns or tables without downtime
- Migrating large tables with millions of rows
- Implementing GDPR/CCPA data export or deletion
- Setting up soft delete for recoverable data
- Creating audit trails for compliance
- Backing up or restoring data

## Zero-Downtime Migrations

### Expand-Contract Pattern

Safe schema changes without downtime:

```
Phase 1: EXPAND - Add new structure alongside old
Phase 2: MIGRATE - Copy/transform data
Phase 3: SWITCH - Update application to use new structure
Phase 4: CONTRACT - Remove old structure
```

### Example: Renaming a Column

```sql
-- Migration: 20240115_rename_name_to_full_name.sql

-- Phase 1: EXPAND - Add new column
ALTER TABLE users ADD COLUMN IF NOT EXISTS full_name TEXT;

-- Phase 2: MIGRATE - Copy data (batch for large tables)
UPDATE users SET full_name = name WHERE full_name IS NULL;

-- Phase 3: Create sync trigger for transition period
CREATE OR REPLACE FUNCTION sync_user_name()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.full_name IS NULL AND NEW.name IS NOT NULL THEN
    NEW.full_name := NEW.name;
  ELSIF NEW.name IS NULL AND NEW.full_name IS NOT NULL THEN
    NEW.name := NEW.full_name;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_user_name_trigger
  BEFORE INSERT OR UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION sync_user_name();

-- Phase 4: After deploying code that uses full_name
-- Migration: 20240120_drop_name_column.sql
DROP TRIGGER IF EXISTS sync_user_name_trigger ON users;
DROP FUNCTION IF EXISTS sync_user_name();
ALTER TABLE users DROP COLUMN IF EXISTS name;
```

### Large Table Migrations (Batched)

For tables with millions of rows, batch to avoid locking:

```sql
-- Batch migration function
CREATE OR REPLACE FUNCTION migrate_users_batch(batch_size INT DEFAULT 10000)
RETURNS INT AS $$
DECLARE
  affected INT := 0;
  total INT := 0;
BEGIN
  LOOP
    UPDATE users
    SET full_name = name
    WHERE id IN (
      SELECT id FROM users
      WHERE full_name IS NULL AND name IS NOT NULL
      LIMIT batch_size
      FOR UPDATE SKIP LOCKED
    );

    GET DIAGNOSTICS affected = ROW_COUNT;
    total := total + affected;

    EXIT WHEN affected = 0;

    -- Allow other transactions to proceed
    PERFORM pg_sleep(0.1);
  END LOOP;

  RETURN total;
END;
$$ LANGUAGE plpgsql;

-- Run migration
SELECT migrate_users_batch(10000);
```

## Backup and Recovery

### Supabase Backup Strategy

```
Tier 1: Point-in-Time Recovery (PITR)
- Automatic with Pro plan
- Recovery to any point in last 7 days
- Use for: Accidental deletes, data corruption

Tier 2: Daily Database Dumps
- Manual via Supabase Dashboard or CLI
- Download and store externally
- Use for: Disaster recovery, audits

Tier 3: Table-Level Exports
- Export specific tables as CSV/JSON
- Use for: Data migration, reporting
```

### Manual Backup Script

```bash
#!/bin/bash
# scripts/backup-database.sh

set -euo pipefail

# Load credentials from .env.local
source .env.local

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups"
BACKUP_FILE="${BACKUP_DIR}/ballee_${DATE}.sql.gz"

mkdir -p "${BACKUP_DIR}"

# Dump database
echo "Creating backup: ${BACKUP_FILE}"
PGPASSWORD="${SUPABASE_DB_PASSWORD_PROD}" pg_dump \
  -h "${SUPABASE_DB_HOST_PROD}" \
  -U postgres \
  -d postgres \
  --no-owner \
  --no-privileges \
  | gzip > "${BACKUP_FILE}"

# Verify backup
if ! gzip -t "${BACKUP_FILE}"; then
  echo "ERROR: Backup verification failed"
  rm -f "${BACKUP_FILE}"
  exit 1
fi

echo "Backup complete: $(du -h ${BACKUP_FILE} | cut -f1)"

# Upload to storage (optional)
# aws s3 cp "${BACKUP_FILE}" "s3://backups/ballee/${BACKUP_FILE}"
```

### Table-Level Recovery

```sql
-- Restore specific records from backup
-- 1. Create temp table from backup data
CREATE TEMP TABLE restored_events AS
SELECT * FROM events WHERE FALSE; -- Empty table with same structure

-- 2. Copy data from backup file
\copy restored_events FROM 'events_backup.csv' WITH CSV HEADER;

-- 3. Merge recovered data (insert missing, update existing)
INSERT INTO events
SELECT * FROM restored_events
WHERE id NOT IN (SELECT id FROM events)
ON CONFLICT (id) DO NOTHING;

-- 4. Cleanup
DROP TABLE restored_events;
```

## Data Retention Policies

### Ballee Retention Configuration

| Table | Retention | Soft Delete | Archive |
|-------|-----------|-------------|---------|
| `users` | Indefinite | Yes | No |
| `accounts` | Indefinite | Yes | No |
| `events` | Indefinite | Yes | No |
| `venues` | Indefinite | Yes | No |
| `sessions` | 90 days | No | No |
| `audit_logs` | 2 years | No | Yes |
| `notifications` | 30 days after read | No | No |
| `password_reset_tokens` | 24 hours | No | No |

### Automated Cleanup Function

```sql
-- Create cleanup function
CREATE OR REPLACE FUNCTION cleanup_expired_data()
RETURNS TABLE(table_name TEXT, deleted_count BIGINT) AS $$
DECLARE
  count BIGINT;
BEGIN
  -- Sessions: delete after 90 days
  DELETE FROM auth.sessions
  WHERE created_at < NOW() - INTERVAL '90 days';
  GET DIAGNOSTICS count = ROW_COUNT;
  IF count > 0 THEN
    table_name := 'sessions'; deleted_count := count; RETURN NEXT;
  END IF;

  -- Read notifications: delete after 30 days
  DELETE FROM notifications
  WHERE read_at IS NOT NULL
  AND read_at < NOW() - INTERVAL '30 days';
  GET DIAGNOSTICS count = ROW_COUNT;
  IF count > 0 THEN
    table_name := 'notifications'; deleted_count := count; RETURN NEXT;
  END IF;

  -- Password reset tokens: delete after 24 hours
  DELETE FROM password_reset_tokens
  WHERE created_at < NOW() - INTERVAL '24 hours';
  GET DIAGNOSTICS count = ROW_COUNT;
  IF count > 0 THEN
    table_name := 'password_reset_tokens'; deleted_count := count; RETURN NEXT;
  END IF;

  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule with pg_cron (Supabase Pro feature)
SELECT cron.schedule('cleanup-expired-data', '0 3 * * *', 'SELECT * FROM cleanup_expired_data()');
```

## GDPR/CCPA Compliance

### User Data Export (Right to Access)

```typescript
// lib/services/gdpr-export.service.ts
import { getSupabaseServerClient } from '@kit/supabase/server-client';

interface UserDataExport {
  user: UserProfile;
  account: Account;
  events: Event[];
  assignments: Assignment[];
  payments: Payment[];
  notifications: Notification[];
  auditLogs: AuditLogEntry[];
  exportedAt: Date;
}

export async function exportUserData(userId: string): Promise<UserDataExport> {
  const client = getSupabaseServerClient();

  // Parallel fetch all user data
  const [user, account, events, assignments, payments, notifications, auditLogs] =
    await Promise.all([
      client.from('users').select('*').eq('id', userId).single(),
      client.from('accounts').select('*').eq('primary_owner_user_id', userId).single(),
      client.from('events').select('*').eq('created_by', userId),
      client.from('assignments').select('*').eq('dancer_id', userId),
      client.from('payments').select('*').eq('dancer_id', userId),
      client.from('notifications').select('*').eq('user_id', userId),
      client.from('audit_logs').select('*').eq('user_id', userId),
    ]);

  return {
    user: sanitizeForExport(user.data),
    account: account.data,
    events: events.data || [],
    assignments: assignments.data || [],
    payments: payments.data || [],
    notifications: notifications.data || [],
    auditLogs: auditLogs.data || [],
    exportedAt: new Date(),
  };
}

function sanitizeForExport(user: any): UserProfile {
  // Remove internal fields
  const { password_hash, internal_notes, ...exportable } = user;
  return exportable;
}
```

### User Data Deletion (Right to Erasure)

```typescript
// lib/services/gdpr-delete.service.ts
interface DeletionResult {
  userId: string;
  tablesProcessed: string[];
  anonymizedFields: string[];
  deletedAt: Date;
  retainedForLegal: string[];
}

export async function deleteUserData(
  userId: string,
  options: { hardDelete?: boolean } = {}
): Promise<DeletionResult> {
  const client = getSupabaseServerClient();
  const processed: string[] = [];
  const anonymized: string[] = [];

  // Use transaction for consistency
  const { error } = await client.rpc('delete_user_data', {
    p_user_id: userId,
    p_hard_delete: options.hardDelete ?? false,
  });

  if (error) throw error;

  return {
    userId,
    tablesProcessed: processed,
    anonymizedFields: anonymized,
    deletedAt: new Date(),
    retainedForLegal: ['audit_logs', 'payments'], // Legal/financial records
  };
}
```

```sql
-- Database function for user deletion
CREATE OR REPLACE FUNCTION delete_user_data(
  p_user_id UUID,
  p_hard_delete BOOLEAN DEFAULT FALSE
) RETURNS VOID AS $$
BEGIN
  IF p_hard_delete THEN
    -- Hard delete user (cascades to related tables)
    DELETE FROM auth.users WHERE id = p_user_id;
  ELSE
    -- Soft delete with anonymization
    UPDATE users SET
      email = 'deleted_' || p_user_id || '@anonymized.local',
      display_name = 'Deleted User',
      phone_number = NULL,
      avatar_url = NULL,
      deleted_at = NOW()
    WHERE id = p_user_id;

    -- Anonymize audit logs (keep for compliance)
    UPDATE audit_logs SET
      user_email = 'anonymized'
    WHERE user_id = p_user_id;

    -- Delete sessions
    DELETE FROM auth.sessions WHERE user_id = p_user_id;

    -- Delete notification preferences
    DELETE FROM notification_preferences WHERE user_id = p_user_id;
  END IF;

  -- Log the deletion request
  INSERT INTO gdpr_requests (user_id, request_type, processed_at)
  VALUES (p_user_id, 'deletion', NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### Consent Tracking

```sql
-- Consent tracking table
CREATE TABLE IF NOT EXISTS user_consents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL,  -- 'marketing', 'analytics', 'third_party'
  granted BOOLEAN NOT NULL,
  granted_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  ip_address INET,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, consent_type)
);

-- RLS policy
ALTER TABLE user_consents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_consents" ON user_consents
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

## Soft Delete Pattern

Ballee uses soft delete for `venues`, `events`, and `users`.

### Database Schema

```sql
-- Soft delete columns (already exist on many tables)
ALTER TABLE venues ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE venues ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id);

-- Partial index for active records (performance optimization)
CREATE INDEX IF NOT EXISTS idx_venues_active
ON venues(id)
WHERE deleted_at IS NULL;

-- View for active records only
CREATE OR REPLACE VIEW active_venues AS
SELECT * FROM venues WHERE deleted_at IS NULL;
```

### Application Layer

```typescript
// lib/services/soft-delete.service.ts
export class SoftDeleteService<T extends { id: string; deleted_at?: string }> {
  constructor(
    private client: SupabaseClient,
    private tableName: string
  ) {}

  async delete(id: string, deletedBy?: string): Promise<Result<T>> {
    const { data, error } = await this.client
      .from(this.tableName)
      .update({
        deleted_at: new Date().toISOString(),
        deleted_by: deletedBy,
      })
      .eq('id', id)
      .is('deleted_at', null)
      .select()
      .single();

    if (error) return { success: false, error };
    return { success: true, data };
  }

  async restore(id: string): Promise<Result<T>> {
    const { data, error } = await this.client
      .from(this.tableName)
      .update({ deleted_at: null, deleted_by: null })
      .eq('id', id)
      .not('deleted_at', 'is', null)
      .select()
      .single();

    if (error) return { success: false, error };
    return { success: true, data };
  }

  async hardDelete(id: string): Promise<Result<void>> {
    const { error } = await this.client
      .from(this.tableName)
      .delete()
      .eq('id', id);

    if (error) return { success: false, error };
    return { success: true, data: undefined };
  }
}
```

### RLS for Soft Delete

```sql
-- RLS policy that respects soft delete
DROP POLICY IF EXISTS "venues_select" ON venues;
CREATE POLICY "venues_select" ON venues
  FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL  -- Hide soft-deleted records
    OR is_super_admin()  -- Admin can see all
  );

-- Admin-only policy to restore deleted records
DROP POLICY IF EXISTS "venues_update_deleted" ON venues;
CREATE POLICY "venues_update_deleted" ON venues
  FOR UPDATE
  TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());
```

## Data Versioning / Audit Trail

### Audit Log Table

```sql
-- Already exists in Ballee - use for compliance
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  old_data JSONB,
  new_data JSONB,
  changed_fields TEXT[],
  user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_record
ON audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created
ON audit_logs(created_at DESC);
```

### Generic Audit Trigger

```sql
-- Apply to sensitive tables
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
  old_data JSONB;
  new_data JSONB;
  changed_fields TEXT[];
BEGIN
  IF TG_OP = 'DELETE' THEN
    old_data := to_jsonb(OLD);
    new_data := NULL;
  ELSIF TG_OP = 'INSERT' THEN
    old_data := NULL;
    new_data := to_jsonb(NEW);
  ELSE
    old_data := to_jsonb(OLD);
    new_data := to_jsonb(NEW);
    SELECT array_agg(key) INTO changed_fields
    FROM jsonb_each(new_data)
    WHERE new_data->key IS DISTINCT FROM old_data->key;
  END IF;

  INSERT INTO audit_logs (table_name, record_id, action, old_data, new_data, changed_fields, user_id)
  VALUES (TG_TABLE_NAME, COALESCE(NEW.id, OLD.id), TG_OP, old_data, new_data, changed_fields, auth.uid());

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply to payments table (financial compliance)
CREATE TRIGGER audit_payments
  AFTER INSERT OR UPDATE OR DELETE ON payments
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Migration locks table | Long-running UPDATE on large table | Use batched updates with `FOR UPDATE SKIP LOCKED` |
| Backup too large | Table bloat | Run `VACUUM FULL` before backup (causes downtime) |
| Restore fails | Schema mismatch | Ensure target schema matches backup version |
| Soft delete queries slow | Missing partial index | Add `WHERE deleted_at IS NULL` index |
| Audit log grows too fast | High-frequency updates | Only audit significant changes, add debouncing |
| GDPR export timeout | Too much data | Stream export, use background job |
| Cascade delete fails | FK constraints | Check ON DELETE behavior, use soft delete |

## Related Skills

- `database-migration-manager` - Migration file creation
- `rls-policy-generator` - RLS policies for soft delete
- `db-performance-patterns` - Batch operation optimization
- `production-database-query` - Safe production queries

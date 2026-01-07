# Data Management Skill

Patterns for data migrations, backups, retention, compliance, and versioning.

> **Template Usage:** Customize for your database (PostgreSQL, MySQL, etc.), ORM, and compliance requirements.

## Zero-Downtime Data Migrations

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
-- Phase 1: EXPAND - Add new column
ALTER TABLE users ADD COLUMN full_name TEXT;

-- Phase 2: MIGRATE - Copy data
UPDATE users SET full_name = name WHERE full_name IS NULL;

-- Phase 3: TRIGGER - Keep columns in sync during transition
CREATE OR REPLACE FUNCTION sync_user_name()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    IF NEW.full_name IS NULL AND NEW.name IS NOT NULL THEN
      NEW.full_name := NEW.name;
    ELSIF NEW.name IS NULL AND NEW.full_name IS NOT NULL THEN
      NEW.name := NEW.full_name;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_user_name_trigger
  BEFORE INSERT OR UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION sync_user_name();

-- Phase 4: APPLICATION UPDATE
-- Deploy code that writes to both columns, reads from new

-- Phase 5: CONTRACT - Remove old column (after confirming all services migrated)
DROP TRIGGER IF EXISTS sync_user_name_trigger ON users;
DROP FUNCTION IF EXISTS sync_user_name();
ALTER TABLE users DROP COLUMN name;
```

### Large Table Migrations

For tables with millions of rows:

```sql
-- Batch migration to avoid locking
DO $$
DECLARE
  batch_size INT := 10000;
  affected INT;
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
    EXIT WHEN affected = 0;

    -- Allow other transactions to proceed
    PERFORM pg_sleep(0.1);
    COMMIT;
  END LOOP;
END $$;
```

## Backup and Recovery

### Backup Strategy

```
Tier 1: Point-in-Time Recovery (PITR)
- Continuous WAL archiving
- Recovery to any point in last 7-30 days
- Use for: Accidental deletes, data corruption

Tier 2: Daily Snapshots
- Full database dump daily
- Retained for 30-90 days
- Use for: Disaster recovery, new environment setup

Tier 3: Weekly Archives
- Compressed full backup
- Stored in different region/cloud
- Retained for 1-7 years
- Use for: Compliance, legal holds
```

### Backup Scripts

```bash
#!/bin/bash
# backup.sh - Daily backup with retention

set -euo pipefail

DATABASE_URL="${DATABASE_URL:?Missing DATABASE_URL}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup_${DATE}.sql.gz"

# Create backup
echo "Creating backup: ${BACKUP_FILE}"
pg_dump "${DATABASE_URL}" | gzip > "${BACKUP_FILE}"

# Verify backup
if ! gzip -t "${BACKUP_FILE}"; then
  echo "ERROR: Backup verification failed"
  rm -f "${BACKUP_FILE}"
  exit 1
fi

# Calculate checksum
sha256sum "${BACKUP_FILE}" > "${BACKUP_FILE}.sha256"

# Clean old backups
find "${BACKUP_DIR}" -name "backup_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
find "${BACKUP_DIR}" -name "backup_*.sha256" -mtime +${RETENTION_DAYS} -delete

echo "Backup complete: $(du -h ${BACKUP_FILE} | cut -f1)"
```

### Recovery Procedures

```bash
#!/bin/bash
# restore.sh - Restore from backup

set -euo pipefail

BACKUP_FILE="${1:?Usage: restore.sh <backup_file>}"
DATABASE_URL="${DATABASE_URL:?Missing DATABASE_URL}"

# Verify checksum
if [ -f "${BACKUP_FILE}.sha256" ]; then
  echo "Verifying checksum..."
  sha256sum -c "${BACKUP_FILE}.sha256"
fi

# Confirm restore
read -p "This will OVERWRITE the database. Continue? (yes/no): " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
  echo "Aborted"
  exit 1
fi

# Restore
echo "Restoring from: ${BACKUP_FILE}"
gunzip -c "${BACKUP_FILE}" | psql "${DATABASE_URL}"

echo "Restore complete"
```

### Table-Level Recovery

```sql
-- Restore specific table from backup
-- 1. Create temp schema
CREATE SCHEMA IF NOT EXISTS recovery;

-- 2. Restore table to recovery schema (from backup)
-- pg_restore -d $DATABASE_URL -n public -t users --schema recovery backup.dump

-- 3. Merge recovered data
INSERT INTO public.users
SELECT * FROM recovery.users
WHERE id NOT IN (SELECT id FROM public.users)
ON CONFLICT (id) DO NOTHING;

-- 4. Cleanup
DROP SCHEMA recovery CASCADE;
```

## Data Retention Policies

### Retention Configuration

```typescript
// retention-config.ts
interface RetentionPolicy {
  table: string;
  retentionDays: number;
  softDelete: boolean;
  archiveBeforeDelete: boolean;
  excludeCondition?: string;
}

const RETENTION_POLICIES: RetentionPolicy[] = [
  // User data - keep indefinitely for active users
  { table: 'users', retentionDays: -1, softDelete: true, archiveBeforeDelete: false },

  // Session data - 90 days
  { table: 'sessions', retentionDays: 90, softDelete: false, archiveBeforeDelete: false },

  // Audit logs - 2 years
  { table: 'audit_logs', retentionDays: 730, softDelete: false, archiveBeforeDelete: true },

  // Analytics events - 1 year
  { table: 'analytics_events', retentionDays: 365, softDelete: false, archiveBeforeDelete: true },

  // Notifications - 30 days after read
  {
    table: 'notifications',
    retentionDays: 30,
    softDelete: false,
    archiveBeforeDelete: false,
    excludeCondition: "read_at IS NULL"
  },
];
```

### Automated Cleanup Job

```sql
-- Cleanup function
CREATE OR REPLACE FUNCTION cleanup_expired_data()
RETURNS TABLE(table_name TEXT, deleted_count BIGINT) AS $$
DECLARE
  policy RECORD;
  count BIGINT;
BEGIN
  -- Sessions: delete after 90 days
  DELETE FROM sessions WHERE created_at < NOW() - INTERVAL '90 days';
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
$$ LANGUAGE plpgsql;

-- Schedule with pg_cron (run daily at 3 AM)
SELECT cron.schedule('cleanup-expired-data', '0 3 * * *', 'SELECT * FROM cleanup_expired_data()');
```

## GDPR/CCPA Compliance

### User Data Export (Right to Access)

```typescript
// data-export.service.ts
interface UserDataExport {
  user: UserProfile;
  sessions: Session[];
  orders: Order[];
  messages: Message[];
  auditLogs: AuditLogEntry[];
  exportedAt: Date;
}

async function exportUserData(userId: string): Promise<UserDataExport> {
  // Parallel fetch all user data
  const [user, sessions, orders, messages, auditLogs] = await Promise.all([
    db.from('users').select('*').eq('id', userId).single(),
    db.from('sessions').select('*').eq('user_id', userId),
    db.from('orders').select('*').eq('user_id', userId),
    db.from('messages').select('*').or(`sender_id.eq.${userId},recipient_id.eq.${userId}`),
    db.from('audit_logs').select('*').eq('user_id', userId),
  ]);

  return {
    user: sanitizeForExport(user.data),
    sessions: sessions.data || [],
    orders: orders.data || [],
    messages: messages.data || [],
    auditLogs: auditLogs.data || [],
    exportedAt: new Date(),
  };
}

function sanitizeForExport(user: any): UserProfile {
  // Remove internal fields, hashed passwords, etc.
  const { password_hash, internal_notes, ...exportable } = user;
  return exportable;
}
```

### User Data Deletion (Right to Erasure)

```typescript
// data-deletion.service.ts
interface DeletionResult {
  userId: string;
  tablesProcessed: string[];
  anonymizedFields: string[];
  deletedAt: Date;
  retainedForLegal: string[];
}

async function deleteUserData(
  userId: string,
  options: { hardDelete?: boolean; retainForLegal?: string[] } = {}
): Promise<DeletionResult> {
  const { hardDelete = false, retainForLegal = [] } = options;
  const processed: string[] = [];
  const anonymized: string[] = [];

  await db.transaction(async (tx) => {
    // 1. Delete/anonymize user profile
    if (hardDelete && !retainForLegal.includes('users')) {
      await tx.from('users').delete().eq('id', userId);
      processed.push('users');
    } else {
      // Anonymize instead of delete
      await tx.from('users').update({
        email: `deleted_${userId}@anonymized.local`,
        name: 'Deleted User',
        phone: null,
        avatar_url: null,
        deleted_at: new Date().toISOString(),
      }).eq('id', userId);
      anonymized.push('email', 'name', 'phone', 'avatar_url');
    }

    // 2. Delete sessions (always safe to hard delete)
    await tx.from('sessions').delete().eq('user_id', userId);
    processed.push('sessions');

    // 3. Anonymize messages (keep for conversation integrity)
    await tx.from('messages').update({
      sender_name: 'Deleted User',
    }).eq('sender_id', userId);
    anonymized.push('messages.sender_name');

    // 4. Keep audit logs for legal/security (anonymize user reference)
    await tx.from('audit_logs').update({
      user_email: 'anonymized',
    }).eq('user_id', userId);
    anonymized.push('audit_logs.user_email');

    // 5. Delete notification preferences
    await tx.from('notification_preferences').delete().eq('user_id', userId);
    processed.push('notification_preferences');
  });

  // Log the deletion for compliance
  await logDeletionRequest(userId, processed, anonymized);

  return {
    userId,
    tablesProcessed: processed,
    anonymizedFields: anonymized,
    deletedAt: new Date(),
    retainedForLegal,
  };
}
```

### Consent Tracking

```sql
-- Consent tracking table
CREATE TABLE IF NOT EXISTS user_consents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_type TEXT NOT NULL,  -- 'marketing', 'analytics', 'third_party'
  granted BOOLEAN NOT NULL,
  granted_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, consent_type)
);

-- Function to update consent
CREATE OR REPLACE FUNCTION update_user_consent(
  p_user_id UUID,
  p_consent_type TEXT,
  p_granted BOOLEAN,
  p_ip_address INET DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
) RETURNS user_consents AS $$
DECLARE
  result user_consents;
BEGIN
  INSERT INTO user_consents (user_id, consent_type, granted, granted_at, revoked_at, ip_address, user_agent)
  VALUES (
    p_user_id,
    p_consent_type,
    p_granted,
    CASE WHEN p_granted THEN NOW() ELSE NULL END,
    CASE WHEN NOT p_granted THEN NOW() ELSE NULL END,
    p_ip_address,
    p_user_agent
  )
  ON CONFLICT (user_id, consent_type) DO UPDATE SET
    granted = EXCLUDED.granted,
    granted_at = CASE WHEN EXCLUDED.granted AND NOT user_consents.granted THEN NOW() ELSE user_consents.granted_at END,
    revoked_at = CASE WHEN NOT EXCLUDED.granted AND user_consents.granted THEN NOW() ELSE user_consents.revoked_at END,
    ip_address = EXCLUDED.ip_address,
    user_agent = EXCLUDED.user_agent
  RETURNING * INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql;
```

## Soft Delete Pattern

### Database Schema

```sql
-- Add soft delete columns to tables
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES users(id);

-- Partial index for active records (improves query performance)
CREATE INDEX IF NOT EXISTS idx_users_active
ON users(id)
WHERE deleted_at IS NULL;

-- View for active records only
CREATE OR REPLACE VIEW active_users AS
SELECT * FROM users WHERE deleted_at IS NULL;
```

### Application Layer

```typescript
// soft-delete.service.ts
class SoftDeleteService<T extends { id: string; deleted_at?: string }> {
  constructor(
    private client: SupabaseClient,
    private tableName: string
  ) {}

  // Soft delete
  async delete(id: string, deletedBy?: string): Promise<Result<T>> {
    const { data, error } = await this.client
      .from(this.tableName)
      .update({
        deleted_at: new Date().toISOString(),
        deleted_by: deletedBy
      })
      .eq('id', id)
      .is('deleted_at', null)  // Only delete if not already deleted
      .select()
      .single();

    if (error) return { success: false, error };
    return { success: true, data };
  }

  // Restore soft-deleted record
  async restore(id: string): Promise<Result<T>> {
    const { data, error } = await this.client
      .from(this.tableName)
      .update({ deleted_at: null, deleted_by: null })
      .eq('id', id)
      .not('deleted_at', 'is', null)  // Only restore if deleted
      .select()
      .single();

    if (error) return { success: false, error };
    return { success: true, data };
  }

  // Hard delete (permanent)
  async hardDelete(id: string): Promise<Result<void>> {
    const { error } = await this.client
      .from(this.tableName)
      .delete()
      .eq('id', id);

    if (error) return { success: false, error };
    return { success: true, data: undefined };
  }

  // Find including deleted
  async findWithDeleted(id: string): Promise<Result<T>> {
    const { data, error } = await this.client
      .from(this.tableName)
      .select('*')
      .eq('id', id)
      .single();

    if (error) return { success: false, error };
    return { success: true, data };
  }
}
```

### RLS for Soft Delete

```sql
-- RLS policy that respects soft delete
DROP POLICY IF EXISTS "users_select" ON users;
CREATE POLICY "users_select" ON users
  FOR SELECT
  TO authenticated
  USING (
    deleted_at IS NULL  -- Hide soft-deleted records
    AND (
      id = auth.uid()  -- Own record
      OR is_super_admin()  -- Admin can see all
    )
  );

-- Admin policy to see deleted records
DROP POLICY IF EXISTS "admin_see_deleted" ON users;
CREATE POLICY "admin_see_deleted" ON users
  FOR SELECT
  TO authenticated
  USING (is_super_admin());  -- No deleted_at filter
```

## Data Versioning

### Audit Trail Pattern

```sql
-- Audit log table
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  old_data JSONB,
  new_data JSONB,
  changed_fields TEXT[],
  user_id UUID REFERENCES users(id),
  user_email TEXT,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_record
ON audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user
ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created
ON audit_logs(created_at DESC);

-- Generic audit trigger function
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
  ELSE -- UPDATE
    old_data := to_jsonb(OLD);
    new_data := to_jsonb(NEW);
    -- Calculate changed fields
    SELECT array_agg(key) INTO changed_fields
    FROM jsonb_each(new_data)
    WHERE new_data->key IS DISTINCT FROM old_data->key;
  END IF;

  INSERT INTO audit_logs (
    table_name, record_id, action,
    old_data, new_data, changed_fields,
    user_id, created_at
  ) VALUES (
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    TG_OP,
    old_data, new_data, changed_fields,
    auth.uid(),
    NOW()
  );

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit trigger to a table
CREATE TRIGGER audit_users
  AFTER INSERT OR UPDATE OR DELETE ON users
  FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
```

### Version History Table Pattern

```sql
-- Version history for specific tables
CREATE TABLE IF NOT EXISTS document_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  version_number INT NOT NULL,
  content JSONB NOT NULL,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  comment TEXT,

  UNIQUE(document_id, version_number)
);

-- Auto-increment version number
CREATE OR REPLACE FUNCTION create_document_version()
RETURNS TRIGGER AS $$
DECLARE
  next_version INT;
BEGIN
  -- Get next version number
  SELECT COALESCE(MAX(version_number), 0) + 1
  INTO next_version
  FROM document_versions
  WHERE document_id = NEW.id;

  -- Create version record
  INSERT INTO document_versions (document_id, version_number, content, created_by)
  VALUES (NEW.id, next_version, to_jsonb(NEW), auth.uid());

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER version_documents
  AFTER UPDATE ON documents
  FOR EACH ROW EXECUTE FUNCTION create_document_version();
```

### Restore from Version

```typescript
// version-restore.service.ts
async function restoreDocumentVersion(
  documentId: string,
  versionNumber: number
): Promise<Result<Document>> {
  // Get the version to restore
  const { data: version, error: versionError } = await db
    .from('document_versions')
    .select('content')
    .eq('document_id', documentId)
    .eq('version_number', versionNumber)
    .single();

  if (versionError || !version) {
    return { success: false, error: new Error('Version not found') };
  }

  // Restore the content (this will trigger a new version)
  const { data, error } = await db
    .from('documents')
    .update(version.content)
    .eq('id', documentId)
    .select()
    .single();

  if (error) return { success: false, error };
  return { success: true, data };
}
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Migration locks table | Long-running UPDATE on large table | Use batched updates with `FOR UPDATE SKIP LOCKED` |
| Backup too large | Table bloat, unvacuumed | Run `VACUUM FULL` before backup |
| Restore fails | Schema mismatch | Ensure target schema matches backup |
| Soft delete queries slow | Missing partial index | Add `WHERE deleted_at IS NULL` index |
| Audit log grows too fast | Too many small updates | Batch updates, add debouncing |
| GDPR export timeout | Too much data | Stream export, use background job |
| Version history bloat | Every field change creates version | Only version on significant changes |

## Related Templates

- See `db-anti-patterns` for query optimization
- See `rls-security` for access control patterns
- See `auth-patterns` for user data protection
- See `background-jobs` for scheduled cleanup tasks
- See `logging-patterns` for audit trail integration

## Customization Guide

1. **Retention Periods**: Adjust based on your legal/compliance requirements
2. **Backup Schedule**: Configure based on RPO (Recovery Point Objective)
3. **GDPR/CCPA**: Add fields specific to your data model
4. **Soft Delete**: Apply only to tables where recovery is needed
5. **Versioning**: Implement only for documents/content that needs history
6. **Audit Triggers**: Apply to sensitive tables only (performance impact)

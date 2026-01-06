# Database Migration Helper Scripts

Collection of bash scripts to help manage and verify database migrations across environments.

## Prerequisites

```bash
# Install PostgreSQL client
brew install postgresql@15

# Install 1Password CLI
brew install 1password-cli
```

## Available Scripts

### 1. check-migration-status.sh

Comprehensive report showing migration counts and latest migrations across all environments.

**Usage:**
```bash
cd apps/web
../../.claude/skills/database-migration-manager/scripts/check-migration-status.sh
```

**Output:**
```
================================
  MIGRATION STATUS REPORT
================================

📁 LOCAL
  Count: 330
  Latest: 20251125140000

🔴 PRODUCTION (csjruhqyqzzqxnfeyiaf)
  Count: 331
  Latest: 20251125140000 | create_client_policy_system

🟡 STAGING (hxpcknyqswetsqmqmeep)
  Count: 330
  Latest: 20251125105211 | allow_dancers_see_assigned_cast_roles

================================
✅ ALL ENVIRONMENTS IN SYNC!
================================
```

**Features:**
- Automatically falls back to transaction mode (port 6543) if session mode fails
- Retrieves credentials from 1Password automatically
- Clear status indicators for each environment
- Sync status summary at the end

### 2. find-missing-migrations.sh

Identifies specific migrations that exist locally but haven't been applied to a remote environment.

**Usage:**
```bash
cd apps/web

# Check production
../../.claude/skills/database-migration-manager/scripts/find-missing-migrations.sh production

# Check staging
../../.claude/skills/database-migration-manager/scripts/find-missing-migrations.sh staging
```

**Output:**
```
🟡 Checking STAGING (hxpcknyqswetsqmqmeep)

=== Migration Status ===
Local migrations: 330
Remote migrations: 329

❌ Missing 1 migration(s) on staging:

  - 20251125140000_create_client_policy_system.sql

To apply missing migrations:

  # Apply to staging (use transaction mode if pool saturated)
  PGPASSWORD="$(op item get rkzjnr5ffy5u6iojnsq3clnmia --fields notesPlain --reveal)" psql \
    "postgresql://postgres.hxpcknyqswetsqmqmeep@aws-1-eu-central-1.pooler.supabase.com:6543/postgres" \
    -f supabase/migrations/20251125140000_create_client_policy_system.sql
```

**Features:**
- Lists specific migration files that are missing
- Provides ready-to-run commands to apply missing migrations
- Handles connection pool saturation automatically (uses port 6543)
- Works for both production and staging

## Connection Mode Handling

Both scripts automatically handle the "MaxClientsInSessionMode" error by:

1. **First attempt**: Session mode (port 5432) for better prepared statement support
2. **Fallback**: Transaction mode (port 6543) if session pool is saturated

This ensures scripts work even during high connection load.

## Error Handling

### 1Password Authentication Failed
```
❌ Failed to retrieve password from 1Password
```
**Solution:** Ensure you're logged into 1Password CLI: `op signin`

### psql Not Found
```
❌ Error: psql not found. Install with: brew install postgresql@15
```
**Solution:** Install PostgreSQL client tools

### Connection Pool Saturated
The scripts automatically switch to transaction mode (port 6543) when this occurs.

## Security Notes

- Passwords are retrieved from 1Password on-demand (never stored)
- Temporary files are cleaned up after execution
- Scripts use read-only queries (SELECT) for verification

## Integration with Skill

These scripts are referenced in the `database-migration-manager` skill documentation and can be invoked during migration workflows.

**Common workflow:**
1. Create migration locally
2. Test with `pnpm supabase:reset`
3. Run `check-migration-status.sh` to verify sync
4. Deploy to staging/production
5. Run `find-missing-migrations.sh` to confirm deployment

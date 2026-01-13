# Changelog - Database Migration Manager Skill

## [1.1.0] - 2025-11-25

### Added

#### Connection Pooler Documentation
- **Session Mode (Port 5432)** vs **Transaction Mode (Port 6543)** comprehensive guide
- Detailed explanation of when to use each mode
- Port 6543 transaction mode as solution for `MaxClientsInSessionMode` errors

#### MaxClientsInSessionMode Troubleshooting Section
- Complete troubleshooting guide for connection pool saturation
- 4 solutions ranked by preference (transaction mode, wait, increase pool, close connections)
- Prevention best practices
- Links to official Supabase documentation

#### Helper Scripts
Created two production-ready bash scripts in `scripts/` directory:

**1. check-migration-status.sh**
- Comprehensive status report across all environments (local, production, staging)
- Auto-retrieves credentials from 1Password
- Automatic fallback to transaction mode if session pool saturated
- Clear sync status indicators

**2. find-missing-migrations.sh**
- Identifies specific migrations missing on remote environments
- Generates ready-to-run commands to apply missing migrations
- Supports both production and staging
- Automatic transaction mode usage for reliability

**3. scripts/README.md**
- Complete documentation for all helper scripts
- Prerequisites, usage examples, error handling
- Security notes and integration guidelines

### Changed

#### Updated Deployment Methods
- All psql deployment commands now include both session mode (default) and transaction mode (fallback) examples
- Production and staging deployment sections restructured for clarity
- Added explicit connection pooler mode explanations

#### Version Bump
- Updated version from `1.0.0` to `1.1.0`
- Added `last_updated: "2025-11-25"` field

#### Improved Documentation
- Clearer separation between session and transaction mode usage
- Better structured troubleshooting section
- Added references to Supabase official documentation

### Technical Details

**Key Learning from Production Issue:**
- Staging database hit "MaxClientsInSessionMode" error on port 5432
- Solution: Switch to transaction mode on port 6543
- Transaction mode bypasses session pool limits by sharing connections
- No impact on migration execution (migrations don't use prepared statements)

**Connection String Format:**
```bash
# Session Mode (Port 5432)
postgresql://postgres.{PROJECT_REF}@aws-1-eu-central-1.pooler.supabase.com:5432/postgres

# Transaction Mode (Port 6543)
postgresql://postgres.{PROJECT_REF}@aws-1-eu-central-1.pooler.supabase.com:6543/postgres
```

**Migration Status on 2025-11-25:**
- Local: 330 migrations
- Production: 331 migrations (1 extra from previous cleanup)
- Staging: 330 migrations (in sync with local)

### References
- [Supabase Discussion: MaxClientsInSessionMode #37571](https://github.com/orgs/supabase/discussions/37571)
- [Supavisor Connection Terminology](https://supabase.com/docs/guides/troubleshooting/supavisor-and-connection-terminology-explained-9pr_ZO)
- [Connection Pooler Deprecation Notice #32755](https://github.com/orgs/supabase/discussions/32755)

---

## [1.0.0] - 2025-11-20

### Initial Release
- Basic migration creation templates
- RLS patterns and security definer functions
- Deployment methods (GitHub Actions, CLI, psql, Dashboard)
- Testing and validation workflows
- Common patterns and troubleshooting

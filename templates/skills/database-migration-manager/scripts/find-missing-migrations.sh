#!/bin/bash
#
# Find Missing Migrations on Remote Environments
#
# Usage:
#   ./find-missing-migrations.sh [production|staging]
#
# Examples:
#   ./find-missing-migrations.sh production
#   ./find-missing-migrations.sh staging
#
# Dependencies:
#   - PostgreSQL client (psql)
#   - 1Password CLI (op)

set -e

export PATH="/usr/local/opt/postgresql@15/bin:$PATH"

# Load credentials from .env.local if available
if [ -f ".env.local" ]; then
    source .env.local
fi

ENVIRONMENT=${1:-staging}

if [ "$ENVIRONMENT" != "production" ] && [ "$ENVIRONMENT" != "staging" ]; then
    echo "❌ Error: Invalid environment. Use 'production' or 'staging'"
    exit 1
fi

# Check dependencies
if ! command -v psql &> /dev/null; then
    echo "❌ Error: psql not found. Install with: brew install postgresql@15"
    exit 1
fi

# Set connection details based on environment
if [ "$ENVIRONMENT" = "production" ]; then
    PROJECT_REF="csjruhqyqzzqxnfeyiaf"
    ONEPASSWORD_ID="kuyspxxlyi2mxg7nfeb6dm3pje"
    echo "🔴 Checking PRODUCTION (csjruhqyqzzqxnfeyiaf)"

    # Try .env.local first, fallback to 1Password
    if [ -n "$SUPABASE_DB_PASSWORD_PRODUCTION" ]; then
        PASSWORD="$SUPABASE_DB_PASSWORD_PRODUCTION"
    elif command -v op &> /dev/null; then
        PASSWORD=$(op item get $ONEPASSWORD_ID --fields notesPlain --reveal 2>&1 | grep -v ERROR | head -1)
    else
        PASSWORD=""
    fi
else
    PROJECT_REF="hxpcknyqswetsqmqmeep"
    ONEPASSWORD_ID="rkzjnr5ffy5u6iojnsq3clnmia"
    echo "🟡 Checking STAGING (hxpcknyqswetsqmqmeep)"

    # Try .env.local first, fallback to 1Password
    if [ -n "$SUPABASE_DB_PASSWORD_STAGING" ]; then
        PASSWORD="$SUPABASE_DB_PASSWORD_STAGING"
    elif command -v op &> /dev/null; then
        PASSWORD=$(op item get $ONEPASSWORD_ID --fields notesPlain --reveal 2>&1 | grep -v ERROR | head -1)
    else
        PASSWORD=""
    fi
fi

if [ -z "$PASSWORD" ]; then
    echo "❌ Failed to retrieve password (check .env.local or install 1Password CLI)"
    exit 1
fi

# Get all remote versions (try session mode, fallback to transaction mode)
PGPASSWORD="$PASSWORD" psql \
  "postgresql://postgres.${PROJECT_REF}@aws-1-eu-central-1.pooler.supabase.com:5432/postgres" \
  -t -A -c "SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;" > /tmp/remote_versions.txt 2>/dev/null || \
PGPASSWORD="$PASSWORD" psql \
  "postgresql://postgres.${PROJECT_REF}@aws-1-eu-central-1.pooler.supabase.com:6543/postgres" \
  -t -A -c "SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;" > /tmp/remote_versions.txt

# Get all local versions (extract just timestamps - first 14 chars)
ls -1 supabase/migrations/*.sql 2>/dev/null | sed 's/supabase\/migrations\///' | cut -d'_' -f1 | sort > /tmp/local_versions.txt

echo ""
echo "=== Migration Status ==="
echo "Local migrations: $(wc -l < /tmp/local_versions.txt | tr -d ' ')"
echo "Remote migrations: $(wc -l < /tmp/remote_versions.txt | tr -d ' ')"
echo ""

# Find missing migrations
MISSING=$(comm -13 /tmp/remote_versions.txt /tmp/local_versions.txt)

if [ -z "$MISSING" ] || [ "$MISSING" = "" ]; then
  echo "✅ No missing migrations - $ENVIRONMENT is up to date!"
else
  MISSING_COUNT=$(echo "$MISSING" | wc -l | tr -d ' ')
  echo "❌ Missing $MISSING_COUNT migration(s) on $ENVIRONMENT:"
  echo ""

  # Show actual filenames for missing migrations
  for version in $MISSING; do
    filename=$(ls supabase/migrations/${version}_*.sql 2>/dev/null)
    if [ -n "$filename" ]; then
      echo "  - $(basename $filename)"
    else
      echo "  - $version (file not found locally)"
    fi
  done

  echo ""
  echo "To apply missing migrations:"
  echo ""
  if [ "$ENVIRONMENT" = "production" ]; then
    echo "  # Apply to production (use transaction mode if pool saturated)"
    echo "  PGPASSWORD=\"\$(op item get $ONEPASSWORD_ID --fields notesPlain --reveal)\" psql \\"
    echo "    \"postgresql://postgres.${PROJECT_REF}@aws-1-eu-central-1.pooler.supabase.com:6543/postgres\" \\"
    echo "    -f supabase/migrations/YYYYMMDDHHMMSS_description.sql"
  else
    echo "  # Apply to staging (use transaction mode if pool saturated)"
    echo "  PGPASSWORD=\"\$(op item get $ONEPASSWORD_ID --fields notesPlain --reveal)\" psql \\"
    echo "    \"postgresql://postgres.${PROJECT_REF}@aws-1-eu-central-1.pooler.supabase.com:6543/postgres\" \\"
    echo "    -f supabase/migrations/YYYYMMDDHHMMSS_description.sql"
  fi
fi

# Cleanup
rm -f /tmp/remote_versions.txt /tmp/local_versions.txt

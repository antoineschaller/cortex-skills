#!/bin/bash
#
# Check Migration Status Across All Environments
#
# Usage:
#   ./check-migration-status.sh
#
# Dependencies:
#   - PostgreSQL client (psql)
#   - 1Password CLI (op)
#   - Access to production and staging credentials

set -e

export PATH="/usr/local/opt/postgresql@15/bin:$PATH"

# Load credentials from .env.local if available
if [ -f ".env.local" ]; then
    source .env.local
fi

echo "================================"
echo "  MIGRATION STATUS REPORT"
echo "================================"
echo ""

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "❌ Error: psql not found. Install PostgreSQL client:"
    echo "   brew install postgresql@15"
    exit 1
fi

echo "📁 LOCAL"
LOCAL_COUNT=$(ls -1 supabase/migrations/*.sql 2>/dev/null | wc -l | tr -d ' ')
LOCAL_LATEST=$(ls -1 supabase/migrations/*.sql 2>/dev/null | tail -1 | sed 's/supabase\/migrations\///' | cut -d'_' -f1)
echo "  Count: $LOCAL_COUNT"
echo "  Latest: $LOCAL_LATEST"
echo ""

echo "🔴 PRODUCTION (csjruhqyqzzqxnfeyiaf)"
# Try .env.local first (using SUPABASE_DB_PASSWORD_PROD), fallback to 1Password with caching
if [ -n "$SUPABASE_DB_PASSWORD_PROD" ]; then
    PROD_PW="$SUPABASE_DB_PASSWORD_PROD"
elif command -v op &> /dev/null; then
    PROD_PW=$(op item get kuyspxxlyi2mxg7nfeb6dm3pje --fields notesPlain --reveal 2>&1 | grep -v ERROR | head -1)
    if [ -n "$PROD_PW" ]; then
        echo "SUPABASE_DB_PASSWORD_PROD=$PROD_PW" >> .env.local
        echo "  ✅ Cached production password to .env.local"
    fi
else
    PROD_PW=""
fi

if [ -z "$PROD_PW" ]; then
    echo "  ❌ Failed to get password (check .env.local or install 1Password CLI)"
else
    # Try session mode first, fallback to transaction mode
    PROD_COUNT=$(PGPASSWORD="$PROD_PW" psql \
      "postgresql://postgres.csjruhqyqzzqxnfeyiaf@aws-1-eu-central-1.pooler.supabase.com:5432/postgres" \
      -t -A -c "SELECT COUNT(*) FROM supabase_migrations.schema_migrations;" 2>&1 || \
      PGPASSWORD="$PROD_PW" psql \
      "postgresql://postgres.csjruhqyqzzqxnfeyiaf@aws-1-eu-central-1.pooler.supabase.com:6543/postgres" \
      -t -A -c "SELECT COUNT(*) FROM supabase_migrations.schema_migrations;" 2>&1)

    PROD_LATEST=$(PGPASSWORD="$PROD_PW" psql \
      "postgresql://postgres.csjruhqyqzzqxnfeyiaf@aws-1-eu-central-1.pooler.supabase.com:6543/postgres" \
      -t -A -c "SELECT version || ' | ' || name FROM supabase_migrations.schema_migrations ORDER BY version DESC LIMIT 1;" 2>&1)

    echo "  Count: $PROD_COUNT"
    echo "  Latest: $PROD_LATEST"
fi
echo ""

echo "🟡 STAGING (hxpcknyqswetsqmqmeep)"
# Try .env.local first (using SUPABASE_DB_PASSWORD_STAGING), fallback to 1Password with caching
if [ -n "$SUPABASE_DB_PASSWORD_STAGING" ]; then
    STAGING_PW="$SUPABASE_DB_PASSWORD_STAGING"
elif command -v op &> /dev/null; then
    STAGING_PW=$(op item get rkzjnr5ffy5u6iojnsq3clnmia --fields notesPlain --reveal 2>&1 | grep -v ERROR | head -1)
    if [ -n "$STAGING_PW" ]; then
        echo "SUPABASE_DB_PASSWORD_STAGING=$STAGING_PW" >> .env.local
        echo "  ✅ Cached staging password to .env.local"
    fi
else
    STAGING_PW=""
fi

if [ -z "$STAGING_PW" ]; then
    echo "  ❌ Failed to get password (check .env.local or install 1Password CLI)"
else
    # Try session mode first, fallback to transaction mode
    STAGING_COUNT=$(PGPASSWORD="$STAGING_PW" psql \
      "postgresql://postgres.hxpcknyqswetsqmqmeep@aws-1-eu-central-1.pooler.supabase.com:5432/postgres" \
      -t -A -c "SELECT COUNT(*) FROM supabase_migrations.schema_migrations;" 2>&1 || \
      PGPASSWORD="$STAGING_PW" psql \
      "postgresql://postgres.hxpcknyqswetsqmqmeep@aws-1-eu-central-1.pooler.supabase.com:6543/postgres" \
      -t -A -c "SELECT COUNT(*) FROM supabase_migrations.schema_migrations;" 2>&1)

    STAGING_LATEST=$(PGPASSWORD="$STAGING_PW" psql \
      "postgresql://postgres.hxpcknyqswetsqmqmeep@aws-1-eu-central-1.pooler.supabase.com:6543/postgres" \
      -t -A -c "SELECT version || ' | ' || name FROM supabase_migrations.schema_migrations ORDER BY version DESC LIMIT 1;" 2>&1)

    echo "  Count: $STAGING_COUNT"
    echo "  Latest: $STAGING_LATEST"
fi
echo ""

echo "================================"
# Clean up counts (remove whitespace and error text)
PROD_COUNT_CLEAN=$(echo "$PROD_COUNT" | grep -o '[0-9]*' | head -1)
STAGING_COUNT_CLEAN=$(echo "$STAGING_COUNT" | grep -o '[0-9]*' | head -1)

if [ "$PROD_COUNT_CLEAN" = "$LOCAL_COUNT" ] && [ "$STAGING_COUNT_CLEAN" = "$LOCAL_COUNT" ]; then
  echo "✅ ALL ENVIRONMENTS IN SYNC!"
elif [ "$PROD_COUNT_CLEAN" = "$LOCAL_COUNT" ]; then
  echo "⚠️  Production in sync, Staging needs update"
elif [ "$STAGING_COUNT_CLEAN" = "$LOCAL_COUNT" ]; then
  echo "⚠️  Staging in sync, Production needs update"
else
  echo "⚠️  Both environments need updates"
  echo "    Local: $LOCAL_COUNT | Production: $PROD_COUNT_CLEAN | Staging: $STAGING_COUNT_CLEAN"
fi
echo "================================"

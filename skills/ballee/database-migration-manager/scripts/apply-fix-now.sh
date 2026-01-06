#!/bin/bash
set -e

# Apply atomic_profile_update fix to production using Supabase Management API

echo "🔧 Applying atomic_profile_update fix to production..."
echo ""

# Get project ref
PROJECT_REF=$(cat supabase/.temp/project-ref)
echo "📡 Project: $PROJECT_REF"

# Get access token
ACCESS_TOKEN=$(cat ~/.config/supabase/access-token)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Error: No Supabase access token found"
  echo "   Run: supabase login"
  exit 1
fi

# Extract just the CREATE FUNCTION statement (without the COMMENT)
MIGRATION_FILE="supabase/migrations/20251012155558_fix_professional_profiles_on_conflict_regression.sql"

echo "📝 Reading migration file..."
echo ""

# Use Management API to execute SQL
echo "⏳ Executing SQL via Supabase Management API..."
echo ""

# Execute using the database query endpoint
RESPONSE=$(curl -s -X POST \
  "https://api.supabase.com/v1/projects/$PROJECT_REF/database/query" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "query": $(cat "$MIGRATION_FILE" | jq -Rs .)
}
EOF
)

# Check response
if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
  echo "❌ Error executing migration:"
  echo "$RESPONSE" | jq -r '.error'
  echo ""
  echo "ℹ️  Alternative: Apply manually via SQL Editor:"
  echo "   https://supabase.com/dashboard/project/$PROJECT_REF/sql/new"
  exit 1
fi

echo "✅ Migration applied successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. Mark migration as applied:"
echo "      pnpm supabase migration repair --status applied 20251012155558"
echo "   2. Test: Have a dancer update their profile"
echo "   3. Monitor logs for errors"
echo ""

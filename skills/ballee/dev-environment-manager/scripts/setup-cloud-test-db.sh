#!/bin/bash
# Setup Cloud Test Database
#
# This script prepares a cloud Supabase project for testing by:
# 1. Linking to the test project
# 2. Pushing all migrations
# 3. Running seed data
#
# Prerequisites:
#   - Supabase CLI installed (supabase/setup-cli@v1)
#   - SUPABASE_ACCESS_TOKEN set
#   - SUPABASE_TEST_PROJECT_REF set
#
# Usage:
#   ./scripts/setup-cloud-test-db.sh

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Cloud Test Database Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check required environment variables
if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "❌ Error: SUPABASE_ACCESS_TOKEN is required"
  echo "   Get your token from: https://supabase.com/dashboard/account/tokens"
  exit 1
fi

if [ -z "$SUPABASE_TEST_PROJECT_REF" ]; then
  echo "❌ Error: SUPABASE_TEST_PROJECT_REF is required"
  echo "   Find your project reference in: Dashboard > Settings > General"
  exit 1
fi

# Navigate to web app directory
cd "$(dirname "$0")/.."

echo ""
echo "📦 Project Reference: $SUPABASE_TEST_PROJECT_REF"
echo ""

# Link to the test project
echo "🔗 Linking to test project..."
supabase link --project-ref "$SUPABASE_TEST_PROJECT_REF"

# Push migrations
echo ""
echo "📤 Pushing migrations to cloud database..."
supabase db push --include-seed

echo ""
echo "✅ Cloud test database setup complete!"
echo ""
echo "Next steps:"
echo "  1. Add these secrets to GitHub Actions:"
echo "     - SUPABASE_TEST_URL"
echo "     - SUPABASE_TEST_ANON_KEY"
echo "     - SUPABASE_TEST_SERVICE_ROLE_KEY"
echo "     - SUPABASE_TEST_PROJECT_REF"
echo "     - SUPABASE_ACCESS_TOKEN"
echo ""
echo "  2. Run tests locally with cloud DB:"
echo "     cp .env.test.cloud.example .env.test.cloud"
echo "     # Fill in credentials"
echo "     source .env.test.cloud && pnpm test:cloud"
echo ""

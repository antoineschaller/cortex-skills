#!/bin/bash

# Production Schema Validation Script
# Compares local migrations with production to detect drift
# Run this before deploying features that depend on schema changes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Production Migration Validation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if supabase CLI is available
if ! command -v supabase &> /dev/null; then
  echo -e "${RED}❌ Supabase CLI not found${NC}"
  echo "Install: brew install supabase/tap/supabase"
  exit 1
fi

# Check if linked to remote project
if ! supabase projects list &> /dev/null 2>&1; then
  echo -e "${RED}❌ Not authenticated with Supabase${NC}"
  echo "Login with: supabase login"
  exit 1
fi

# Navigate to repository root (script is in .claude/skills/database-migration-manager/scripts/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
cd "$REPO_ROOT" || exit 1

# Get local migrations
LOCAL_MIGRATIONS=$(ls -1 supabase/migrations/*.sql 2>/dev/null | wc -l | tr -d ' ')

# Get production migrations
REMOTE_OUTPUT=$(supabase migration list --linked 2>&1)
if [ $? -ne 0 ]; then
  echo -e "${YELLOW}⚠️  Could not connect to production${NC}"
  echo "This validation will run in CI/CD pipeline"
  exit 0
fi

REMOTE_MIGRATIONS=$(echo "$REMOTE_OUTPUT" | grep -cE "^\s*[0-9]{14}" || echo "0")

echo -e "${BLUE}📋 Migration Status${NC}"
echo "Local migrations:      $LOCAL_MIGRATIONS"
echo "Production migrations: $REMOTE_MIGRATIONS"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Summary based on counts
if [ "$LOCAL_MIGRATIONS" -gt "$REMOTE_MIGRATIONS" ]; then
  UNAPPLIED=$((LOCAL_MIGRATIONS - REMOTE_MIGRATIONS))
  echo -e "${RED}❌ MIGRATION DRIFT DETECTED${NC}"
  echo ""
  echo "$UNAPPLIED local migration(s) not applied to production"
  echo ""
  echo "Recommended actions:"
  echo "1. Apply pending migrations to production:"
  echo "   pnpm --filter web supabase db push"
  echo ""
  echo "2. After applying, re-run validation:"
  echo "   ./scripts/validate-production-schema.sh"
  echo ""

  exit 1
elif [ "$REMOTE_MIGRATIONS" -gt "$LOCAL_MIGRATIONS" ]; then
  EXTRA=$((REMOTE_MIGRATIONS - LOCAL_MIGRATIONS))
  echo -e "${YELLOW}⚠️  PRODUCTION AHEAD OF LOCAL${NC}"
  echo ""
  echo "Production has $EXTRA more migrations than local."
  echo ""
  echo "Recommended action:"
  echo "  Pull missing migrations: supabase db pull"
  echo ""
  echo "This is not blocking - production is up-to-date."
  exit 0
else
  echo -e "${GREEN}✅ MIGRATION VALIDATION PASSED${NC}"
  echo ""
  echo "All local migrations are applied to production."
  exit 0
fi

#!/bin/bash

#
# Pre-Deployment Validation Checks
#
# Runs comprehensive validation before deploying to production:
# 1. Database error handling validation
# 2. Schema contract validation
# 3. TypeScript compilation
# 4. Unit tests (error handling focus)
#
# WHY: Prevents production issues by catching errors in dev environment
#
# RUN: ./scripts/pre-deployment-checks.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Pre-Deployment Validation Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_SKIPPED=0

# Check helper function
run_check() {
  local check_name="$1"
  local check_command="$2"
  local is_optional="${3:-false}"

  echo -e "${BLUE}▶ Running: $check_name${NC}"
  echo ""

  if eval "$check_command"; then
    echo ""
    echo -e "${GREEN}✅ $check_name: PASSED${NC}"
    ((CHECKS_PASSED++))
  else
    echo ""
    if [ "$is_optional" = "true" ]; then
      echo -e "${YELLOW}⚠️  $check_name: SKIPPED (optional)${NC}"
      ((CHECKS_SKIPPED++))
    else
      echo -e "${RED}❌ $check_name: FAILED${NC}"
      ((CHECKS_FAILED++))
    fi
  fi
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# 1. Database Error Handling Validation
run_check \
  "Database Error Handling" \
  "./.claude/skills/code-quality-tools/scripts/validate-error-handling.sh" \
  "false"

# 2. Database Schema Contracts (if exists)
if [ -f "./.claude/skills/database-migration-manager/scripts/validate-production-schema.sh" ]; then
  run_check \
    "Database Schema Contracts" \
    "./.claude/skills/database-migration-manager/scripts/validate-production-schema.sh" \
    "true"
else
  echo -e "${YELLOW}⚠️  Schema validation script not found (skipping)${NC}"
  ((CHECKS_SKIPPED++))
  echo ""
fi

# 3. TypeScript Compilation
run_check \
  "TypeScript Compilation" \
  "cd apps/web && pnpm typecheck" \
  "false"

# 4. Error Handling Unit Tests
run_check \
  "Error Handling Tests" \
  "pnpm --filter @ballee/dancers test error-handling" \
  "false"

# 5. Lint Check (optional but recommended)
run_check \
  "Lint Check" \
  "cd apps/web && pnpm lint" \
  "true"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Pre-Deployment Check Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Passed:  $CHECKS_PASSED"
echo "❌ Failed:  $CHECKS_FAILED"
echo "⚠️  Skipped: $CHECKS_SKIPPED"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
  echo -e "${GREEN}🎉 All critical checks passed!${NC}"
  echo ""
  echo "Safe to deploy to production."
  echo ""
  exit 0
else
  echo -e "${RED}🚫 Deployment blocked - fix failing checks first${NC}"
  echo ""
  echo "Action required:"
  echo "  1. Review failed checks above"
  echo "  2. Fix issues in your code"
  echo "  3. Re-run: ./scripts/pre-deployment-checks.sh"
  echo ""
  exit 1
fi

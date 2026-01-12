#!/usr/bin/env bash
# Generic code quality check script
#
# Runs all quality checks in sequence: typecheck, lint, format, test
# Useful as a universal quality gate before commits or in CI/CD pipelines.
#
# Usage:
#   ./code-quality-check.sh [project-root]
#   ./code-quality-check.sh  # Uses current directory
#
# Environment Variables:
#   SKIP_TYPECHECK - Set to 1 to skip TypeScript type checking
#   SKIP_LINT - Set to 1 to skip linting
#   SKIP_FORMAT - Set to 1 to skip format checking
#   SKIP_TESTS - Set to 1 to skip tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT=${1:-.}
SKIP_TYPECHECK=${SKIP_TYPECHECK:-0}
SKIP_LINT=${SKIP_LINT:-0}
SKIP_FORMAT=${SKIP_FORMAT:-0}
SKIP_TESTS=${SKIP_TESTS:-0}

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Code Quality Check${NC}"
echo -e "${BLUE}  Project: $PROJECT_ROOT${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

cd "$PROJECT_ROOT"

ERRORS=0

# 1. TypeScript type checking
if [ "$SKIP_TYPECHECK" != "1" ]; then
  echo -e "${BLUE}1️⃣  Running TypeScript type check...${NC}"
  if npm run typecheck 2>&1; then
    echo -e "${GREEN}✅ TypeScript: No type errors${NC}\n"
  else
    echo -e "${RED}❌ TypeScript: Type errors found${NC}\n"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo -e "${YELLOW}⏭️  Skipping TypeScript type check${NC}\n"
fi

# 2. Linting
if [ "$SKIP_LINT" != "1" ]; then
  echo -e "${BLUE}2️⃣  Running lint check...${NC}"
  if npm run lint 2>&1; then
    echo -e "${GREEN}✅ Lint: No issues${NC}\n"
  else
    echo -e "${RED}❌ Lint: Issues found${NC}\n"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo -e "${YELLOW}⏭️  Skipping lint check${NC}\n"
fi

# 3. Format checking
if [ "$SKIP_FORMAT" != "1" ]; then
  echo -e "${BLUE}3️⃣  Running format check...${NC}"
  # Try both common format check commands
  if npm run format:check 2>&1 || npm run format -- --check 2>&1; then
    echo -e "${GREEN}✅ Format: All files formatted correctly${NC}\n"
  else
    echo -e "${RED}❌ Format: Formatting issues found${NC}\n"
    echo -e "${YELLOW}   Run: npm run format (or npm run format:fix)${NC}\n"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo -e "${YELLOW}⏭️  Skipping format check${NC}\n"
fi

# 4. Tests
if [ "$SKIP_TESTS" != "1" ]; then
  echo -e "${BLUE}4️⃣  Running tests...${NC}"
  if npm test 2>&1; then
    echo -e "${GREEN}✅ Tests: All tests passed${NC}\n"
  else
    echo -e "${RED}❌ Tests: Test failures${NC}\n"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo -e "${YELLOW}⏭️  Skipping tests${NC}\n"
fi

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
if [ $ERRORS -gt 0 ]; then
  echo -e "${RED}❌ Quality check failed with $ERRORS error(s)${NC}"
  exit 1
else
  echo -e "${GREEN}✅ All quality checks passed!${NC}"
  exit 0
fi

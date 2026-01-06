#!/usr/bin/env bash
#
# Validate Query Columns Script
#
# Validates that all database column references in service files match
# the actual database schema defined in database.types.ts
#
# Can be called directly or via symlink from apps/web/scripts/

set -euo pipefail

# Resolve actual script location (following symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Find repo root by looking for package.json
REPO_ROOT="$(cd "$SCRIPT_DIR" && while [ ! -f "package.json" ] && [ "$(pwd)" != "/" ]; do cd ..; done; pwd)"
APPS_WEB="$REPO_ROOT/apps/web"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$APPS_WEB"

if [ ! -f "lib/database.types.ts" ]; then
  echo -e "${YELLOW}⚠️  database.types.ts not found${NC}"
  echo "ℹ️  Run: pnpm supabase:typegen"
  exit 0
fi

# The validate-query-columns.ts is in the same directory as this script
VALIDATOR_SCRIPT="$SCRIPT_DIR/validate-query-columns.ts"

if [ ! -f "$VALIDATOR_SCRIPT" ]; then
  echo -e "${RED}❌ Validation script not found at $VALIDATOR_SCRIPT${NC}"
  exit 2
fi

echo "🔍 Validating query column references..."

if npx tsx "$VALIDATOR_SCRIPT"; then
  echo -e "${GREEN}✅ Query column validation passed${NC}"
  exit 0
else
  exit_code=$?
  echo -e "${RED}❌ Query column validation failed${NC}"
  echo "💡 Fix invalid column references or update schema"
  echo "💡 To bypass: git commit --no-verify"
  exit $exit_code
fi

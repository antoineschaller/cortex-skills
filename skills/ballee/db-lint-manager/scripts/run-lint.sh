#!/bin/bash
# run-lint.sh - Run supabase db lint on specified environment
#
# Usage:
#   ./run-lint.sh local       # Lint local database
#   ./run-lint.sh staging     # Lint staging database
#   ./run-lint.sh production  # Lint production database (--linked)
#
# Options:
#   --json    Output in JSON format (default: pretty)
#   --schema  Specify schema (default: public)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-local}"
OUTPUT_FORMAT="pretty"
SCHEMA="public"

# Parse additional arguments
shift || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --json)
      OUTPUT_FORMAT="json"
      shift
      ;;
    --schema)
      SCHEMA="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Find project root
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
if [ -z "$PROJECT_ROOT" ]; then
  echo -e "${RED}Error: Could not determine project root${NC}"
  exit 1
fi

WEB_DIR="$PROJECT_ROOT/apps/web"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Database Function Lint${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Schema: ${YELLOW}$SCHEMA${NC}"
echo -e "Output: ${YELLOW}$OUTPUT_FORMAT${NC}"
echo ""

run_lint() {
  local cmd="$1"
  echo -e "${GREEN}Running: $cmd${NC}"
  echo ""

  if [ "$OUTPUT_FORMAT" = "json" ]; then
    eval "$cmd" -o json
  else
    eval "$cmd"
  fi
}

case "$ENVIRONMENT" in
  local|--local)
    echo -e "${BLUE}Checking if local Supabase is running...${NC}"
    if ! docker ps | grep -q "supabase_db"; then
      echo -e "${RED}Error: Local Supabase is not running${NC}"
      echo -e "Start it with: ${YELLOW}pnpm supabase:web:start${NC}"
      exit 1
    fi

    cd "$WEB_DIR"
    run_lint "pnpm supabase db lint --local -s $SCHEMA"
    ;;

  staging|--staging)
    echo -e "${BLUE}Connecting to staging database...${NC}"

    # Try .env.local first (preferred)
    STAGING_PW=""
    if [ -f "$WEB_DIR/.env.local" ]; then
      source "$WEB_DIR/.env.local" 2>/dev/null
      STAGING_PW="${SUPABASE_DB_PASSWORD_STAGING:-}"
    fi

    # Fall back to 1Password and cache to .env.local
    if [ -z "$STAGING_PW" ] && command -v op &> /dev/null; then
      STAGING_PW=$(op item get rkzjnr5ffy5u6iojnsq3clnmia --fields notesPlain --reveal 2>/dev/null || echo "")
      if [ -n "$STAGING_PW" ]; then
        echo "SUPABASE_DB_PASSWORD_STAGING=$STAGING_PW" >> "$WEB_DIR/.env.local"
        echo -e "${GREEN}✅ Cached staging password to .env.local${NC}"
      fi
    fi

    if [ -z "$STAGING_PW" ]; then
      echo -e "${RED}Error: Could not get staging database password${NC}"
      echo -e "Add ${YELLOW}SUPABASE_DB_PASSWORD_STAGING${NC} to apps/web/.env.local or install 1Password CLI"
      exit 1
    fi

    # Staging project: hxpcknyqswetsqmqmeep
    DB_URL="postgresql://postgres.hxpcknyqswetsqmqmeep:${STAGING_PW}@aws-1-eu-central-1.pooler.supabase.com:5432/postgres"

    cd "$WEB_DIR"
    run_lint "pnpm supabase db lint --db-url \"$DB_URL\" -s $SCHEMA"
    ;;

  production|prod|--production|--linked)
    echo -e "${BLUE}Connecting to production database (linked project)...${NC}"

    cd "$WEB_DIR"
    run_lint "pnpm supabase db lint --linked -s $SCHEMA"
    ;;

  *)
    echo -e "${RED}Unknown environment: $ENVIRONMENT${NC}"
    echo ""
    echo "Usage: ./run-lint.sh <environment> [options]"
    echo ""
    echo "Environments:"
    echo "  local       Lint local database (requires Docker)"
    echo "  staging     Lint staging database"
    echo "  production  Lint production database (--linked)"
    echo ""
    echo "Options:"
    echo "  --json      Output in JSON format"
    echo "  --schema    Specify schema (default: public)"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}Lint complete!${NC}"

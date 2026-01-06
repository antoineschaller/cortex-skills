#!/bin/bash
# FK Integrity Validator
# Usage: ./validate-fk-integrity.sh [local|staging|production]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$SCRIPT_DIR/validate-fk-integrity.sql"
ENV="${1:-local}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== FK Integrity Validator ===${NC}"
echo -e "Environment: ${YELLOW}$ENV${NC}"
echo ""

# Load environment variables
if [ -f "apps/web/.env.local" ]; then
    source apps/web/.env.local 2>/dev/null || true
fi

case "$ENV" in
    local)
        echo -e "${GREEN}Running against local database...${NC}"
        PGPASSWORD=postgres psql -h localhost -p 54322 -U postgres -d postgres -f "$SQL_FILE"
        ;;
    staging)
        echo -e "${YELLOW}Running against STAGING database...${NC}"
        if [ -n "$SUPABASE_DB_URL_STAGING" ]; then
            psql "$SUPABASE_DB_URL_STAGING" -f "$SQL_FILE"
        else
            echo -e "${RED}Error: SUPABASE_DB_URL_STAGING not set in .env.local${NC}"
            exit 1
        fi
        ;;
    production|prod)
        echo -e "${RED}Running against PRODUCTION database (READ ONLY)...${NC}"
        if [ -n "$SUPABASE_DB_URL_PROD" ]; then
            psql "$SUPABASE_DB_URL_PROD" -f "$SQL_FILE"
        else
            echo -e "${RED}Error: SUPABASE_DB_URL_PROD not set in .env.local${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}Unknown environment: $ENV${NC}"
        echo "Usage: $0 [local|staging|production]"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}FK validation complete!${NC}"

#!/bin/bash

################################################################################
# Safe Database Reset Script
#
# CRITICAL SAFEGUARDS:
# 1. NEVER resets production database
# 2. Requires explicit confirmation for staging
# 3. Detects and blocks production connections
#
# Usage:
#   ./scripts/safe-db-reset.sh [staging|local]
#
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the safeguard functions
source "${SCRIPT_DIR}/db-safeguard.sh"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

# Production project refs - NEVER reset these
PRODUCTION_REFS=(
    "csjruhqyqzzqxnfeyiaf"
)

# Staging project ref
STAGING_REF="hxpcknyqswetsqmqmeep"

################################################################################
# Main
################################################################################

show_usage() {
    echo ""
    echo "Usage: $0 [target]"
    echo ""
    echo "Targets:"
    echo "  local     Reset local Supabase database (safe)"
    echo "  staging   Reset staging database (requires confirmation)"
    echo ""
    echo "Examples:"
    echo "  $0 local      # Reset local development database"
    echo "  $0 staging    # Reset staging (with confirmation)"
    echo ""
    echo "NOTE: Production database reset is BLOCKED by this script."
    echo "      Use Supabase Dashboard for production operations."
    echo ""
}

check_supabase_link() {
    if [[ -f "${SCRIPT_DIR}/../supabase/.temp/project-ref" ]]; then
        cat "${SCRIPT_DIR}/../supabase/.temp/project-ref"
    elif [[ -f "${SCRIPT_DIR}/../.supabase/project-ref" ]]; then
        cat "${SCRIPT_DIR}/../.supabase/project-ref"
    else
        echo ""
    fi
}

reset_local() {
    echo ""
    echo -e "${CYAN}🔄 Resetting LOCAL database...${NC}"
    echo ""

    # Check we're not accidentally linked to production
    local linked_ref=$(check_supabase_link)
    for ref in "${PRODUCTION_REFS[@]}"; do
        if [[ "$linked_ref" == "$ref" ]]; then
            echo -e "${RED}🚫 ERROR: You are currently linked to PRODUCTION!${NC}"
            echo -e "${RED}   Linked to: $linked_ref${NC}"
            echo ""
            echo -e "${YELLOW}To unlink from production, run:${NC}"
            echo -e "${YELLOW}  rm -rf apps/web/supabase/.temp/project-ref${NC}"
            echo -e "${YELLOW}  rm -rf apps/web/.supabase/project-ref${NC}"
            echo ""
            exit 1
        fi
    done

    cd "${SCRIPT_DIR}/.."

    echo -e "${GREEN}✅ Safe to reset local database${NC}"
    echo ""

    # Run the actual reset
    pnpm supabase db reset

    echo ""
    echo -e "${GREEN}✅ Local database reset complete!${NC}"
}

reset_staging() {
    echo ""
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                    ⚠️  STAGING DATABASE RESET ⚠️                    ║${NC}"
    echo -e "${YELLOW}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║                                                                   ║${NC}"
    echo -e "${YELLOW}║  You are about to RESET the STAGING database.                    ║${NC}"
    echo -e "${YELLOW}║                                                                   ║${NC}"
    echo -e "${YELLOW}║  Project: hxpcknyqswetsqmqmeep (ballee-staging)                  ║${NC}"
    echo -e "${YELLOW}║                                                                   ║${NC}"
    echo -e "${YELLOW}║  This will:                                                       ║${NC}"
    echo -e "${YELLOW}║  • DELETE all data in staging                                     ║${NC}"
    echo -e "${YELLOW}║  • Re-apply all migrations                                        ║${NC}"
    echo -e "${YELLOW}║  • Run seed scripts                                               ║${NC}"
    echo -e "${YELLOW}║                                                                   ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Double confirmation for staging
    read -p "Type 'reset staging' to confirm: " confirm
    if [[ "$confirm" != "reset staging" ]]; then
        echo ""
        echo -e "${RED}❌ Confirmation failed. Operation cancelled.${NC}"
        exit 1
    fi

    echo ""
    echo -e "${CYAN}🔄 Linking to staging...${NC}"

    cd "${SCRIPT_DIR}/.."

    # Link to staging project
    supabase link --project-ref "$STAGING_REF"

    echo ""
    echo -e "${CYAN}🔄 Resetting staging database...${NC}"

    # Reset staging
    supabase db reset --linked

    echo ""
    echo -e "${GREEN}✅ Staging database reset complete!${NC}"
}

block_production() {
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    🚫 PRODUCTION RESET BLOCKED 🚫                  ║${NC}"
    echo -e "${RED}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║                                                                   ║${NC}"
    echo -e "${RED}║  Production database reset is NOT allowed via CLI.               ║${NC}"
    echo -e "${RED}║                                                                   ║${NC}"
    echo -e "${RED}║  If you absolutely need to reset production:                     ║${NC}"
    echo -e "${RED}║  1. Use the Supabase Dashboard directly                          ║${NC}"
    echo -e "${RED}║  2. Get approval from the team                                   ║${NC}"
    echo -e "${RED}║  3. Create a full backup first                                   ║${NC}"
    echo -e "${RED}║                                                                   ║${NC}"
    echo -e "${RED}║  Production project: csjruhqyqzzqxnfeyiaf                        ║${NC}"
    echo -e "${RED}║                                                                   ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 1
}

# Main script
case "${1:-}" in
    local)
        reset_local
        ;;
    staging)
        reset_staging
        ;;
    production|prod)
        block_production
        ;;
    -h|--help|help|"")
        show_usage
        exit 0
        ;;
    *)
        echo -e "${RED}Unknown target: $1${NC}"
        show_usage
        exit 1
        ;;
esac

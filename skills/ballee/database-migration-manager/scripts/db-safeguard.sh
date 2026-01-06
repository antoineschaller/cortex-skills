#!/bin/bash

################################################################################
# Database Safeguard Script
#
# CRITICAL: Prevents accidental operations on production database
#
# This script provides:
# 1. Detection of production database connections
# 2. Blocking of destructive operations on production
# 3. Clear warnings and confirmation prompts
#
# Usage:
#   source scripts/db-safeguard.sh
#   check_not_production "$DATABASE_URL" "reset"
#   check_not_production "$DATABASE_URL" "drop"
################################################################################

# Production database identifiers - ADD ALL PRODUCTION REFS HERE
PRODUCTION_PROJECT_REFS=(
    "csjruhqyqzzqxnfeyiaf"  # Production Supabase project
)

PRODUCTION_HOSTNAMES=(
    "db.csjruhqyqzzqxnfeyiaf.supabase.co"
    "csjruhqyqzzqxnfeyiaf.supabase.co"
    "aws-0-eu-central-2.pooler.supabase.com"  # Production pooler
)

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

################################################################################
# Check if a connection string points to production
# Returns: 0 if production, 1 if not production
################################################################################
is_production_db() {
    local connection_string="$1"

    # Check for production project refs in connection string
    for ref in "${PRODUCTION_PROJECT_REFS[@]}"; do
        if [[ "$connection_string" == *"$ref"* ]]; then
            return 0  # Is production
        fi
    done

    # Check for production hostnames
    for hostname in "${PRODUCTION_HOSTNAMES[@]}"; do
        if [[ "$connection_string" == *"$hostname"* ]]; then
            return 0  # Is production
        fi
    done

    return 1  # Not production
}

################################################################################
# Check that we're NOT connected to production before destructive operations
# Usage: check_not_production "$DB_URL" "operation_name"
################################################################################
check_not_production() {
    local connection_string="$1"
    local operation="$2"

    if is_production_db "$connection_string"; then
        echo ""
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                    🚨 PRODUCTION DATABASE DETECTED 🚨              ║${NC}"
        echo -e "${RED}╠═══════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║                                                                   ║${NC}"
        echo -e "${RED}║  Operation: ${operation}${NC}"
        echo -e "${RED}║                                                                   ║${NC}"
        echo -e "${RED}║  This operation is BLOCKED on production databases.              ║${NC}"
        echo -e "${RED}║                                                                   ║${NC}"
        echo -e "${RED}║  If you really need to do this:                                  ║${NC}"
        echo -e "${RED}║  1. Create a backup first                                        ║${NC}"
        echo -e "${RED}║  2. Use the Supabase Dashboard directly                          ║${NC}"
        echo -e "${RED}║  3. Get team approval                                            ║${NC}"
        echo -e "${RED}║                                                                   ║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        return 1  # Block the operation
    fi

    return 0  # Allow the operation
}

################################################################################
# Require explicit confirmation for any operation on staging
# Usage: confirm_staging_operation "$DB_URL" "operation_name"
################################################################################
confirm_staging_operation() {
    local connection_string="$1"
    local operation="$2"

    # Check if staging
    if [[ "$connection_string" == *"hxpcknyqswetsqmqmeep"* ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  STAGING DATABASE DETECTED${NC}"
        echo -e "${YELLOW}Operation: ${operation}${NC}"
        echo ""
        read -p "Are you sure you want to proceed? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Operation cancelled."
            return 1
        fi
    fi

    return 0
}

################################################################################
# Safe wrapper for supabase db reset
# NEVER allows reset on production
################################################################################
safe_db_reset() {
    local project_ref="$1"

    # Check if production
    for ref in "${PRODUCTION_PROJECT_REFS[@]}"; do
        if [[ "$project_ref" == "$ref" ]]; then
            echo ""
            echo -e "${RED}🚫 BLOCKED: Cannot reset production database!${NC}"
            echo -e "${RED}   Project ref: $project_ref${NC}"
            echo ""
            return 1
        fi
    done

    # Check if linked to production
    if [[ -f ".supabase/project-ref" ]]; then
        local linked_ref=$(cat .supabase/project-ref)
        for ref in "${PRODUCTION_PROJECT_REFS[@]}"; do
            if [[ "$linked_ref" == "$ref" ]]; then
                echo ""
                echo -e "${RED}🚫 BLOCKED: Currently linked to production database!${NC}"
                echo -e "${RED}   Linked project: $linked_ref${NC}"
                echo -e "${YELLOW}   Run: supabase link --project-ref hxpcknyqswetsqmqmeep${NC}"
                echo -e "${YELLOW}   to switch to staging first.${NC}"
                echo ""
                return 1
            fi
        done
    fi

    echo -e "${GREEN}✅ Safe to proceed - not connected to production${NC}"
    return 0
}

################################################################################
# Display current database connection info
################################################################################
show_db_info() {
    local connection_string="$1"

    echo ""
    echo "Database Connection Info:"
    echo "========================="

    if is_production_db "$connection_string"; then
        echo -e "${RED}Environment: 🔴 PRODUCTION${NC}"
    elif [[ "$connection_string" == *"hxpcknyqswetsqmqmeep"* ]]; then
        echo -e "${YELLOW}Environment: 🟡 STAGING${NC}"
    elif [[ "$connection_string" == *"127.0.0.1"* ]] || [[ "$connection_string" == *"localhost"* ]]; then
        echo -e "${GREEN}Environment: 🟢 LOCAL${NC}"
    else
        echo -e "${YELLOW}Environment: ⚪ UNKNOWN${NC}"
    fi
    echo ""
}

# Export functions for use in other scripts
export -f is_production_db
export -f check_not_production
export -f confirm_staging_operation
export -f safe_db_reset
export -f show_db_info

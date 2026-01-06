#!/bin/bash

################################################################################
# Sync Production Database to Staging
#
# SAFETY: This script ONLY READS from production and WRITES to staging.
# Multiple safeguards prevent any writes to production.
#
# Usage:
#   ./sync-prod-to-staging.sh [options]
#
# Options:
#   --confirm       Required flag to actually execute (safety measure)
#   --include-auth  Include auth.users (default: true for complete sync)
#   --skip-auth     Skip auth.users table
#   --help          Show this help message
#
# Prerequisites:
#   - PostgreSQL 17 client tools (psql, pg_dump)
#   - Credentials in .env.local or 1Password CLI authenticated
#
################################################################################

set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# SAFETY CONSTANTS - NEVER MODIFY THESE
# ══════════════════════════════════════════════════════════════════════════════

# Production is READ ONLY - we only construct read connection
readonly PROD_PROJECT_REF="csjruhqyqzzqxnfeyiaf"
readonly PROD_POOLER_HOST="aws-1-eu-central-1.pooler.supabase.com"
readonly PROD_DB_USER="postgres.${PROD_PROJECT_REF}"
readonly PROD_DB_NAME="postgres"
readonly PROD_PORT="5432"

# Staging is WRITE target
readonly STAGING_PROJECT_REF="hxpcknyqswetsqmqmeep"
readonly STAGING_POOLER_HOST="aws-1-eu-central-1.pooler.supabase.com"
readonly STAGING_DB_USER="postgres.${STAGING_PROJECT_REF}"
readonly STAGING_DB_NAME="postgres"
readonly STAGING_PORT="5432"

# Script config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
WEB_DIR="${PROJECT_ROOT}/apps/web"
ENV_FILE="${WEB_DIR}/.env.local"
TEMP_DIR="${PROJECT_ROOT}/.tmp/db-sync"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="${TEMP_DIR}/prod_to_staging_${TIMESTAMP}.sql"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Flags
CONFIRMED=false
INCLUDE_AUTH=true  # Default: include auth for complete sync
YES_FLAG=false     # Skip interactive confirmation prompt

# ══════════════════════════════════════════════════════════════════════════════
# Helper Functions
# ══════════════════════════════════════════════════════════════════════════════

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}"; }

log_section() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║ $1${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_help() {
    grep "^#" "${BASH_SOURCE[0]}" | head -20 | tail -18
    exit 0
}

cleanup() {
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
}

trap cleanup EXIT

# ══════════════════════════════════════════════════════════════════════════════
# Credential Loading (from .env.local or 1Password)
# ══════════════════════════════════════════════════════════════════════════════

load_credentials() {
    log_section "Loading Credentials"

    # Source existing env file
    if [[ -f "${ENV_FILE}" ]]; then
        source "${ENV_FILE}"
    fi

    # Production password
    if [[ -z "${SUPABASE_DB_PASSWORD_PROD:-}" ]]; then
        log_info "Fetching production password from 1Password..."
        SUPABASE_DB_PASSWORD_PROD="$(op item get kuyspxxlyi2mxg7nfeb6dm3pje --fields notesPlain --reveal 2>/dev/null)" || {
            log_error "Failed to get production password from 1Password"
            log_info "Please set SUPABASE_DB_PASSWORD_PROD in ${ENV_FILE}"
            exit 1
        }
        echo "SUPABASE_DB_PASSWORD_PROD=\"${SUPABASE_DB_PASSWORD_PROD}\"" >> "${ENV_FILE}"
        log_success "Cached production password to .env.local"
    else
        log_success "Production password loaded from .env.local"
    fi

    # Staging password
    if [[ -z "${SUPABASE_DB_PASSWORD_STAGING:-}" ]]; then
        log_info "Fetching staging password from 1Password..."
        SUPABASE_DB_PASSWORD_STAGING="$(op item get rkzjnr5ffy5u6iojnsq3clnmia --fields notesPlain --reveal 2>/dev/null)" || {
            log_error "Failed to get staging password from 1Password"
            log_info "Please set SUPABASE_DB_PASSWORD_STAGING in ${ENV_FILE}"
            exit 1
        }
        echo "SUPABASE_DB_PASSWORD_STAGING=\"${SUPABASE_DB_PASSWORD_STAGING}\"" >> "${ENV_FILE}"
        log_success "Cached staging password to .env.local"
    else
        log_success "Staging password loaded from .env.local"
    fi

    export SUPABASE_DB_PASSWORD_PROD
    export SUPABASE_DB_PASSWORD_STAGING
}

# ══════════════════════════════════════════════════════════════════════════════
# Safety Verification
# ══════════════════════════════════════════════════════════════════════════════

verify_safety() {
    log_section "Safety Verification"

    echo -e "${BOLD}${RED}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  CRITICAL SAFETY CHECK ⚠️                       ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                      ║"
    echo "║  SOURCE (READ ONLY):  Production Database                            ║"
    echo "║  TARGET (WILL ERASE): Staging Database                               ║"
    echo "║                                                                      ║"
    echo "║  This will:                                                          ║"
    echo "║    1. READ all data from PRODUCTION                                  ║"
    echo "║    2. ERASE all data in STAGING                                      ║"
    echo "║    3. COPY production data to STAGING                                ║"
    if [[ "${INCLUDE_AUTH}" == "true" ]]; then
    echo "║    4. INCLUDE auth.users (complete sync)                             ║"
    fi
    echo "║                                                                      ║"
    echo "║  Production will NOT be modified.                                    ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Verify we're targeting staging, not production
    log_info "Verifying target database..."

    local staging_check
    staging_check=$(PGPASSWORD="${SUPABASE_DB_PASSWORD_STAGING}" psql \
        "postgresql://${STAGING_DB_USER}@${STAGING_POOLER_HOST}:${STAGING_PORT}/${STAGING_DB_NAME}" \
        -t -c "SELECT current_database();" 2>/dev/null | tr -d '[:space:]')

    if [[ "${staging_check}" != "postgres" ]]; then
        log_error "Failed to verify staging database connection"
        exit 1
    fi

    log_success "Confirmed target is STAGING database (${STAGING_PROJECT_REF})"

    # Additional confirmation
    if [[ "${CONFIRMED}" != "true" ]]; then
        echo ""
        log_warning "To execute this sync, run with --confirm flag:"
        echo ""
        echo "  $0 --confirm"
        echo ""
        log_info "Dry run complete. No changes made."
        exit 0
    fi

    # Final confirmation prompt (skip if --yes flag provided)
    if [[ "${YES_FLAG}" != "true" ]]; then
        echo ""
        read -p "Type 'SYNC TO STAGING' to confirm: " confirmation
        if [[ "${confirmation}" != "SYNC TO STAGING" ]]; then
            log_error "Confirmation failed. Aborting."
            exit 1
        fi
    else
        log_info "Skipping interactive prompt (--yes flag provided)"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# Database Operations
# ══════════════════════════════════════════════════════════════════════════════

prod_db_url() {
    local encoded_password
    encoded_password=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${SUPABASE_DB_PASSWORD_PROD}', safe=''))")
    echo "postgresql://${PROD_DB_USER}:${encoded_password}@${PROD_POOLER_HOST}:${PROD_PORT}/${PROD_DB_NAME}"
}

staging_db_url() {
    local encoded_password
    encoded_password=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${SUPABASE_DB_PASSWORD_STAGING}', safe=''))")
    echo "postgresql://${STAGING_DB_USER}:${encoded_password}@${STAGING_POOLER_HOST}:${STAGING_PORT}/${STAGING_DB_NAME}"
}

dump_production() {
    log_section "Dumping Production Database (READ ONLY)"

    mkdir -p "${TEMP_DIR}"

    local db_url
    db_url="$(prod_db_url)"

    log_info "Using Supabase CLI to dump production data..."
    log_info "This may take several minutes for large databases..."

    local schemas="public"
    if [[ "${INCLUDE_AUTH}" == "true" ]]; then
        schemas="public,auth"
    fi

    cd "${WEB_DIR}"

    log_info "Dumping schemas: ${schemas}..."
    pnpm supabase db dump \
        --db-url "${db_url}" \
        --data-only \
        --schema "${schemas}" \
        --use-copy \
        --exclude "auth.audit_log_entries,auth.schema_migrations,supabase_migrations.schema_migrations" \
        -f "${DUMP_FILE}" 2>&1 || {
            log_error "Failed to dump production database"
            exit 1
        }

    if [[ -f "${DUMP_FILE}" ]] && [[ -s "${DUMP_FILE}" ]]; then
        local dump_size=$(du -h "${DUMP_FILE}" | cut -f1)
        log_success "Dump created: ${dump_size}"
    else
        log_error "Dump file is empty or missing"
        exit 1
    fi
}

truncate_staging() {
    log_section "Clearing Staging Database"

    local staging_conn="postgresql://${STAGING_DB_USER}@${STAGING_POOLER_HOST}:${STAGING_PORT}/${STAGING_DB_NAME}"

    # Disable triggers and FK checks
    log_info "Disabling triggers and FK constraints..."
    PGPASSWORD="${SUPABASE_DB_PASSWORD_STAGING}" psql "${staging_conn}" -c \
        "SET session_replication_role = 'replica';" 2>/dev/null

    # Truncate auth tables first if we're syncing auth
    if [[ "${INCLUDE_AUTH}" == "true" ]]; then
        log_info "Truncating auth tables..."
        PGPASSWORD="${SUPABASE_DB_PASSWORD_STAGING}" psql "${staging_conn}" <<EOF 2>/dev/null || true
SET session_replication_role = 'replica';
TRUNCATE TABLE auth.users CASCADE;
TRUNCATE TABLE auth.identities CASCADE;
TRUNCATE TABLE auth.sessions CASCADE;
TRUNCATE TABLE auth.refresh_tokens CASCADE;
TRUNCATE TABLE auth.mfa_factors CASCADE;
TRUNCATE TABLE auth.mfa_challenges CASCADE;
TRUNCATE TABLE auth.mfa_amr_claims CASCADE;
TRUNCATE TABLE auth.flow_state CASCADE;
TRUNCATE TABLE auth.saml_relay_states CASCADE;
TRUNCATE TABLE auth.saml_providers CASCADE;
TRUNCATE TABLE auth.sso_providers CASCADE;
TRUNCATE TABLE auth.sso_domains CASCADE;
TRUNCATE TABLE auth.one_time_tokens CASCADE;
EOF
    fi

    # Get list of public tables to truncate
    log_info "Truncating public tables..."
    local tables
    tables=$(PGPASSWORD="${SUPABASE_DB_PASSWORD_STAGING}" psql "${staging_conn}" \
        -t -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT LIKE 'supabase_%';" 2>/dev/null)

    for table in ${tables}; do
        table=$(echo "${table}" | tr -d '[:space:]')
        if [[ -n "${table}" ]]; then
            log_info "  Truncating ${table}..."
            PGPASSWORD="${SUPABASE_DB_PASSWORD_STAGING}" psql "${staging_conn}" -c \
                "SET session_replication_role = 'replica'; TRUNCATE TABLE public.\"${table}\" CASCADE;" 2>/dev/null || true
        fi
    done

    log_success "Staging tables truncated"
}

restore_to_staging() {
    log_section "Restoring to Staging Database"

    local staging_conn="$(staging_db_url)"

    # Verify dump file exists
    if [[ ! -f "${DUMP_FILE}" ]] || [[ ! -s "${DUMP_FILE}" ]]; then
        log_error "Dump file not found or empty: ${DUMP_FILE}"
        exit 1
    fi
    log_success "Dump file exists: $(du -h "${DUMP_FILE}" | cut -f1)"

    log_info "Restoring dump to staging..."

    # Restore with triggers disabled
    (echo "SET session_replication_role = 'replica';" && cat "${DUMP_FILE}") | \
        PGPASSWORD="${SUPABASE_DB_PASSWORD_STAGING}" psql "${staging_conn}" 2>&1 | grep -E "(ERROR|error)" | head -10 || true

    # Re-enable triggers
    log_info "Re-enabling triggers..."
    PGPASSWORD="${SUPABASE_DB_PASSWORD_STAGING}" psql "${staging_conn}" -c \
        "SET session_replication_role = 'origin';" 2>/dev/null

    log_success "Data restored to staging"
}

verify_sync() {
    log_section "Verifying Sync"

    # Compare row counts for key tables
    local tables_to_check="profiles accounts events productions clients"

    echo ""
    printf "%-30s %15s %15s\n" "Table" "Production" "Staging"
    printf "%-30s %15s %15s\n" "-----" "----------" "-------"

    for table in ${tables_to_check}; do
        local prod_count staging_count

        prod_count=$(PGPASSWORD="${SUPABASE_DB_PASSWORD_PROD}" psql \
            "postgresql://${PROD_DB_USER}@${PROD_POOLER_HOST}:${PROD_PORT}/${PROD_DB_NAME}" \
            -t -c "SELECT COUNT(*) FROM public.${table};" 2>/dev/null | tr -d '[:space:]') || prod_count="N/A"

        staging_count=$(PGPASSWORD="${SUPABASE_DB_PASSWORD_STAGING}" psql \
            "postgresql://${STAGING_DB_USER}@${STAGING_POOLER_HOST}:${STAGING_PORT}/${STAGING_DB_NAME}" \
            -t -c "SELECT COUNT(*) FROM public.${table};" 2>/dev/null | tr -d '[:space:]') || staging_count="N/A"

        if [[ "${prod_count}" == "${staging_count}" ]]; then
            printf "%-30s %15s %15s ✅\n" "${table}" "${prod_count}" "${staging_count}"
        else
            printf "%-30s %15s %15s ⚠️\n" "${table}" "${prod_count}" "${staging_count}"
        fi
    done

    # Check auth.users if included
    if [[ "${INCLUDE_AUTH}" == "true" ]]; then
        echo ""
        printf "%-30s %15s %15s\n" "auth.users" "Production" "Staging"
        printf "%-30s %15s %15s\n" "----------" "----------" "-------"

        local prod_auth staging_auth

        prod_auth=$(PGPASSWORD="${SUPABASE_DB_PASSWORD_PROD}" psql \
            "postgresql://${PROD_DB_USER}@${PROD_POOLER_HOST}:${PROD_PORT}/${PROD_DB_NAME}" \
            -t -c "SELECT COUNT(*) FROM auth.users;" 2>/dev/null | tr -d '[:space:]') || prod_auth="N/A"

        staging_auth=$(PGPASSWORD="${SUPABASE_DB_PASSWORD_STAGING}" psql \
            "postgresql://${STAGING_DB_USER}@${STAGING_POOLER_HOST}:${STAGING_PORT}/${STAGING_DB_NAME}" \
            -t -c "SELECT COUNT(*) FROM auth.users;" 2>/dev/null | tr -d '[:space:]') || staging_auth="N/A"

        if [[ "${prod_auth}" == "${staging_auth}" ]]; then
            printf "%-30s %15s %15s ✅\n" "auth.users" "${prod_auth}" "${staging_auth}"
        else
            printf "%-30s %15s %15s ⚠️\n" "auth.users" "${prod_auth}" "${staging_auth}"
        fi
    fi

    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# Argument Parsing
# ══════════════════════════════════════════════════════════════════════════════

while [[ $# -gt 0 ]]; do
    case $1 in
        --confirm)
            CONFIRMED=true
            shift
            ;;
        --yes|-y)
            YES_FLAG=true
            shift
            ;;
        --skip-auth)
            INCLUDE_AUTH=false
            shift
            ;;
        --include-auth)
            INCLUDE_AUTH=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            ;;
    esac
done

# ══════════════════════════════════════════════════════════════════════════════
# Main Execution
# ══════════════════════════════════════════════════════════════════════════════

main() {
    log_section "Production → Staging Database Sync"

    echo -e "${BOLD}Timestamp:${NC} ${TIMESTAMP}"
    echo -e "${BOLD}Source:${NC}    Production (${PROD_PROJECT_REF})"
    echo -e "${BOLD}Target:${NC}    Staging (${STAGING_PROJECT_REF})"
    echo -e "${BOLD}Include Auth:${NC} ${INCLUDE_AUTH}"
    echo ""

    load_credentials
    verify_safety
    dump_production
    truncate_staging
    restore_to_staging
    verify_sync

    log_section "Sync Complete"
    log_success "Production data has been copied to staging"
    log_info "Staging URL: https://${STAGING_PROJECT_REF}.supabase.co"
}

main

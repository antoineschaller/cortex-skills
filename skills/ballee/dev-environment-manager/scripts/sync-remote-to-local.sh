#!/bin/bash

################################################################################
# Sync Remote Database (Staging/Production) to Local Development
#
# Uses Supabase CLI's built-in pg_dump to avoid version mismatches.
#
# SAFETY: This script ONLY READS from remote and WRITES to local.
# Multiple safeguards prevent any writes to remote.
#
# Usage:
#   SYNC_ENV=staging ./sync-remote-to-local.sh [options]
#   SYNC_ENV=prod ./sync-remote-to-local.sh [options]
#
# Options:
#   --confirm       Required flag to actually execute (safety measure)
#   --include-auth  Include auth.users (default: true for complete sync)
#   --skip-auth     Skip auth.users table
#   --yes, -y       Skip interactive confirmation prompt
#   --help          Show this help message
#
# Environment:
#   SYNC_ENV        Set to "staging" or "prod" (default: staging)
#
################################################################################

set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# ENVIRONMENT CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

SYNC_ENV="${SYNC_ENV:-staging}"

# Staging configuration
readonly STAGING_PROJECT_REF="hxpcknyqswetsqmqmeep"
readonly STAGING_POOLER_HOST="aws-1-eu-central-1.pooler.supabase.com"
readonly STAGING_DB_USER="postgres.${STAGING_PROJECT_REF}"

# Production configuration
readonly PROD_PROJECT_REF="csjruhqyqzzqxnfeyiaf"
readonly PROD_POOLER_HOST="aws-1-eu-central-1.pooler.supabase.com"
readonly PROD_DB_USER="postgres.${PROD_PROJECT_REF}"

# Common configuration
readonly REMOTE_DB_NAME="postgres"
readonly REMOTE_PORT="5432"

# Local is WRITE target
readonly LOCAL_HOST="127.0.0.1"
readonly LOCAL_PORT="54322"
readonly LOCAL_DB_USER="postgres"
readonly LOCAL_DB_NAME="postgres"
readonly LOCAL_PASSWORD="postgres"

# Script config (allow override via environment)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../../../.." && pwd)}"
WEB_DIR="${PROJECT_ROOT}/apps/web"
ENV_FILE="${ENV_FILE:-${WEB_DIR}/.env.local}"
TEMP_DIR="${PROJECT_ROOT}/.tmp/db-sync"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="${TEMP_DIR}/${SYNC_ENV}_dump_${TIMESTAMP}.sql"

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
INCLUDE_AUTH=true
YES_FLAG=false

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
    grep "^#" "${BASH_SOURCE[0]}" | head -28 | tail -26
    exit 0
}

cleanup() {
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
}

trap cleanup EXIT

# Get remote configuration based on SYNC_ENV
get_remote_config() {
    if [[ "${SYNC_ENV}" == "prod" ]]; then
        REMOTE_PROJECT_REF="${PROD_PROJECT_REF}"
        REMOTE_POOLER_HOST="${PROD_POOLER_HOST}"
        REMOTE_DB_USER="${PROD_DB_USER}"
        PASSWORD_VAR="SUPABASE_DB_PASSWORD_PROD"
        OP_ITEM_ID="kuyspxxlyi2mxg7nfeb6dm3pje"
        ENV_LABEL="PRODUCTION"
    else
        REMOTE_PROJECT_REF="${STAGING_PROJECT_REF}"
        REMOTE_POOLER_HOST="${STAGING_POOLER_HOST}"
        REMOTE_DB_USER="${STAGING_DB_USER}"
        PASSWORD_VAR="SUPABASE_DB_PASSWORD_STAGING"
        OP_ITEM_ID="rkzjnr5ffy5u6iojnsq3clnmia"
        ENV_LABEL="STAGING"
    fi
}

# Build remote connection string (URL encoded)
remote_db_url() {
    local encoded_password
    encoded_password=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${REMOTE_DB_PASSWORD}', safe=''))")
    echo "postgresql://${REMOTE_DB_USER}:${encoded_password}@${REMOTE_POOLER_HOST}:${REMOTE_PORT}/${REMOTE_DB_NAME}"
}

# Build local connection string
local_conn() {
    echo "postgresql://${LOCAL_DB_USER}:${LOCAL_PASSWORD}@${LOCAL_HOST}:${LOCAL_PORT}/${LOCAL_DB_NAME}"
}

# ══════════════════════════════════════════════════════════════════════════════
# Credential Loading
# ══════════════════════════════════════════════════════════════════════════════

load_credentials() {
    log_section "Loading Credentials"

    get_remote_config

    # Source existing env file
    if [[ -f "${ENV_FILE}" ]]; then
        set +u
        source "${ENV_FILE}" 2>/dev/null || true
        set -u
    fi

    # Get password from environment variable
    REMOTE_DB_PASSWORD="${!PASSWORD_VAR:-}"

    # Fallback to 1Password if not set
    if [[ -z "${REMOTE_DB_PASSWORD:-}" ]]; then
        log_info "Fetching ${ENV_LABEL} password from 1Password..."
        REMOTE_DB_PASSWORD="$(op item get "${OP_ITEM_ID}" --fields notesPlain --reveal 2>/dev/null)" || {
            log_error "Failed to get ${ENV_LABEL} password from 1Password"
            log_info "Please set ${PASSWORD_VAR} in ${ENV_FILE}"
            exit 1
        }
        echo "${PASSWORD_VAR}=\"${REMOTE_DB_PASSWORD}\"" >> "${ENV_FILE}"
        log_success "Cached ${ENV_LABEL} password to .env.local"
    else
        log_success "${ENV_LABEL} password loaded from .env.local"
    fi

    export REMOTE_DB_PASSWORD
}

# ══════════════════════════════════════════════════════════════════════════════
# Safety Verification
# ══════════════════════════════════════════════════════════════════════════════

verify_local_supabase() {
    log_section "Verifying Local Supabase"

    if ! PGPASSWORD="${LOCAL_PASSWORD}" psql \
        "postgresql://${LOCAL_DB_USER}@${LOCAL_HOST}:${LOCAL_PORT}/${LOCAL_DB_NAME}" \
        -c "SELECT 1;" &>/dev/null; then
        log_error "Local Supabase is not running!"
        echo ""
        log_info "Start it with:"
        echo "  cd ${WEB_DIR} && pnpm supabase start"
        echo ""
        exit 1
    fi

    log_success "Local Supabase is running on port ${LOCAL_PORT}"
}

verify_safety() {
    log_section "Safety Verification"

    echo -e "${BOLD}${RED}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  CRITICAL SAFETY CHECK ⚠️                       ║"
    echo "╠══════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                      ║"
    echo "║  SOURCE (READ ONLY):  ${ENV_LABEL} Database                            "
    echo "║  TARGET (WILL ERASE): Local Development Database                     ║"
    echo "║                                                                      ║"
    echo "║  This will:                                                          ║"
    echo "║    1. READ all data from ${ENV_LABEL}                                  "
    echo "║    2. ERASE all data in LOCAL                                        ║"
    echo "║    3. COPY ${ENV_LABEL} data to LOCAL                                  "
    if [[ "${INCLUDE_AUTH}" == "true" ]]; then
    echo "║    4. INCLUDE auth.users (complete sync)                             ║"
    fi
    echo "║                                                                      ║"
    echo "║  ${ENV_LABEL} will NOT be modified.                                    "
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    log_info "Verifying target is local database..."

    local local_check
    local_check=$(PGPASSWORD="${LOCAL_PASSWORD}" psql \
        "postgresql://${LOCAL_DB_USER}@${LOCAL_HOST}:${LOCAL_PORT}/${LOCAL_DB_NAME}" \
        -t -c "SHOW port;" 2>/dev/null | tr -d '[:space:]')

    if [[ "${local_check}" != "5432" ]]; then
        log_error "Target database port mismatch. Expected internal port 5432, got ${local_check}"
        log_error "This doesn't look like local Supabase"
        exit 1
    fi

    log_success "Confirmed target is LOCAL database (127.0.0.1:${LOCAL_PORT})"

    if [[ "${CONFIRMED}" != "true" ]]; then
        echo ""
        log_warning "To execute this sync, run with --confirm flag:"
        echo ""
        echo "  $0 --confirm"
        echo ""
        log_info "Dry run complete. No changes made."
        exit 0
    fi

    if [[ "${YES_FLAG}" != "true" ]]; then
        echo ""
        read -p "Type 'SYNC TO LOCAL' to confirm: " confirmation
        if [[ "${confirmation}" != "SYNC TO LOCAL" ]]; then
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

dump_remote() {
    log_section "Dumping ${ENV_LABEL} Database"

    mkdir -p "${TEMP_DIR}"

    local db_url
    db_url="$(remote_db_url)"

    log_info "Using Supabase CLI to dump ${ENV_LABEL} data..."
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
            log_error "Failed to dump ${ENV_LABEL} database"
            log_info "Falling back to manual sync..."
            return 1
        }

    if [[ -f "${DUMP_FILE}" ]] && [[ -s "${DUMP_FILE}" ]]; then
        local dump_size=$(du -h "${DUMP_FILE}" | cut -f1)
        log_success "Dump created: ${dump_size}"
        return 0
    else
        log_warning "Dump file is empty or missing, falling back to manual sync"
        return 1
    fi
}

truncate_local() {
    log_section "Clearing Local Database"

    local local_url="$(local_conn)"

    log_info "Disabling triggers and truncating tables..."

    PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" <<'EOF' 2>/dev/null || true
SET session_replication_role = 'replica';

DO $$
BEGIN
    EXECUTE 'TRUNCATE TABLE auth.users CASCADE';
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT LIKE 'supabase_%')
    LOOP
        EXECUTE 'TRUNCATE TABLE public.' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END $$;

SET session_replication_role = 'origin';
EOF

    log_success "Local tables truncated"
}

restore_to_local() {
    log_section "Restoring to Local Database"

    local local_url="$(local_conn)"

    log_info "Restoring dump to local database..."

    PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" <<EOF 2>&1 | grep -v "^SET$" | grep -v "^COPY" | head -20 || true
SET session_replication_role = 'replica';
\i ${DUMP_FILE}
SET session_replication_role = 'origin';
EOF

    log_success "Data restored to local"
}

verify_sync() {
    log_section "Verifying Sync"

    local remote_url="$(remote_db_url)"
    local local_url="$(local_conn)"

    local tables_to_check="clients venues productions events cast_roles cast_assignments profiles professional_profiles accounts event_showtimes hire_orders"

    echo ""
    printf "%-30s %15s %15s\n" "Table" "${ENV_LABEL}" "Local"
    printf "%-30s %15s %15s\n" "-----" "----------" "-----"

    for table in ${tables_to_check}; do
        local remote_count local_count

        remote_count=$(PGPASSWORD="${REMOTE_DB_PASSWORD}" psql "${remote_url}" \
            -t -c "SELECT COUNT(*) FROM public.${table};" 2>/dev/null | tr -d '[:space:]') || remote_count="N/A"

        local_count=$(PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" \
            -t -c "SELECT COUNT(*) FROM public.${table};" 2>/dev/null | tr -d '[:space:]') || local_count="N/A"

        if [[ "${remote_count}" == "${local_count}" ]]; then
            printf "%-30s %15s %15s ✅\n" "${table}" "${remote_count}" "${local_count}"
        else
            printf "%-30s %15s %15s ⚠️\n" "${table}" "${remote_count}" "${local_count}"
        fi
    done

    if [[ "${INCLUDE_AUTH}" == "true" ]]; then
        echo ""
        local remote_auth local_auth

        remote_auth=$(PGPASSWORD="${REMOTE_DB_PASSWORD}" psql "${remote_url}" \
            -t -c "SELECT COUNT(*) FROM auth.users;" 2>/dev/null | tr -d '[:space:]') || remote_auth="N/A"

        local_auth=$(PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" \
            -t -c "SELECT COUNT(*) FROM auth.users;" 2>/dev/null | tr -d '[:space:]') || local_auth="N/A"

        if [[ "${remote_auth}" == "${local_auth}" ]]; then
            printf "%-30s %15s %15s ✅\n" "auth.users" "${remote_auth}" "${local_auth}"
        else
            printf "%-30s %15s %15s ⚠️\n" "auth.users" "${remote_auth}" "${local_auth}"
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
    get_remote_config

    log_section "${ENV_LABEL} → Local Database Sync"

    echo -e "${BOLD}Timestamp:${NC} ${TIMESTAMP}"
    echo -e "${BOLD}Source:${NC}    ${ENV_LABEL} (${REMOTE_PROJECT_REF})"
    echo -e "${BOLD}Target:${NC}    Local (127.0.0.1:${LOCAL_PORT})"
    echo -e "${BOLD}Include Auth:${NC} ${INCLUDE_AUTH}"
    echo ""

    load_credentials
    verify_local_supabase
    verify_safety

    if dump_remote; then
        truncate_local
        restore_to_local
    else
        log_error "Failed to dump ${ENV_LABEL} database"
        exit 1
    fi

    verify_sync

    log_section "Sync Complete"
    log_success "${ENV_LABEL} data has been copied to local"
    log_info "Local Supabase Studio: http://127.0.0.1:54323"
    echo ""
    log_info "You can now test with ${ENV_LABEL} data locally."
    log_info "Login with any ${ENV_LABEL} user email + password 'password'"
}

main

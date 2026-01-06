#!/bin/bash

################################################################################
# Sync Production Database to Local Development
#
# Uses Supabase CLI's built-in pg_dump to avoid version mismatches.
#
# SAFETY: This script ONLY READS from production and WRITES to local.
# Multiple safeguards prevent any writes to production.
#
# Usage:
#   ./sync-prod-to-local.sh [options]
#
# Options:
#   --confirm       Required flag to actually execute (safety measure)
#   --include-auth  Include auth.users (default: true for complete sync)
#   --skip-auth     Skip auth.users table
#   --yes, -y       Skip interactive confirmation prompt
#   --help          Show this help message
#
# Prerequisites:
#   - Supabase CLI installed (pnpm supabase ...)
#   - Local Supabase running (pnpm supabase start)
#   - Credentials in .env.local or 1Password CLI authenticated
#
################################################################################

set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# SAFETY CONSTANTS - NEVER MODIFY THESE
# ══════════════════════════════════════════════════════════════════════════════

# Production is READ ONLY
readonly PROD_PROJECT_REF="csjruhqyqzzqxnfeyiaf"
readonly PROD_POOLER_HOST="aws-1-eu-central-1.pooler.supabase.com"
readonly PROD_DB_USER="postgres.${PROD_PROJECT_REF}"
readonly PROD_DB_NAME="postgres"
readonly PROD_PORT="5432"

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
DUMP_FILE="${TEMP_DIR}/prod_dump_${TIMESTAMP}.sql"

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
    grep "^#" "${BASH_SOURCE[0]}" | head -24 | tail -22
    exit 0
}

cleanup() {
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
}

trap cleanup EXIT

# Build production connection string (URL encoded)
prod_db_url() {
    # URL encode the password
    local encoded_password
    encoded_password=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${SUPABASE_DB_PASSWORD_PROD}', safe=''))")
    echo "postgresql://${PROD_DB_USER}:${encoded_password}@${PROD_POOLER_HOST}:${PROD_PORT}/${PROD_DB_NAME}"
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

    # Source existing env file
    if [[ -f "${ENV_FILE}" ]]; then
        set +u
        source "${ENV_FILE}" 2>/dev/null || true
        set -u
    fi

    # Check both possible variable names
    if [[ -z "${SUPABASE_DB_PASSWORD_PROD:-}" ]]; then
        SUPABASE_DB_PASSWORD_PROD="${SUPABASE_DB_PASSWORD_PRODUCTION:-}"
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

    export SUPABASE_DB_PASSWORD_PROD
}

# ══════════════════════════════════════════════════════════════════════════════
# Safety Verification
# ══════════════════════════════════════════════════════════════════════════════

verify_local_supabase() {
    log_section "Verifying Local Supabase"

    # Check if local Supabase is running
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
    echo "║  SOURCE (READ ONLY):  Production Database                            ║"
    echo "║  TARGET (WILL ERASE): Local Development Database                     ║"
    echo "║                                                                      ║"
    echo "║  This will:                                                          ║"
    echo "║    1. READ all data from PRODUCTION                                  ║"
    echo "║    2. ERASE all data in LOCAL                                        ║"
    echo "║    3. COPY production data to LOCAL                                  ║"
    if [[ "${INCLUDE_AUTH}" == "true" ]]; then
    echo "║    4. INCLUDE auth.users (complete sync)                             ║"
    fi
    echo "║                                                                      ║"
    echo "║  Production will NOT be modified.                                    ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Verify target is actually local (port 54322)
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

    # Final confirmation (skip if --yes flag provided)
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
# Database Operations using Supabase CLI
# ══════════════════════════════════════════════════════════════════════════════

dump_production() {
    log_section "Dumping Production Database"

    mkdir -p "${TEMP_DIR}"

    local db_url
    db_url="$(prod_db_url)"

    log_info "Using Supabase CLI to dump production data..."
    log_info "This may take several minutes for large databases..."

    # Build schema list
    local schemas="public"
    if [[ "${INCLUDE_AUTH}" == "true" ]]; then
        schemas="public,auth"
    fi

    # Use Supabase CLI's db dump (uses bundled pg_dump, avoiding version issues)
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
-- Disable triggers
SET session_replication_role = 'replica';

-- Truncate auth tables if they exist
DO $$
BEGIN
    EXECUTE 'TRUNCATE TABLE auth.users CASCADE';
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- Get and truncate all public tables
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT LIKE 'supabase_%')
    LOOP
        EXECUTE 'TRUNCATE TABLE public.' || quote_ident(r.tablename) || ' CASCADE';
    END LOOP;
END $$;

-- Re-enable triggers
SET session_replication_role = 'origin';
EOF

    log_success "Local tables truncated"
}

restore_to_local() {
    log_section "Restoring to Local Database"

    local local_url="$(local_conn)"

    log_info "Restoring dump to local database..."

    # Restore with triggers disabled to avoid constraint issues
    PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" <<EOF 2>&1 | grep -v "^SET$" | grep -v "^COPY" | head -20 || true
SET session_replication_role = 'replica';
\i ${DUMP_FILE}
SET session_replication_role = 'origin';
EOF

    log_success "Data restored to local"
}

# Fallback: Sync a single table using INSERT statements when COPY fails
sync_table_with_inserts() {
    local table="$1"
    local columns="$2"
    local prod_url="$3"
    local local_url="$4"

    # Generate INSERT statements from prod data using JSON aggregation
    # This handles special characters, newlines, and escaping properly
    local insert_sql="${TEMP_DIR}/${table}_inserts.sql"

    PGPASSWORD="${SUPABASE_DB_PASSWORD_PROD}" psql "${prod_url}" -t -A <<EOF > "${insert_sql}" 2>/dev/null
SELECT 'INSERT INTO ${table} (${columns}) SELECT * FROM json_populate_recordset(NULL::${table}, ''' ||
       replace(json_agg(t)::text, '''', '''''') || ''') ON CONFLICT DO NOTHING;'
FROM (SELECT ${columns} FROM ${table}) t;
EOF

    if [[ -f "${insert_sql}" ]] && [[ -s "${insert_sql}" ]]; then
        PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" -c "SET session_replication_role = 'replica';" 2>/dev/null
        PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" -f "${insert_sql}" 2>/dev/null || true
    fi
}

# Fallback: Manual sync for specific tables when Supabase CLI dump fails
manual_sync() {
    log_section "Manual Sync (Fallback)"

    mkdir -p "${TEMP_DIR}"

    local prod_url="$(prod_db_url)"
    local local_url="$(local_conn)"

    # Sync auth.users first if requested
    if [[ "${INCLUDE_AUTH}" == "true" ]]; then
        log_info "Syncing auth.users..."

        # Generate INSERT statements for auth.users
        PGPASSWORD="${SUPABASE_DB_PASSWORD_PROD}" psql "${prod_url}" -t -A -c "
SELECT 'INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, raw_user_meta_data, role, aud, created_at, updated_at) VALUES (
  ''' || id || ''',
  ''' || REPLACE(COALESCE(email, ''), '''', '''''') || ''',
  ''' || COALESCE(encrypted_password, '') || ''',
  ' || COALESCE('''' || email_confirmed_at::text || '''', 'now()') || ',
  ''' || REPLACE(COALESCE(raw_user_meta_data::text, '{}'), '''', '''''') || '''::jsonb,
  ''authenticated'', ''authenticated'',
  ''' || created_at || ''', ''' || updated_at || '''
) ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, encrypted_password = EXCLUDED.encrypted_password, raw_user_meta_data = EXCLUDED.raw_user_meta_data;'
FROM auth.users;
" > "${TEMP_DIR}/auth_users.sql" 2>/dev/null

        PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" -c "DELETE FROM auth.users;" 2>/dev/null || true
        PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" -f "${TEMP_DIR}/auth_users.sql" 2>/dev/null || true

        local auth_count=$(PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" -t -c "SELECT COUNT(*) FROM auth.users;" 2>/dev/null | tr -d '[:space:]')
        log_success "auth.users: ${auth_count} rows"
    fi

    # Sync all tables with data in dependency order (FK relationships respected)
    # Order: independent tables first, then tables that reference them
    local tables=(
        # Level 0: Reference tables (no FK dependencies)
        countries
        jurisdictions
        legal_status_types
        roles
        config
        engagement_models

        # Level 1: Core entities (depend on reference tables)
        clients
        venues
        accounts

        # Level 2: Productions/Events (depend on clients/venues)
        productions
        events
        cast_roles
        contract_templates
        contract_setups

        # Level 3: User-related (depend on accounts)
        profiles
        professional_profiles
        admin_account_context
        admin_invitations
        dancer_contract_details
        dancer_links
        dancer_locations
        user_signatures

        # Level 4: Event-related (depend on events/productions)
        event_showtimes
        cast_assignments

        # Level 5: Hire/Reimbursement (depend on events/profiles)
        hire_orders
        reimbursement_requests
        reimbursement_line_items
        reimbursement_documents

        # Level 6: Airtable sync (depend on various entities)
        airtable_entity_mapping
        airtable_sync_runs
        airtable_sync_changes

        # Level 7: Chatbot (depend on profiles)
        chatbot_conversations
        chatbot_messages
        chatbot_audit_logs
        chatbot_token_usage

        # Level 8: Country requirements
        country_contract_requirements
    )

    local failed_tables=()

    for table in "${tables[@]}"; do
        log_info "Syncing ${table}..."

        # Get local columns in proper order, excluding generated columns
        # Use information_schema.columns with proper check for generated columns
        local local_cols
        local_cols=$(PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" -t -A -c \
            "SELECT string_agg(column_name, ',' ORDER BY ordinal_position)
             FROM information_schema.columns
             WHERE table_schema='public' AND table_name='${table}'
             AND (is_generated = 'NEVER' OR is_generated IS NULL)
             AND column_name NOT IN (
                 SELECT column_name FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='${table}'
                 AND is_generated = 'ALWAYS'
             );" 2>/dev/null)

        if [[ -z "$local_cols" ]]; then
            log_warning "  No columns found for ${table}, skipping"
            continue
        fi

        # Check if table exists in prod and has data
        local prod_count
        prod_count=$(PGPASSWORD="${SUPABASE_DB_PASSWORD_PROD}" psql "${prod_url}" -t -A -c \
            "SELECT COUNT(*) FROM ${table};" 2>/dev/null) || prod_count="0"

        if [[ "${prod_count}" == "0" ]]; then
            log_info "  ${table}: 0 rows in prod, skipping"
            continue
        fi

        # Export from prod using local column order (handles schema differences)
        local csv_file="${TEMP_DIR}/${table}.csv"
        local copy_error
        copy_error=$(PGPASSWORD="${SUPABASE_DB_PASSWORD_PROD}" psql "${prod_url}" -c \
            "\\COPY (SELECT ${local_cols} FROM ${table}) TO '${csv_file}' WITH (FORMAT CSV, HEADER)" 2>&1)

        if [[ -f "$csv_file" ]] && [[ -s "$csv_file" ]]; then
            # Truncate local table
            PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" -c \
                "SET session_replication_role = 'replica'; TRUNCATE TABLE ${table} CASCADE;" 2>/dev/null || true

            # Try COPY first
            local import_error
            import_error=$(PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" -c \
                "SET session_replication_role = 'replica'; \\COPY ${table}(${local_cols}) FROM '${csv_file}' WITH (FORMAT CSV, HEADER)" 2>&1)

            if echo "$import_error" | grep -q "ERROR"; then
                log_warning "  COPY failed for ${table}: ${import_error}"
                log_info "  Trying INSERT fallback..."

                # Fallback: Generate INSERT statements
                sync_table_with_inserts "${table}" "${local_cols}" "${prod_url}" "${local_url}"
            fi

            local count=$(PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" -t -c "SELECT COUNT(*) FROM ${table};" 2>/dev/null | tr -d '[:space:]')

            if [[ "${count}" == "${prod_count}" ]]; then
                log_success "  ${table}: ${count} rows ✓"
            elif [[ "${count}" -gt "0" ]]; then
                log_warning "  ${table}: ${count}/${prod_count} rows (partial)"
            else
                log_error "  ${table}: 0/${prod_count} rows (FAILED)"
                failed_tables+=("${table}")
            fi
        else
            log_warning "  Failed to export ${table}: ${copy_error}"
            failed_tables+=("${table}")
        fi
    done

    # Report failed tables
    if [[ ${#failed_tables[@]} -gt 0 ]]; then
        echo ""
        log_warning "Failed to sync ${#failed_tables[@]} tables:"
        for t in "${failed_tables[@]}"; do
            echo "  - ${t}"
        done
    fi

    # Re-enable triggers
    PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" -c "SET session_replication_role = 'origin';" 2>/dev/null
}

verify_sync() {
    log_section "Verifying Sync"

    local prod_url="$(prod_db_url)"
    local local_url="$(local_conn)"

    # Check all tables with significant data
    local tables_to_check="clients venues productions events cast_roles cast_assignments profiles professional_profiles accounts event_showtimes hire_orders reimbursement_requests reimbursement_line_items reimbursement_documents dancer_contract_details dancer_links dancer_locations user_signatures countries jurisdictions legal_status_types"

    echo ""
    printf "%-30s %15s %15s\n" "Table" "Production" "Local"
    printf "%-30s %15s %15s\n" "-----" "----------" "-----"

    for table in ${tables_to_check}; do
        local prod_count local_count

        prod_count=$(PGPASSWORD="${SUPABASE_DB_PASSWORD_PROD}" psql "${prod_url}" \
            -t -c "SELECT COUNT(*) FROM public.${table};" 2>/dev/null | tr -d '[:space:]') || prod_count="N/A"

        local_count=$(PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" \
            -t -c "SELECT COUNT(*) FROM public.${table};" 2>/dev/null | tr -d '[:space:]') || local_count="N/A"

        if [[ "${prod_count}" == "${local_count}" ]]; then
            printf "%-30s %15s %15s ✅\n" "${table}" "${prod_count}" "${local_count}"
        else
            printf "%-30s %15s %15s ⚠️\n" "${table}" "${prod_count}" "${local_count}"
        fi
    done

    if [[ "${INCLUDE_AUTH}" == "true" ]]; then
        echo ""
        local prod_auth local_auth

        prod_auth=$(PGPASSWORD="${SUPABASE_DB_PASSWORD_PROD}" psql "${prod_url}" \
            -t -c "SELECT COUNT(*) FROM auth.users;" 2>/dev/null | tr -d '[:space:]') || prod_auth="N/A"

        local_auth=$(PGPASSWORD="${LOCAL_PASSWORD}" psql "${local_url}" \
            -t -c "SELECT COUNT(*) FROM auth.users;" 2>/dev/null | tr -d '[:space:]') || local_auth="N/A"

        if [[ "${prod_auth}" == "${local_auth}" ]]; then
            printf "%-30s %15s %15s ✅\n" "auth.users" "${prod_auth}" "${local_auth}"
        else
            printf "%-30s %15s %15s ⚠️\n" "auth.users" "${prod_auth}" "${local_auth}"
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
    log_section "Production → Local Database Sync"

    echo -e "${BOLD}Timestamp:${NC} ${TIMESTAMP}"
    echo -e "${BOLD}Source:${NC}    Production (${PROD_PROJECT_REF})"
    echo -e "${BOLD}Target:${NC}    Local (127.0.0.1:${LOCAL_PORT})"
    echo -e "${BOLD}Include Auth:${NC} ${INCLUDE_AUTH}"
    echo ""

    load_credentials
    verify_local_supabase
    verify_safety

    # Try Supabase CLI dump first, fall back to manual sync
    if dump_production; then
        truncate_local
        restore_to_local
    else
        log_warning "Supabase CLI dump failed, using manual sync..."
        truncate_local
        manual_sync
    fi

    verify_sync

    log_section "Sync Complete"
    log_success "Production data has been copied to local"
    log_info "Local Supabase Studio: http://127.0.0.1:54323"
    echo ""
    log_info "You can now test with production data locally."
    log_info "Login with any production user email + password 'password'"
}

main

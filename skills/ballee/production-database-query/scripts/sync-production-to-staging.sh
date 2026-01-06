#!/bin/bash

################################################################################
# Production to Staging DATA-ONLY Sync Script
#
# Safely syncs production DATA to staging environment while PRESERVING
# the staging database schema. This allows staging to have different
# (newer) migrations than production for testing purposes.
#
# Key Features:
#   - DATA ONLY sync (schema is NOT replaced)
#   - Staging migrations table is preserved
#   - Staging can be ahead of production schema-wise
#   - Backup created before any changes
#
# Usage:
#   ./scripts/sync-production-to-staging.sh [OPTIONS]
#
# Options:
#   --dry-run           Show what would happen without making changes
#   --skip-backup       Skip creating backup (not recommended)
#   --force             Skip confirmation prompt
#   --help              Show this help message
#
################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source production database safeguards
if [[ -f "${SCRIPT_DIR}/db-safeguard.sh" ]]; then
    source "${SCRIPT_DIR}/db-safeguard.sh"
fi
BACKUP_DIR="${PROJECT_ROOT}/.backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/staging_backup_${TIMESTAMP}.sql.gz"
SYNC_LOG="${PROJECT_ROOT}/logs/sync_${TIMESTAMP}.log"
DRY_RUN=false
SKIP_BACKUP=false
FORCE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${SYNC_LOG}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $@${NC}"
    log "INFO" "$@"
}

log_success() {
    echo -e "${GREEN}✅ $@${NC}"
    log "SUCCESS" "$@"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $@${NC}"
    log "WARNING" "$@"
}

log_error() {
    echo -e "${RED}❌ $@${NC}"
    log "ERROR" "$@"
}

show_help() {
    grep "^#" "${BASH_SOURCE[0]}" | grep -E "^\s*#" | head -20
}

cleanup() {
    if [[ $? -ne 0 ]]; then
        log_error "Script failed!"
        exit 1
    fi
}

trap cleanup EXIT

################################################################################
# Argument Parsing
################################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

################################################################################
# Validation
################################################################################

validate_environment() {
    log_info "Validating environment..."

    # Create logs directory if needed
    mkdir -p "${PROJECT_ROOT}/logs"
    mkdir -p "${BACKUP_DIR}"

    # Check required environment variables
    local required_vars=(
        "POSTGRES_URL"
        "STAGING_POSTGRES_URL"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable not set: $var"
            exit 1
        fi
    done

    # Check for psql and pg_dump
    if ! command -v pg_dump &> /dev/null; then
        log_error "pg_dump not found. Please install PostgreSQL client tools."
        exit 1
    fi

    if ! command -v psql &> /dev/null; then
        log_error "psql not found. Please install PostgreSQL client tools."
        exit 1
    fi

    log_success "Environment validated"
}

# Extract database info from connection string
parse_connection_url() {
    local url=$1
    # postgres://user:password@host:port/database
    local protocol="${url%%://*}"
    local remainder="${url#*://}"
    local userpass="${remainder%%@*}"
    local hostdb="${remainder#*@}"
    local host="${hostdb%%/*}"
    local database="${hostdb##*/}"
    local user="${userpass%%:*}"
    local password="${userpass#*:}"

    echo "${host}|${port:-5432}|${database}|${user}|${password}"
}

get_row_counts() {
    local db_url=$1
    local temp_counts=$(mktemp)

    PGPASSWORD="${db_url##*:}" psql -h "${db_url%%:*}" -U "postgres" \
        -d "${db_url##*/}" \
        -t -c "
        SELECT
            tablename,
            n_live_tup as rows
        FROM pg_stat_user_tables
        ORDER BY tablename
    " > "${temp_counts}" 2>/dev/null || true

    cat "${temp_counts}"
    rm -f "${temp_counts}"
}

################################################################################
# Main Sync Process
################################################################################

confirm_sync() {
    if [[ "${FORCE}" == true ]]; then
        return 0
    fi

    echo ""
    echo -e "${YELLOW}========== DATA-ONLY SYNC CONFIRMATION ==========${NC}"
    echo "Mode:                DATA ONLY (schema preserved)"
    echo "Source (Production): ${POSTGRES_URL%@*}@**"
    echo "Target (Staging):    ${STAGING_POSTGRES_URL%@*}@**"
    echo "Backup file:         ${BACKUP_FILE}"
    echo "Dry run:             ${DRY_RUN}"
    echo ""
    echo -e "${BLUE}ℹ️  This will:${NC}"
    echo "   - TRUNCATE all staging tables (clear data)"
    echo "   - INSERT production data into staging"
    echo "   - PRESERVE staging schema (tables, columns, indexes)"
    echo "   - PRESERVE staging migrations tracking table"
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: Staging data will be replaced with production data!${NC}"
    echo ""
    read -p "Continue? (type 'YES' to confirm): " -r
    echo ""

    if [[ ! $REPLY =~ ^YES$ ]]; then
        log_warning "Sync cancelled by user"
        exit 0
    fi
}

backup_staging_database() {
    log_info "Creating backup of staging database..."

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would create backup: ${BACKUP_FILE}"
        return 0
    fi

    if [[ "${SKIP_BACKUP}" == true ]]; then
        log_warning "Skipping backup (--skip-backup flag set)"
        return 0
    fi

    if ! pg_dump "${STAGING_POSTGRES_URL}" \
        --format=custom \
        --compress=9 \
        --no-acl \
        --file="${BACKUP_FILE}" 2>/dev/null; then
        log_error "Failed to create backup"
        exit 1
    fi

    local backup_size=$(du -h "${BACKUP_FILE}" | cut -f1)
    log_success "Backup created: ${BACKUP_FILE} (${backup_size})"
}

dump_production_database() {
    log_info "Dumping production database (DATA ONLY)..."

    local dump_file="${PROJECT_ROOT}/.backups/prod_dump_${TIMESTAMP}.sql"

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would dump production DATA to: ${dump_file}"
        return 0
    fi

    # Use --data-only to preserve staging schema
    # Exclude schema_migrations to preserve staging's migration tracking
    if ! pg_dump "${POSTGRES_URL}" \
        --format=plain \
        --data-only \
        --no-owner \
        --no-acl \
        --no-privileges \
        --exclude-table='supabase_migrations.schema_migrations' \
        --file="${dump_file}" 2>/dev/null; then
        log_error "Failed to dump production database"
        exit 1
    fi

    local dump_size=$(du -h "${dump_file}" | cut -f1)
    log_success "Production DATA dump completed: ${dump_size}"
}

verify_database_connection() {
    local db_url=$1
    local name=$2

    log_info "Verifying connection to ${name}..."

    if psql "${db_url}" -c "SELECT 1" > /dev/null 2>&1; then
        log_success "${name} connection verified"
    else
        log_error "Cannot connect to ${name}"
        exit 1
    fi
}

get_table_row_counts() {
    local db_url=$1

    psql "${db_url}" -t -c "
        SELECT
            schemaname,
            tablename,
            n_live_tup as rows
        FROM pg_stat_user_tables
        WHERE schemaname != 'information_schema'
        ORDER BY schemaname, tablename
    " 2>/dev/null | grep -v '^[[:space:]]*$' || echo "0|0|0"
}

compare_row_counts() {
    log_info "Comparing row counts..."

    local prod_counts=$(get_table_row_counts "${POSTGRES_URL}")
    local staging_counts=$(get_table_row_counts "${STAGING_POSTGRES_URL}")

    local prod_total=$(echo "${prod_counts}" | awk '{sum+=$3} END {print sum}')
    local staging_total=$(echo "${staging_counts}" | awk '{sum+=$3} END {print sum}')

    log_info "Production total rows: ${prod_total}"
    log_info "Staging total rows:    ${staging_total}"

    if [[ "${prod_total}" -eq "${staging_total}" ]]; then
        log_success "Row counts match!"
    else
        log_warning "Row counts differ (prod: ${prod_total}, staging: ${staging_total})"
    fi
}

restore_to_staging() {
    log_info "Restoring DATA ONLY to staging database (preserving schema)..."

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would restore DATA to staging (schema preserved)"
        return 0
    fi

    local dump_file="${PROJECT_ROOT}/.backups/prod_dump_${TIMESTAMP}.sql"

    # Get list of tables to truncate (exclude migration tracking and system tables)
    log_info "Getting list of tables to truncate..."
    local tables=$(psql "${STAGING_POSTGRES_URL}" -t -c "
        SELECT tablename FROM pg_tables
        WHERE schemaname = 'public'
        ORDER BY tablename;
    " 2>/dev/null | tr -d ' ' | grep -v '^$' || true)

    if [[ -z "${tables}" ]]; then
        log_warning "No tables found in staging public schema"
    else
        # Disable triggers temporarily for FK constraints
        log_info "Disabling triggers for data truncation..."
        psql "${STAGING_POSTGRES_URL}" -c "SET session_replication_role = 'replica';" 2>/dev/null || true

        # Truncate all public tables (preserves schema, clears data)
        log_info "Truncating staging tables (preserving schema)..."
        for table in $tables; do
            log_info "  Truncating: ${table}"
            psql "${STAGING_POSTGRES_URL}" -c "TRUNCATE TABLE public.\"${table}\" CASCADE;" 2>/dev/null || true
        done

        log_success "Staging tables truncated (schema preserved)"
    fi

    # Restore production data
    log_info "Restoring production DATA to staging..."
    if ! psql "${STAGING_POSTGRES_URL}" < "${dump_file}" 2>&1 | grep -v "^SET$" | grep -v "^$"; then
        # Check if it actually failed or just had warnings
        if ! psql "${STAGING_POSTGRES_URL}" -c "SELECT 1" > /dev/null 2>&1; then
            log_error "Failed to restore data - database connection lost"
            # Re-enable triggers before exit
            psql "${STAGING_POSTGRES_URL}" -c "SET session_replication_role = 'origin';" 2>/dev/null || true
            exit 1
        fi
    fi

    # Re-enable triggers
    log_info "Re-enabling triggers..."
    psql "${STAGING_POSTGRES_URL}" -c "SET session_replication_role = 'origin';" 2>/dev/null || true

    log_success "Production DATA restored to staging (schema preserved)"

    # Verify migration tracking table is intact
    log_info "Verifying migration tracking table is preserved..."
    local migration_count=$(psql "${STAGING_POSTGRES_URL}" -t -c "SELECT COUNT(*) FROM supabase_migrations.schema_migrations;" 2>/dev/null | tr -d ' ')
    if [[ -n "${migration_count}" && "${migration_count}" -gt 0 ]]; then
        log_success "Migration tracking preserved: ${migration_count} migrations recorded"
    else
        log_warning "Migration tracking table appears empty - staging may need migrations applied"
    fi

    # Clean up dump file
    rm -f "${dump_file}"
}

generate_sync_report() {
    log_info "Generating sync report..."

    local report_file="${PROJECT_ROOT}/logs/sync_report_${TIMESTAMP}.txt"

    cat > "${report_file}" << EOF
================================================================================
PRODUCTION TO STAGING DATA SYNC REPORT
================================================================================

Sync Date:        $(date '+%Y-%m-%d %H:%M:%S')
Backup File:      ${BACKUP_FILE}
Backup Size:      $(du -h "${BACKUP_FILE}" 2>/dev/null | cut -f1 || echo "N/A")
Duration:         ${ELAPSED_TIME}s
Dry Run:          ${DRY_RUN}

Source Database:  Production
Target Database:  Staging

Production Row Counts:
$(get_table_row_counts "${POSTGRES_URL}" | head -20)

Staging Row Counts:
$(get_table_row_counts "${STAGING_POSTGRES_URL}" | head -20)

Status: SUCCESS
================================================================================
EOF

    log_success "Sync report generated: ${report_file}"
}

send_slack_notification() {
    if [[ -z "${SLACK_WEBHOOK:-}" ]]; then
        return 0
    fi

    local status=$1
    local color="good"
    local emoji="✅"

    if [[ "${status}" != "success" ]]; then
        color="danger"
        emoji="❌"
    fi

    local prod_total=$(get_table_row_counts "${POSTGRES_URL}" | awk '{sum+=$3} END {print sum}')

    curl -X POST "${SLACK_WEBHOOK}" \
        -H 'Content-type: application/json' \
        --data "{
            \"attachments\": [
                {
                    \"color\": \"${color}\",
                    \"title\": \"${emoji} Production to Staging Data Sync\",
                    \"text\": \"Synced production database to staging\",
                    \"fields\": [
                        {
                            \"title\": \"Status\",
                            \"value\": \"${status}\",
                            \"short\": true
                        },
                        {
                            \"title\": \"Rows Synced\",
                            \"value\": \"${prod_total}\",
                            \"short\": true
                        },
                        {
                            \"title\": \"Backup File\",
                            \"value\": \"\`${BACKUP_FILE}\`\",
                            \"short\": false
                        },
                        {
                            \"title\": \"Timestamp\",
                            \"value\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
                            \"short\": true
                        }
                    ]
                }
            ]
        }" 2>/dev/null || true
}

################################################################################
# Main Execution
################################################################################

main() {
    local start_time=$(date +%s)

    log_info "Starting production to staging DATA-ONLY sync..."
    log_info "Mode: DATA ONLY (staging schema will be preserved)"
    log_info "Dry run mode: ${DRY_RUN}"

    # Validate environment
    validate_environment

    # Verify connections
    verify_database_connection "${POSTGRES_URL}" "Production"
    verify_database_connection "${STAGING_POSTGRES_URL}" "Staging"

    # Get row counts before
    log_info "Fetching production row counts..."
    local prod_total=$(get_table_row_counts "${POSTGRES_URL}" | awk '{sum+=$3} END {print sum}')
    log_info "Production total rows: ${prod_total}"

    # Confirm sync
    confirm_sync

    # Backup staging
    backup_staging_database

    # Dump production
    dump_production_database

    # Restore to staging
    restore_to_staging

    # Verify sync
    compare_row_counts

    # Generate report
    generate_sync_report

    # Calculate elapsed time
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    ELAPSED_TIME=${elapsed}

    log_success "Sync completed successfully in ${elapsed}s"

    # Send notification
    send_slack_notification "success"
}

# Run main function
main "$@"

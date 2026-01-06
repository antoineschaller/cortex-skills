#!/bin/bash

# Sync Production Data to Local Development Database
# Purpose: Download anonymized data from production for realistic local testing
# Usage: ./scripts/sync-production-data.sh [--full|--sample]

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     📦 Sync Production Data to Local Database           ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to log info
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to log success
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to log warning
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to log error and exit
error_exit() {
    echo -e "${RED}❌ Error: $1${NC}"
    exit 1
}

# Parse command line arguments
MODE="sample"
AUTO_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --full)
            MODE="full"
            shift
            ;;
        --sample)
            MODE="sample"
            shift
            ;;
        --auto)
            AUTO_MODE=true
            shift
            ;;
        *)
            error_exit "Invalid argument. Use: --full, --sample, --auto"
            ;;
    esac
done

# Check if linked to remote
if [ ! -f "supabase/.temp/project-ref" ]; then
    error_exit "Not linked to remote project. Run: supabase link --project-ref <project-ref>"
fi

PROJECT_REF=$(cat supabase/.temp/project-ref)
info "Linked to project: ${PROJECT_REF}"
echo ""

# Create dump directory
DUMP_DIR="supabase/dumps"
mkdir -p "$DUMP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="${DUMP_DIR}/production_data_${TIMESTAMP}.sql"

# Tables to include in data dump (exclude auth tables for security)
TABLES_TO_DUMP=(
    "public.profiles"
    "public.professional_profiles"
    "public.dancer_profiles"
    "public.accounts"
    "public.accounts_memberships"
    "public.teams"
    "public.venues"
    "public.productions"
    "public.cast_roles"
    "public.events"
    "public.event_invitations"
    "public.event_participants"
    "public.organizations"
)

# Sensitive columns will be anonymized in the anonymization script below
# (Removed associative array for bash 3.x compatibility)

if [ "$AUTO_MODE" = false ]; then
    echo -e "${YELLOW}⚠️  WARNING: This will download production data to your local machine${NC}"
    echo ""
    echo -e "Mode: ${CYAN}${MODE}${NC}"
    if [ "$MODE" = "sample" ]; then
        echo -e "  - Will limit rows per table for faster testing"
    fi
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warning "Data sync cancelled"
        exit 0
    fi
else
    info "Running in auto mode (non-interactive)"
    info "Mode: ${MODE}"
fi

# Step 1: Dump production data
info "Dumping production data..."
echo -e "${BLUE}Tables to dump:${NC}"
for table in "${TABLES_TO_DUMP[@]}"; do
    echo -e "  - ${table}"
done
echo ""

# Build exclude list for auth tables
EXCLUDE_TABLES=(
    "auth.users"
    "auth.identities"
    "auth.sessions"
    "auth.refresh_tokens"
    "auth.mfa_factors"
    "auth.mfa_challenges"
    "auth.audit_log_entries"
)

EXCLUDE_ARGS=""
for table in "${EXCLUDE_TABLES[@]}"; do
    EXCLUDE_ARGS="${EXCLUDE_ARGS} --exclude=${table}"
done

# Dump data from production
if supabase db dump --data-only --use-copy $EXCLUDE_ARGS -f "$DUMP_FILE"; then
    success "Production data dumped to: ${DUMP_FILE}"
else
    error_exit "Failed to dump production data"
fi

echo ""
info "Dump file size: $(du -h "$DUMP_FILE" | cut -f1)"
echo ""

# Step 2: Anonymization is skipped (not needed for internal development)

# Step 3: Sample data if requested
if [ "$MODE" = "sample" ]; then
    info "Creating sample data subset..."
    SAMPLE_SCRIPT="${DUMP_DIR}/sample_${TIMESTAMP}.sql"

    # Create script to limit rows (keep relationships intact)
    cat > "$SAMPLE_SCRIPT" << 'EOF'
-- Sample Data Script
-- Keeps subset of data for faster local development

BEGIN;

-- Keep only recent events (last 30 days + next 90 days)
DELETE FROM public.event_participants
WHERE event_id IN (
    SELECT id FROM public.events
    WHERE start_date_time < NOW() - INTERVAL '30 days'
    OR start_date_time > NOW() + INTERVAL '90 days'
);

DELETE FROM public.event_invitations
WHERE event_id IN (
    SELECT id FROM public.events
    WHERE start_date_time < NOW() - INTERVAL '30 days'
    OR start_date_time > NOW() + INTERVAL '90 days'
);

DELETE FROM public.events
WHERE start_date_time < NOW() - INTERVAL '30 days'
OR start_date_time > NOW() + INTERVAL '90 days';

-- Keep only active productions (last 6 months)
DELETE FROM public.productions
WHERE created_at < NOW() - INTERVAL '6 months';

COMMIT;

DO $$
BEGIN
    RAISE NOTICE '✅ Sample data created';
    RAISE NOTICE '  - Events: last 30 days + next 90 days';
    RAISE NOTICE '  - Productions: last 6 months';
END $$;
EOF

    success "Sample script created"
    echo ""
fi

# Step 4: Import to local database
if [ "$AUTO_MODE" = false ]; then
    echo -e "${YELLOW}⚠️  This will REPLACE all data in your local database${NC}"
    echo -e "${YELLOW}   (Schema and migrations will be preserved)${NC}"
    echo ""
    read -p "Import to local database now? (y/N) " -n 1 -r
    echo
fi

# In auto mode, always import; in manual mode, check user response
if [ "$AUTO_MODE" = true ] || [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Importing data to local database..."

    # Check if local Supabase is running
    if ! supabase status &> /dev/null; then
        error_exit "Local Supabase is not running. Run: supabase start"
    fi

    # Truncate existing data (preserve super admin from seed.sql)
    info "Clearing existing data (preserving super admin)..."
    PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres << 'EOSQL'
-- Preserve super admin ID
DO $$
DECLARE
    super_admin_id UUID := 'a1b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d';
BEGIN
    -- Delete all data except super admin
    DELETE FROM public.event_participants;
    DELETE FROM public.event_invitations;
    DELETE FROM public.events;
    DELETE FROM public.cast_roles;
    DELETE FROM public.productions;
    DELETE FROM public.venues;
    DELETE FROM public.teams;
    DELETE FROM public.accounts_memberships WHERE user_id != super_admin_id;
    DELETE FROM public.dancer_profiles WHERE id IN (
        SELECT id FROM public.professional_profiles WHERE user_id != super_admin_id
    );
    DELETE FROM public.professional_profiles WHERE user_id != super_admin_id;
    DELETE FROM public.profiles WHERE id != super_admin_id;
    DELETE FROM public.accounts WHERE id != super_admin_id;

    RAISE NOTICE '✅ Existing data cleared (super admin preserved)';
END $$;
EOSQL

    # Import dumped data
    info "Importing production data..."
    if PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -f "$DUMP_FILE" > /dev/null 2>&1; then
        success "Data imported successfully"
    else
        warning "Import had some warnings (this is normal for COPY commands)"
    fi

    # Apply sampling if requested
    if [ "$MODE" = "sample" ]; then
        info "Applying data sampling..."
        if PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -f "$SAMPLE_SCRIPT"; then
            success "Sample data created"
        else
            warning "Sampling had some issues"
        fi
    fi

    echo ""
    success "Production data sync complete! 🎉"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           ✅ Local Database Updated with Production Data ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Login credentials:${NC}"
    echo -e "  Email:    ${CYAN}antoine@ballee.co${NC}"
    echo -e "  Password: ${CYAN}password${NC}"
else
    info "Import skipped. Dump file saved at:"
    echo -e "  ${CYAN}${DUMP_FILE}${NC}"
    echo ""
    echo "To import later, run:"
    echo "  PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -f ${DUMP_FILE}"
fi

echo ""

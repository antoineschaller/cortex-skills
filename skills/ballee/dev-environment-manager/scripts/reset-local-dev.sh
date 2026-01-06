#!/bin/bash

# Local Development Database Reset Script
# Purpose: Complete database reset with production data sync
# Usage: ./scripts/reset-local-dev.sh [--clean-volumes] [--skip-sync] [--sample]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CLEAN_VOLUMES=false
SKIP_SYNC=false
SYNC_MODE="sample"  # Default to sample data for faster resets
START_TIME=$(date +%s)

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --clean-volumes)
      CLEAN_VOLUMES=true
      shift
      ;;
    --skip-sync)
      SKIP_SYNC=true
      shift
      ;;
    --full)
      SYNC_MODE="full"
      shift
      ;;
    --sample)
      SYNC_MODE="sample"
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [--clean-volumes] [--skip-sync] [--full|--sample]"
      echo ""
      echo "Options:"
      echo "  --clean-volumes  Deep clean Docker volumes before reset"
      echo "  --skip-sync      Skip production data sync, use basic seed only"
      echo "  --sample         Sync sample production data (default, faster)"
      echo "  --full           Sync full production data (slower, complete dataset)"
      exit 1
      ;;
  esac
done

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       🔄 Ballee Local Development Database Reset        ║${NC}"
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

# Step 1: Stop Supabase
info "Stopping Supabase containers..."
supabase stop || warning "Supabase was not running"
success "Supabase stopped"
echo ""

# Step 2: Clean Docker volumes if requested
if [ "$CLEAN_VOLUMES" = true ]; then
    info "Cleaning Docker volumes (deep clean)..."
    docker volume ls --filter label=com.supabase.cli.project=ballee -q | xargs -r docker volume rm || true
    success "Docker volumes cleaned"
    echo ""
fi

# Step 3: Start Supabase
info "Starting Supabase..."
supabase start || error_exit "Failed to start Supabase"
success "Supabase started"
echo ""

# Step 4: Reset database (apply all migrations)
info "Resetting database (applying all migrations)..."
RESET_OUTPUT=$(supabase db reset 2>&1 || true)
if echo "$RESET_OUTPUT" | grep -q "ERROR:"; then
    echo "$RESET_OUTPUT" | tail -30
    error_exit "Database reset failed with errors"
fi
success "Database reset complete"
echo ""

# Step 5: Verify seed ran automatically
info "Verifying seed data..."
USER_COUNT=$(PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -t -c "SELECT COUNT(*) FROM auth.users WHERE email = 'antoine@ballee.co';" | tr -d ' ')

if [ "$USER_COUNT" -eq "0" ]; then
    warning "Seed did not run automatically, applying manually..."
    ./scripts/apply-seed.sh || error_exit "Manual seed failed"
else
    success "Seed data verified (antoine@ballee.co exists)"
fi
echo ""

# Step 5.5: Sync production data (unless skipped)
if [ "$SKIP_SYNC" = false ]; then
    info "Syncing production data (mode: ${SYNC_MODE})..."
    echo ""

    # Check if linked to remote
    if [ -f "supabase/.temp/project-ref" ]; then
        # Run sync script non-interactively
        if ./scripts/sync-production-data.sh --${SYNC_MODE} --auto; then
            success "Production data synced successfully"
        else
            warning "Production data sync failed, continuing with basic seed data"
            info "You can manually sync later with: ./scripts/sync-production-data.sh"
        fi
    else
        warning "Not linked to remote project, skipping production data sync"
        info "To link: supabase link --project-ref <project-ref>"
        info "Continuing with basic seed data only"
    fi
    echo ""
else
    info "Production data sync skipped (--skip-sync flag used)"
    echo ""
fi

# Step 6: Verify database functions
info "Verifying database functions..."
if ./scripts/quick-test.sh > /dev/null 2>&1; then
    success "All database functions verified"
else
    warning "Some database functions failed verification"
    echo ""
    info "Running detailed function check..."
    ./scripts/quick-test.sh
fi
echo ""

# Step 7: Validate database contracts
info "Validating database schema contracts..."
if ./scripts/validate-db-contracts.sh > /dev/null 2>&1; then
    success "All schema contracts valid"
else
    warning "Schema contract validation failed"
    echo ""
    info "Running detailed contract check..."
    ./scripts/validate-db-contracts.sh
fi
echo ""

# Step 8: Test login
info "Testing super-admin login..."
if [ -f "/tmp/test-login.js" ]; then
    LOGIN_RESULT=$(node /tmp/test-login.js 2>&1 || true)
    if echo "$LOGIN_RESULT" | grep -q "Login successful"; then
        success "Super-admin login verified"
    else
        warning "Login test failed, but database is ready"
    fi
else
    warning "Login test script not found at /tmp/test-login.js"
fi
echo ""

# Step 9: Display connection info
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 Local Development Environment Ready!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Database:${NC}      postgresql://postgres:postgres@127.0.0.1:54322/postgres"
echo -e "${BLUE}API:${NC}           http://127.0.0.1:54321"
echo -e "${BLUE}Studio:${NC}        http://127.0.0.1:54323"
echo ""
echo -e "${GREEN}Super Admin Login:${NC}"
echo -e "  Email:    ${CYAN}antoine@ballee.co${NC}"
echo -e "  Password: ${CYAN}password${NC}"
echo -e "  Role:     ${CYAN}super-admin${NC}"
echo ""
echo -e "${BLUE}Reset completed in ${DURATION}s${NC}"
echo ""

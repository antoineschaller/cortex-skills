#!/bin/bash

# Sync Migrations from Remote Database
# Purpose: Ensure local migration history matches production exactly
# Usage: ./scripts/sync-migrations-from-remote.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     🔄 Sync Migrations from Remote Production          ║${NC}"
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

# Check if linked to remote
if [ ! -f "supabase/.temp/project-ref" ]; then
    error_exit "Not linked to remote project. Run: supabase link --project-ref <project-ref>"
fi

PROJECT_REF=$(cat supabase/.temp/project-ref)
info "Linked to project: ${PROJECT_REF}"
echo ""

# Step 1: Fetch remote migration list
info "Fetching remote migration history..."
REMOTE_MIGRATIONS=$(supabase migration list 2>&1 | grep -E "^[0-9]{14}" | awk '{print $1}' | sort || true)
REMOTE_COUNT=$(echo "$REMOTE_MIGRATIONS" | wc -l | tr -d ' ')
success "Found ${REMOTE_COUNT} migrations in remote database"
echo ""

# Step 2: Get local migrations
info "Scanning local migrations..."
LOCAL_MIGRATIONS=$(ls -1 supabase/migrations/*.sql 2>/dev/null | grep -v ".skip" | xargs -n1 basename | sed 's/_.*$//' | sort || true)
LOCAL_COUNT=$(echo "$LOCAL_MIGRATIONS" | wc -l | tr -d ' ')
success "Found ${LOCAL_COUNT} migration files locally"
echo ""

# Step 3: Check for migrations applied locally but not on remote
info "Checking local database migration status..."
LOCAL_APPLIED=$(PGPASSWORD=postgres psql -h 127.0.0.1 -p 54322 -U postgres -d postgres -t -c "SELECT version FROM supabase_migrations.schema_migrations ORDER BY version;" 2>/dev/null | tr -d ' ' | grep -v '^$' || true)
LOCAL_APPLIED_COUNT=$(echo "$LOCAL_APPLIED" | wc -l | tr -d ' ')
success "Found ${LOCAL_APPLIED_COUNT} migrations applied locally"
echo ""

# Step 4: Compare local vs remote
info "Comparing local and remote migrations..."
NEEDS_REPAIR=""
REPAIR_COUNT=0

for migration in $LOCAL_APPLIED; do
    if ! echo "$REMOTE_MIGRATIONS" | grep -q "^${migration}$"; then
        warning "Migration ${migration} is applied locally but NOT on remote"
        NEEDS_REPAIR="${NEEDS_REPAIR}${migration}\n"
        REPAIR_COUNT=$((REPAIR_COUNT + 1))
    fi
done

if [ $REPAIR_COUNT -eq 0 ]; then
    success "All local migrations are synced with remote ✨"
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           ✅ Migration History in Sync!                  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
else
    echo ""
    warning "${REPAIR_COUNT} migrations need repair on remote"
    echo -e "\nMigrations to repair:"
    echo -e "${YELLOW}${NEEDS_REPAIR}${NC}"

    echo ""
    read -p "Do you want to mark these as applied on remote? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Repairing migration history on remote..."
        for migration in $(echo -e "$NEEDS_REPAIR" | grep -v '^$'); do
            echo -e "${BLUE}  Repairing: ${migration}${NC}"
            supabase migration repair --status applied "$migration" || warning "Failed to repair $migration"
        done
        success "Migration repair complete"
    else
        warning "Migration repair cancelled"
        echo ""
        echo "To manually repair, run:"
        for migration in $(echo -e "$NEEDS_REPAIR" | grep -v '^$'); do
            echo "  supabase migration repair --status applied $migration"
        done
    fi
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Summary:${NC}"
echo -e "  Remote migrations:       ${CYAN}${REMOTE_COUNT}${NC}"
echo -e "  Local migration files:   ${CYAN}${LOCAL_COUNT}${NC}"
echo -e "  Local applied:           ${CYAN}${LOCAL_APPLIED_COUNT}${NC}"
echo -e "  Needs repair:            ${CYAN}${REPAIR_COUNT}${NC}"
echo ""

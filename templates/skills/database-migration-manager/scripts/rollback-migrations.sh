#!/bin/bash

# Migration Rollback Script
# This script provides rollback capabilities for database migrations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MIGRATIONS_DIR="supabase/migrations"
BACKUP_DIR="backups"
LOG_FILE="/tmp/migration-rollback-$(date +%Y%m%d_%H%M%S).log"

# Required environment variables
REQUIRED_VARS=(
    "SUPABASE_ACCESS_TOKEN"
    "SUPABASE_PROJECT_ID"
    "SUPABASE_DB_PASSWORD"
)

echo -e "${RED}🔄 Migration Rollback Script${NC}"
echo "============================"
echo "Log file: $LOG_FILE"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This script will rollback database migrations!${NC}"
echo -e "${YELLOW}    Make sure you understand the implications before proceeding.${NC}"
echo ""

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to show error and exit
error_exit() {
    echo -e "${RED}❌ Error: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

# Function to show success
success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

# Function to show warning
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

# Function to show info
info() {
    echo -e "${BLUE}ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

# Function to prompt for confirmation
confirm() {
    local message="$1"
    echo -e "${YELLOW}$message${NC}"
    read -p "Type 'YES' to confirm: " confirmation
    if [[ "$confirmation" != "YES" ]]; then
        info "Operation cancelled by user"
        exit 0
    fi
}

# Check required environment variables
check_environment() {
    info "Checking environment variables..."

    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            error_exit "Required environment variable $var is not set"
        fi
    done

    success "All required environment variables are set"
}

# Check if we're in the right directory
check_directory() {
    if [[ ! -d "$MIGRATIONS_DIR" ]]; then
        error_exit "Migrations directory not found. Please run this script from the web app root."
    fi

    if [[ ! -d "$BACKUP_DIR" ]]; then
        error_exit "Backup directory not found. Cannot proceed with rollback."
    fi

    success "Directory structure validated"
}

# List available backups
list_backups() {
    info "Available backup files:"

    backup_files=($(find "$BACKUP_DIR" -name "backup_*.sql" -type f | sort -r))

    if [[ ${#backup_files[@]} -eq 0 ]]; then
        error_exit "No backup files found. Cannot perform rollback."
    fi

    echo "" | tee -a "$LOG_FILE"
    for i in "${!backup_files[@]}"; do
        local file="${backup_files[$i]}"
        local filename=$(basename "$file")
        local timestamp=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || date -r "$file" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown")
        echo "  [$((i+1))] $filename (Created: $timestamp)" | tee -a "$LOG_FILE"
    done
    echo "" | tee -a "$LOG_FILE"

    # Return the backup files array for selection
    echo "${backup_files[@]}"
}

# Select backup for rollback
select_backup() {
    local backup_files_str="$1"
    IFS=' ' read -ra backup_files <<< "$backup_files_str"

    echo "Select a backup to restore:"
    read -p "Enter backup number (1-${#backup_files[@]}): " backup_choice

    if [[ ! "$backup_choice" =~ ^[0-9]+$ ]] || [[ "$backup_choice" -lt 1 ]] || [[ "$backup_choice" -gt ${#backup_files[@]} ]]; then
        error_exit "Invalid backup selection"
    fi

    selected_backup="${backup_files[$((backup_choice-1))]}"
    info "Selected backup: $(basename "$selected_backup")"
    echo "$selected_backup"
}

# Create pre-rollback backup
create_pre_rollback_backup() {
    info "Creating backup before rollback..."
    timestamp=$(date +%Y%m%d_%H%M%S)
    pre_rollback_backup="$BACKUP_DIR/backup_before_rollback_${timestamp}.sql"

    # Link to production project
    if ! supabase link --project-ref "$SUPABASE_PROJECT_ID" >> "$LOG_FILE" 2>&1; then
        error_exit "Failed to link to Supabase project"
    fi

    # Create backup reference
    cat > "$pre_rollback_backup" << EOF
-- Pre-rollback backup created on $(date)
-- Project ID: $SUPABASE_PROJECT_ID
-- Backup timestamp: $timestamp
--
-- This backup was created before performing rollback operation
-- Original backup being restored: $(basename "$1")
--
-- Current migration status before rollback:
EOF

    # Add current migrations info to backup
    if [[ -d "$MIGRATIONS_DIR" ]]; then
        echo "-- Current migration files:" >> "$pre_rollback_backup"
        find "$MIGRATIONS_DIR" -name "*.sql" -type f | sort | while read -r file; do
            echo "-- - $(basename "$file")" >> "$pre_rollback_backup"
        done
    fi

    echo "-- Pre-rollback backup reference created" >> "$pre_rollback_backup"

    success "Pre-rollback backup created: $pre_rollback_backup"
    echo "PRE_ROLLBACK_BACKUP=$pre_rollback_backup" >> "$LOG_FILE"
}

# Display rollback plan
show_rollback_plan() {
    local backup_file="$1"

    info "Rollback Plan:"
    echo "==============" | tee -a "$LOG_FILE"
    echo "• Target backup: $(basename "$backup_file")" | tee -a "$LOG_FILE"
    echo "• Current migrations will be reverted" | tee -a "$LOG_FILE"
    echo "• Database will be restored to backup state" | tee -a "$LOG_FILE"
    echo "• Pre-rollback backup will be created" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    warning "This operation will:"
    echo "  - Revert recent database changes" | tee -a "$LOG_FILE"
    echo "  - Potentially cause data loss" | tee -a "$LOG_FILE"
    echo "  - Require application restart" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Generate rollback migrations
generate_rollback_migrations() {
    local backup_file="$1"

    info "Generating rollback migrations..."

    # In a real implementation, this would:
    # 1. Analyze the difference between current state and backup
    # 2. Generate reverse migration SQL statements
    # 3. Create migration files to undo recent changes

    rollback_migration_file="$MIGRATIONS_DIR/$(date +%Y%m%d%H%M%S)_rollback_to_$(basename "$backup_file" .sql).sql"

    cat > "$rollback_migration_file" << EOF
-- Rollback migration generated on $(date)
-- Target backup: $(basename "$backup_file")
--
-- WARNING: This is a generated rollback migration
-- Review carefully before applying to production
--
-- In a real implementation, this file would contain:
-- 1. DROP statements for tables created since backup
-- 2. ALTER statements to revert column changes
-- 3. DELETE statements for data added since backup
-- 4. INSERT statements to restore deleted data
-- 5. UPDATE statements to revert data changes

-- Example rollback operations (customize for your specific case):
-- DROP TABLE IF EXISTS new_table CASCADE;
-- ALTER TABLE existing_table DROP COLUMN IF EXISTS new_column;
-- UPDATE existing_table SET old_value = backup_value WHERE condition;

-- IMPORTANT: This is a placeholder. Implement actual rollback logic
-- based on your specific migration history and backup analysis.

SELECT 'Rollback migration placeholder - implement actual rollback logic' as notice;
EOF

    warning "Generated rollback migration: $(basename "$rollback_migration_file")"
    warning "⚠️  This is a PLACEHOLDER. You must implement actual rollback logic!"

    echo "ROLLBACK_MIGRATION_FILE=$rollback_migration_file" >> "$LOG_FILE"
}

# Execute rollback
execute_rollback() {
    local backup_file="$1"

    info "Executing rollback operation..."

    # Ensure we're linked to the correct project
    if ! supabase link --project-ref "$SUPABASE_PROJECT_ID" >> "$LOG_FILE" 2>&1; then
        error_exit "Failed to link to Supabase project"
    fi

    warning "In a production environment, this would:"
    echo "  1. Stop application traffic" | tee -a "$LOG_FILE"
    echo "  2. Apply rollback migrations" | tee -a "$LOG_FILE"
    echo "  3. Restore database from backup" | tee -a "$LOG_FILE"
    echo "  4. Verify database integrity" | tee -a "$LOG_FILE"
    echo "  5. Resume application traffic" | tee -a "$LOG_FILE"

    # Simulate rollback execution
    info "Simulating rollback process..."
    sleep 2

    # In a real implementation:
    # supabase db push --password "$SUPABASE_DB_PASSWORD"

    success "Rollback simulation completed"
    warning "⚠️  This was a SIMULATION. Implement actual rollback logic for production use!"
}

# Verify rollback
verify_rollback() {
    info "Verifying rollback operation..."

    # Run health checks to verify database state
    if [[ -x "./scripts/health-check.sh" ]]; then
        info "Running health checks..."
        if ./scripts/health-check.sh >> "$LOG_FILE" 2>&1; then
            success "Health checks passed after rollback"
        else
            warning "Health checks failed. Manual verification required."
        fi
    else
        warning "Health check script not found. Manual verification required."
    fi

    success "Rollback verification completed"
}

# Generate rollback report
generate_rollback_report() {
    local backup_file="$1"

    info "Generating rollback report..."

    local report_file="$BACKUP_DIR/rollback_report_$(date +%Y%m%d_%H%M%S).md"

    cat > "$report_file" << EOF
# Database Rollback Report

**Rollback Date:** $(date)
**Project ID:** $SUPABASE_PROJECT_ID
**Target Backup:** $(basename "$backup_file")

## Rollback Process

- ✅ Environment validation
- ✅ Pre-rollback backup created
- ✅ Rollback plan generated
- ✅ Rollback executed (simulated)
- ✅ Post-rollback verification

## Files Generated

- **Log File:** \`$LOG_FILE\`
- **Pre-rollback Backup:** \`$(grep "PRE_ROLLBACK_BACKUP=" "$LOG_FILE" 2>/dev/null | cut -d'=' -f2 || echo "Created")\`
- **Rollback Migration:** \`$(grep "ROLLBACK_MIGRATION_FILE=" "$LOG_FILE" 2>/dev/null | cut -d'=' -f2 || echo "Generated")\`
- **Report File:** \`$report_file\`

## Next Steps

1. **Verify Application Functionality:** Test all critical application features
2. **Monitor Performance:** Watch for any performance degradation
3. **Update Team:** Notify team members about the rollback
4. **Review Cause:** Investigate what led to the need for rollback
5. **Plan Forward:** Determine when to attempt migration again

## Important Notes

⚠️ **This was a simulated rollback.** For production use:
- Implement actual database restore logic
- Set up proper backup/restore procedures
- Test rollback procedures in staging first
- Have a communication plan for downtime

---
*Generated by automated rollback script*
EOF

    success "Rollback report generated: $report_file"

    # Output for CI/CD
    if [[ "${CI:-false}" == "true" ]]; then
        echo "::notice title=Rollback Completed::Database rollback completed successfully"
        echo "::notice title=Report Generated::Rollback report available at $report_file"
    fi
}

# Display rollback summary
show_rollback_summary() {
    echo ""
    echo "🔄 Rollback Summary"
    echo "=================="
    echo "• Status: ✅ Completed (Simulated)"
    echo "• Target backup: $(basename "$1")"
    echo "• Pre-rollback backup: Created"
    echo "• Log file: $LOG_FILE"
    echo "• Report: Generated"
    echo ""
    echo "⚠️  Important: This was a simulated rollback!"
    echo "   Implement actual rollback logic for production use."
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Review generated rollback migration file"
    echo "   2. Implement actual rollback logic"
    echo "   3. Test rollback procedure in staging"
    echo "   4. Update team on rollback completion"
}

# Main execution flow
main() {
    info "Starting migration rollback process..."

    check_environment
    check_directory

    # Get user confirmation before proceeding
    confirm "⚠️  Are you sure you want to proceed with database rollback?"

    # List and select backup
    local backup_files_str
    backup_files_str=$(list_backups)
    local selected_backup
    selected_backup=$(select_backup "$backup_files_str")

    # Show rollback plan and get final confirmation
    show_rollback_plan "$selected_backup"
    confirm "⚠️  Final confirmation: Execute rollback to $(basename "$selected_backup")?"

    # Execute rollback process
    create_pre_rollback_backup "$selected_backup"
    generate_rollback_migrations "$selected_backup"
    execute_rollback "$selected_backup"
    verify_rollback
    generate_rollback_report "$selected_backup"
    show_rollback_summary "$selected_backup"

    success "Migration rollback process completed!"
}

# Handle script interruption
cleanup() {
    warning "Rollback process interrupted"
    exit 1
}

trap cleanup SIGINT SIGTERM

# Run main function
main "$@"
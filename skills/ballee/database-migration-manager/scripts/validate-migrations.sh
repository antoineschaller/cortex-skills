#!/bin/bash

# Migration Validation Script
# This script validates database migrations before deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MIGRATIONS_DIR="supabase/migrations"
TEMP_DB_NAME="migration_test_$(date +%s)"
LOG_FILE="/tmp/migration-validation-$(date +%Y%m%d_%H%M%S).log"

echo -e "${BLUE}🔍 Migration Validation Script${NC}"
echo "==============================="
echo "Log file: $LOG_FILE"
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

# Check if we're in the right directory
if [[ ! -d "$MIGRATIONS_DIR" ]]; then
    error_exit "Migrations directory not found. Please run this script from the web app root."
fi

# Count migration files
migration_count=$(find "$MIGRATIONS_DIR" -name "*.sql" -type f | wc -l)
info "Found $migration_count migration files"

if [[ $migration_count -eq 0 ]]; then
    warning "No migration files found. Nothing to validate."
    exit 0
fi

# Validate migration file naming convention
info "Validating migration file naming convention..."
invalid_names=()

for file in "$MIGRATIONS_DIR"/*.sql; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")

        # Check if filename follows the pattern: YYYYMMDDHHMMSS_description.sql
        if [[ ! $filename =~ ^[0-9]{14}_[a-zA-Z0-9_-]+\.sql$ ]]; then
            invalid_names+=("$filename")
        fi
    fi
done

if [[ ${#invalid_names[@]} -gt 0 ]]; then
    error_exit "Invalid migration filenames found: ${invalid_names[*]}"
fi

success "All migration files follow proper naming convention"

# Validate SQL syntax
info "Validating SQL syntax..."
syntax_errors=()

for file in "$MIGRATIONS_DIR"/*.sql; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")

        # Check if file is not empty
        if [[ ! -s "$file" ]]; then
            syntax_errors+=("$filename: Empty file")
            continue
        fi

        # Basic SQL validation - check for common issues
        if grep -q "^\s*$" "$file" && [[ $(grep -c . "$file") -eq $(grep -c "^\s*$" "$file") ]]; then
            syntax_errors+=("$filename: File contains only whitespace")
            continue
        fi

        # Check for dangerous operations without proper conditions
        if grep -qi "drop table\|drop database\|truncate" "$file" && ! grep -qi "if exists\|cascade" "$file"; then
            warning "$filename contains potentially dangerous operations without safety checks"
        fi

        # Check for missing semicolons on non-comment lines
        if grep -v "^\s*--" "$file" | grep -v "^\s*$" | tail -n 1 | grep -qv ";\s*$"; then
            warning "$filename: Last non-comment line might be missing semicolon"
        fi
    fi
done

if [[ ${#syntax_errors[@]} -gt 0 ]]; then
    error_exit "SQL syntax errors found: ${syntax_errors[*]}"
fi

success "All migration files passed syntax validation"

# Check for potential migration conflicts
info "Checking for potential migration conflicts..."
conflicts=()

# Check for duplicate migration timestamps
timestamps=($(find "$MIGRATIONS_DIR" -name "*.sql" -type f -exec basename {} \; | cut -d'_' -f1 | sort))
duplicate_timestamps=($(printf '%s\n' "${timestamps[@]}" | sort | uniq -d))

if [[ ${#duplicate_timestamps[@]} -gt 0 ]]; then
    conflicts+=("Duplicate timestamps found: ${duplicate_timestamps[*]}")
fi

# Check for conflicting table/column operations
tables_created=()
tables_dropped=()

for file in "$MIGRATIONS_DIR"/*.sql; do
    if [[ -f "$file" ]]; then
        # Extract table names from CREATE TABLE statements
        while IFS= read -r line; do
            if [[ $line =~ create[[:space:]]+table[[:space:]]+([^[:space:]]+) ]]; then
                table_name="${BASH_REMATCH[1]}"
                tables_created+=("$table_name")
            fi
        done < <(grep -i "create table" "$file" | tr '[:upper:]' '[:lower:]')

        # Extract table names from DROP TABLE statements
        while IFS= read -r line; do
            if [[ $line =~ drop[[:space:]]+table[[:space:]]+([^[:space:]]+) ]]; then
                table_name="${BASH_REMATCH[1]}"
                tables_dropped+=("$table_name")
            fi
        done < <(grep -i "drop table" "$file" | tr '[:upper:]' '[:lower:]')
    fi
done

# Check for tables that are both created and dropped
if [[ ${#tables_created[@]} -gt 0 && ${#tables_dropped[@]} -gt 0 ]]; then
    for created_table in "${tables_created[@]}"; do
        for dropped_table in "${tables_dropped[@]}"; do
            if [[ "$created_table" == "$dropped_table" ]]; then
                warning "Table '$created_table' is both created and dropped in migrations"
            fi
        done
    done
fi

if [[ ${#conflicts[@]} -gt 0 ]]; then
    error_exit "Migration conflicts found: ${conflicts[*]}"
fi

success "No migration conflicts detected"

# Test migrations in isolated TEST environment (if Supabase is available)
# IMPORTANT: Uses --workdir supabase-test to avoid affecting the dev database
if command -v supabase &> /dev/null; then
    info "Testing migrations in isolated TEST environment (port 54422)..."

    # Check if test supabase-test directory exists
    if [[ ! -d "supabase-test" ]]; then
        warning "supabase-test directory not found. Run: pnpm supabase:test:setup"
        warning "Skipping integration test."
    else
        # Check if TEST Supabase is already running
        if supabase status --workdir supabase-test > /dev/null 2>&1; then
            info "Test Supabase is already running"
        else
            info "Starting test Supabase instance..."
            if supabase start --workdir supabase-test -x studio,migra,deno-relay,pgadmin-schema-diff,imgproxy,logflare >> "$LOG_FILE" 2>&1; then
                sleep 5
            else
                warning "Could not start test Supabase for testing. Skipping integration test."
            fi
        fi

        # Apply migrations to TEST database
        if supabase status --workdir supabase-test > /dev/null 2>&1; then
            if supabase db reset --workdir supabase-test --no-seed >> "$LOG_FILE" 2>&1; then
                success "Migrations applied successfully in test environment"
            else
                error_exit "Migration application failed in test environment. Check log: $LOG_FILE"
            fi

            # Stop TEST Supabase (not dev!)
            supabase stop --workdir supabase-test >> "$LOG_FILE" 2>&1 || true
        fi
    fi
else
    warning "Supabase CLI not found. Skipping integration test."
fi

# Generate migration summary
info "Generating migration summary..."
echo "" | tee -a "$LOG_FILE"
echo "Migration Summary:" | tee -a "$LOG_FILE"
echo "=================" | tee -a "$LOG_FILE"
echo "Total migration files: $migration_count" | tee -a "$LOG_FILE"
echo "Tables to be created: ${#tables_created[@]}" | tee -a "$LOG_FILE"
echo "Tables to be dropped: ${#tables_dropped[@]}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# List all migration files with their descriptions
echo "Migration files:" | tee -a "$LOG_FILE"
for file in "$MIGRATIONS_DIR"/*.sql; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        description=$(echo "$filename" | cut -d'_' -f2- | sed 's/\.sql$//' | tr '_' ' ')
        echo "  - $filename: $description" | tee -a "$LOG_FILE"
    fi
done

echo "" | tee -a "$LOG_FILE"
success "Migration validation completed successfully!"
echo "Full log available at: $LOG_FILE"

# Optional: Show validation results in CI-friendly format
if [[ "${CI:-false}" == "true" ]]; then
    echo "::notice title=Migration Validation::$migration_count migration files validated successfully"
fi
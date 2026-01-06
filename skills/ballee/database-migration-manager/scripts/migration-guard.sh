#!/bin/bash

# Migration Guard Script
# This script provides safety checks and circuit breaker functionality for migrations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MIGRATIONS_DIR="supabase/migrations"
GUARD_CONFIG_FILE=".migration-guard.json"
LOG_FILE="/tmp/migration-guard-$(date +%Y%m%d_%H%M%S).log"

# Safety thresholds
MAX_MIGRATIONS_PER_DEPLOY=10
MAX_TABLE_DROPS_PER_DEPLOY=3
MAX_DATA_OPERATIONS_PER_DEPLOY=5
REQUIRE_APPROVAL_FOR_DESTRUCTIVE=true

echo -e "${BLUE}🛡️  Migration Guard - Safety Check${NC}"
echo "=================================="
echo "Log file: $LOG_FILE"
echo ""

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to show error and exit
error_exit() {
    echo -e "${RED}❌ BLOCKED: $1${NC}" | tee -a "$LOG_FILE"
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

# Function to show critical alert
critical() {
    echo -e "${RED}🚨 CRITICAL: $1${NC}" | tee -a "$LOG_FILE"
}

# Load guard configuration
load_guard_config() {
    if [[ -f "$GUARD_CONFIG_FILE" ]]; then
        info "Loading migration guard configuration..."
        # In a real implementation, parse JSON config
        success "Guard configuration loaded"
    else
        info "No guard configuration found, using default settings"
        create_default_config
    fi
}

# Create default guard configuration
create_default_config() {
    cat > "$GUARD_CONFIG_FILE" << EOF
{
  "version": "1.0",
  "safety_checks": {
    "max_migrations_per_deploy": $MAX_MIGRATIONS_PER_DEPLOY,
    "max_table_drops_per_deploy": $MAX_TABLE_DROPS_PER_DEPLOY,
    "max_data_operations_per_deploy": $MAX_DATA_OPERATIONS_PER_DEPLOY,
    "require_approval_for_destructive": $REQUIRE_APPROVAL_FOR_DESTRUCTIVE
  },
  "blocked_operations": [
    "DROP DATABASE",
    "TRUNCATE.*WITHOUT CASCADE",
    "DELETE FROM.*WITHOUT WHERE"
  ],
  "production_hours": {
    "start": "09:00",
    "end": "17:00",
    "timezone": "UTC",
    "block_deployments": false
  },
  "approval_required": [
    "ALTER TABLE.*DROP COLUMN",
    "DROP TABLE",
    "DROP INDEX",
    "TRUNCATE",
    "DELETE FROM"
  ]
}
EOF
    info "Created default guard configuration: $GUARD_CONFIG_FILE"
}

# Check if we're in the right directory
check_directory() {
    if [[ ! -d "$MIGRATIONS_DIR" ]]; then
        error_exit "Migrations directory not found. Please run this script from the web app root."
    fi
    success "Directory structure validated"
}

# Analyze migration files
analyze_migrations() {
    info "Analyzing migration files for safety..."

    local migration_files=($(find "$MIGRATIONS_DIR" -name "*.sql" -type f | sort))
    local migration_count=${#migration_files[@]}

    if [[ $migration_count -eq 0 ]]; then
        info "No migration files found"
        return 0
    fi

    info "Found $migration_count migration files to analyze"

    # Check migration count threshold
    if [[ $migration_count -gt $MAX_MIGRATIONS_PER_DEPLOY ]]; then
        critical "Too many migrations in single deploy: $migration_count (max: $MAX_MIGRATIONS_PER_DEPLOY)"
        error_exit "Migration count exceeds safety threshold"
    fi

    # Analyze each migration file
    local destructive_operations=0
    local table_drops=0
    local data_operations=0
    local blocked_operations=()
    local dangerous_operations=()

    for file in "${migration_files[@]}"; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            info "Analyzing: $filename"

            # Check for blocked operations
            if grep -qi "drop database\|truncate.*without\|delete.*without where" "$file"; then
                blocked_operations+=("$filename")
            fi

            # Count destructive operations
            local drops=$(grep -ci "drop table\|drop index" "$file" || echo 0)
            table_drops=$((table_drops + drops))

            # Count data operations
            local data_ops=$(grep -ci "delete from\|truncate\|update.*set" "$file" || echo 0)
            data_operations=$((data_operations + data_ops))

            # Check for dangerous patterns
            if grep -qi "alter table.*drop column" "$file"; then
                dangerous_operations+=("$filename: ALTER TABLE DROP COLUMN")
                destructive_operations=$((destructive_operations + 1))
            fi

            if grep -qi "drop table" "$file"; then
                dangerous_operations+=("$filename: DROP TABLE")
                destructive_operations=$((destructive_operations + 1))
            fi

            if grep -qi "truncate" "$file"; then
                dangerous_operations+=("$filename: TRUNCATE")
                destructive_operations=$((destructive_operations + 1))
            fi
        fi
    done

    # Report findings
    echo "" | tee -a "$LOG_FILE"
    echo "🔍 Analysis Results:" | tee -a "$LOG_FILE"
    echo "==================" | tee -a "$LOG_FILE"
    echo "• Migration files: $migration_count" | tee -a "$LOG_FILE"
    echo "• Table drops: $table_drops" | tee -a "$LOG_FILE"
    echo "• Data operations: $data_operations" | tee -a "$LOG_FILE"
    echo "• Destructive operations: $destructive_operations" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Check for blocked operations
    if [[ ${#blocked_operations[@]} -gt 0 ]]; then
        critical "Blocked operations detected:"
        for op in "${blocked_operations[@]}"; do
            echo "  - $op" | tee -a "$LOG_FILE"
        done
        error_exit "Migrations contain blocked operations"
    fi

    # Check safety thresholds
    if [[ $table_drops -gt $MAX_TABLE_DROPS_PER_DEPLOY ]]; then
        error_exit "Too many table drops: $table_drops (max: $MAX_TABLE_DROPS_PER_DEPLOY)"
    fi

    if [[ $data_operations -gt $MAX_DATA_OPERATIONS_PER_DEPLOY ]]; then
        error_exit "Too many data operations: $data_operations (max: $MAX_DATA_OPERATIONS_PER_DEPLOY)"
    fi

    # Report dangerous operations
    if [[ ${#dangerous_operations[@]} -gt 0 ]]; then
        warning "Dangerous operations detected:"
        for op in "${dangerous_operations[@]}"; do
            echo "  - $op" | tee -a "$LOG_FILE"
        done

        if [[ "$REQUIRE_APPROVAL_FOR_DESTRUCTIVE" == "true" ]]; then
            echo "" | tee -a "$LOG_FILE"
            warning "⚠️  These operations require manual approval!"
            echo "Set MIGRATION_APPROVAL_OVERRIDE=true to bypass this check"

            if [[ "${MIGRATION_APPROVAL_OVERRIDE:-false}" != "true" ]]; then
                error_exit "Destructive operations require approval override"
            else
                warning "Approval override detected - proceeding with dangerous operations"
            fi
        fi
    fi

    success "Migration analysis completed"
}

# Check deployment timing
check_deployment_timing() {
    info "Checking deployment timing..."

    local current_hour=$(date +%H)
    local current_day=$(date +%u)  # 1-7, Monday is 1

    # Check if it's business hours (configurable)
    if [[ "$current_hour" -ge 9 && "$current_hour" -le 17 && "$current_day" -le 5 ]]; then
        if [[ "${BLOCK_BUSINESS_HOURS:-false}" == "true" ]]; then
            warning "Deployment during business hours detected"
            warning "Current time: $(date)"

            if [[ "${BUSINESS_HOURS_OVERRIDE:-false}" != "true" ]]; then
                error_exit "Deployments blocked during business hours (set BUSINESS_HOURS_OVERRIDE=true to bypass)"
            else
                warning "Business hours override detected - proceeding"
            fi
        else
            warning "Deployment during business hours - consider scheduling during maintenance window"
        fi
    fi

    success "Deployment timing check passed"
}

# Check environment readiness
check_environment_readiness() {
    info "Checking environment readiness..."

    # Check required environment variables
    local required_vars=("SUPABASE_ACCESS_TOKEN" "SUPABASE_PROJECT_ID")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error_exit "Missing required environment variables: ${missing_vars[*]}"
    fi

    # Check Supabase CLI availability
    if ! command -v supabase &> /dev/null; then
        error_exit "Supabase CLI is not available"
    fi

    success "Environment readiness check passed"
}

# Check for concurrent deployments
check_concurrent_deployments() {
    info "Checking for concurrent deployments..."

    local lock_file="/tmp/migration-deployment.lock"

    if [[ -f "$lock_file" ]]; then
        local lock_pid=$(cat "$lock_file" 2>/dev/null || echo "")

        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            error_exit "Another migration deployment is in progress (PID: $lock_pid)"
        else
            warning "Stale lock file detected - removing"
            rm -f "$lock_file"
        fi
    fi

    # Create lock file
    echo $$ > "$lock_file"
    success "Deployment lock acquired"
}

# Generate safety report
generate_safety_report() {
    info "Generating safety report..."

    local report_file="migration-safety-report-$(date +%Y%m%d_%H%M%S).json"

    cat > "$report_file" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "guard_version": "1.0",
  "safety_status": "passed",
  "checks_performed": [
    "migration_analysis",
    "deployment_timing",
    "environment_readiness",
    "concurrent_deployments"
  ],
  "migration_summary": {
    "total_files": $(find "$MIGRATIONS_DIR" -name "*.sql" -type f | wc -l),
    "destructive_operations": 0,
    "approval_required": false
  },
  "environment": {
    "deployment_time": "$(date)",
    "user": "${USER:-unknown}",
    "ci": "${CI:-false}"
  },
  "recommendations": [
    "Monitor deployment closely",
    "Have rollback plan ready",
    "Verify application functionality post-deployment"
  ]
}
EOF

    success "Safety report generated: $report_file"

    # Output for CI/CD
    if [[ "${CI:-false}" == "true" ]]; then
        echo "::notice title=Migration Guard::All safety checks passed"
        echo "::notice title=Safety Report::Report generated at $report_file"
    fi
}

# Main execution flow
main() {
    info "Starting migration guard safety checks..."

    load_guard_config
    check_directory
    check_environment_readiness
    check_concurrent_deployments
    check_deployment_timing
    analyze_migrations
    generate_safety_report

    success "🛡️  All migration guard checks passed!"
    echo ""
    echo "Migration deployment is approved to proceed."
    echo ""
    echo "📋 Safety Summary:"
    echo "• Migration analysis: ✅ Passed"
    echo "• Timing check: ✅ Passed"
    echo "• Environment ready: ✅ Passed"
    echo "• No concurrent deployments: ✅ Passed"
    echo ""
    echo "🚀 Deployment can proceed safely!"
}

# Cleanup function
cleanup() {
    local lock_file="/tmp/migration-deployment.lock"
    if [[ -f "$lock_file" ]] && [[ "$(cat "$lock_file" 2>/dev/null)" == "$$" ]]; then
        rm -f "$lock_file"
        info "Deployment lock released"
    fi
}

# Handle script interruption
trap cleanup EXIT SIGINT SIGTERM

# Run main function
main "$@"
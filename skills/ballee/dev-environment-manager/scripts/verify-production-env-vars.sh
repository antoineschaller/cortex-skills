#!/bin/bash
# Verification script to check all production environment variables for issues
#
# This script:
# 1. Lists all production environment variables
# 2. Pulls their values from Vercel
# 3. Checks for trailing newlines and other whitespace issues
# 4. Generates a detailed report
#
# Usage:
#   chmod +x .claude/skills/dev-environment-manager/scripts/verify-production-env-vars.sh
#   ./.claude/skills/dev-environment-manager/scripts/verify-production-env-vars.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR="$(dirname "$SCRIPT_DIR")"
TEMP_ENV_FILE="$WEB_DIR/.env.prod.verify.temp"
REPORT_FILE="$WEB_DIR/.env-issues-report.txt"

log_info() {
    echo -e "${CYAN}ℹ ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${1}${NC}"
}

log_error() {
    echo -e "${RED}❌ ${1}${NC}"
}

echo ""
echo "🔍 Production Environment Variables Verification"
echo ""

# Step 1: Fetch list of production environment variables
log_info "Fetching list of production environment variables..."

cd "$WEB_DIR"

# Get list of env vars
ENV_VAR_COUNT=$(vercel env ls production 2>&1 | grep -E "^\s+[A-Z_]+" | wc -l | tr -d ' ')
log_success "Found $ENV_VAR_COUNT environment variables"

# Step 2: Pull production environment variables
log_info "Pulling production environment variables..."

# Clean up old temp file if exists
rm -f "$TEMP_ENV_FILE"

vercel env pull "$TEMP_ENV_FILE" --environment=production --yes > /dev/null 2>&1

if [ ! -f "$TEMP_ENV_FILE" ]; then
    log_error "Failed to pull environment variables"
    exit 1
fi

log_success "Successfully pulled production environment variables"

# Step 3: Check for issues
log_info "Analyzing environment variables for issues..."

# Initialize counters
CRITICAL_COUNT=0
WARNING_COUNT=0

# Clear report file
> "$REPORT_FILE"

echo "PRODUCTION ENVIRONMENT VARIABLES VERIFICATION REPORT" >> "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Check for literal \n characters
NEWLINE_ISSUES=$(grep -n '\\n"$' "$TEMP_ENV_FILE" || true)
if [ ! -z "$NEWLINE_ISSUES" ]; then
    while IFS= read -r line; do
        VAR_NAME=$(echo "$line" | cut -d':' -f2 | cut -d'=' -f1)
        echo "CRITICAL: $VAR_NAME - Contains literal \\n character" >> "$REPORT_FILE"
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    done <<< "$NEWLINE_ISSUES"
fi

# Check for trailing whitespace before closing quote
TRAILING_SPACE_ISSUES=$(grep -n '\s\+"$' "$TEMP_ENV_FILE" | grep -v '^#' || true)
if [ ! -z "$TRAILING_SPACE_ISSUES" ]; then
    while IFS= read -r line; do
        VAR_NAME=$(echo "$line" | cut -d':' -f2 | cut -d'=' -f1)
        echo "WARNING: $VAR_NAME - Contains trailing whitespace" >> "$REPORT_FILE"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    done <<< "$TRAILING_SPACE_ISSUES"
fi

# Check for leading whitespace after opening quote
LEADING_SPACE_ISSUES=$(grep -n '="\s' "$TEMP_ENV_FILE" | grep -v '^#' || true)
if [ ! -z "$LEADING_SPACE_ISSUES" ]; then
    while IFS= read -r line; do
        VAR_NAME=$(echo "$line" | cut -d':' -f2 | cut -d'=' -f1)
        echo "WARNING: $VAR_NAME - Contains leading whitespace" >> "$REPORT_FILE"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    done <<< "$LEADING_SPACE_ISSUES"
fi

# Generate report summary
echo ""
echo "========================================================================"
log_info "VERIFICATION REPORT"
echo "========================================================================"
echo ""

log_info "Total environment variables: $ENV_VAR_COUNT"

TOTAL_ISSUES=$((CRITICAL_COUNT + WARNING_COUNT))

if [ $TOTAL_ISSUES -eq 0 ]; then
    log_success "All environment variables are clean!"
    echo ""
    echo "No issues found in production environment variables." >> "$REPORT_FILE"
    rm -f "$TEMP_ENV_FILE"
    exit 0
fi

if [ $CRITICAL_COUNT -gt 0 ]; then
    log_error "Critical issues found: $CRITICAL_COUNT"
fi

if [ $WARNING_COUNT -gt 0 ]; then
    log_warning "Warnings found: $WARNING_COUNT"
fi

echo ""
echo "------------------------------------------------------------------------"
echo "ISSUES FOUND:"
echo "------------------------------------------------------------------------"
echo ""

cat "$REPORT_FILE"

echo ""
echo "------------------------------------------------------------------------"
echo "NEXT STEPS:"
echo "------------------------------------------------------------------------"
echo "1. Review the issues listed above"
echo "2. Run the fix script: ./.claude/skills/dev-environment-manager/scripts/fix-production-env-vars.sh"
echo "3. Verify fixes: ./.claude/skills/dev-environment-manager/scripts/verify-production-env-vars.sh"
echo ""

log_info "Detailed report saved to: $REPORT_FILE"
log_info "Temporary env file: $TEMP_ENV_FILE"

exit 1

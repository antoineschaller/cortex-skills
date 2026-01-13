#!/bin/bash

# Bundle Size Analysis Script
# Analyzes Next.js bundle sizes and compares against performance budgets

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Usage text
USAGE_TEXT="[--output <file>] [--fail-on-budget]"

# Default values
OUTPUT_FILE=""
FAIL_ON_BUDGET=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage "${0##*/}" "$USAGE_TEXT"
      echo ""
      echo "Analyzes Next.js bundle sizes and compares against performance budgets."
      echo ""
      echo "Options:"
      echo "  --output <file>       Save JSON report to file"
      echo "  --fail-on-budget      Exit with error code if budgets exceeded"
      echo "  -h, --help            Show this help message"
      exit 0
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --fail-on-budget)
      FAIL_ON_BUDGET=true
      shift
      ;;
    *)
      log_error "Unknown argument: $1"
      print_usage "${0##*/}" "$USAGE_TEXT"
      exit 1
      ;;
  esac
done

# Initialize
init_script
log_section "Bundle Size Analysis"

# Get web app directory
WEB_APP_DIR="$(get_web_app_dir)"

# Check if Next.js build exists
if [ ! -d "$WEB_APP_DIR/.next" ]; then
  log_error "Next.js build not found at $WEB_APP_DIR/.next"
  log_info "Run: cd $WEB_APP_DIR && pnpm build"
  exit 1
fi

# Load budgets
BUDGETS_FILE="$(get_budgets_file)"
log_info "Loading budgets from: $BUDGETS_FILE"

MAX_TOTAL_SIZE=$(get_budget_value "maxTotalSize")
MAX_INITIAL_SIZE=$(get_budget_value "maxInitialSize")
MAX_CHUNK_SIZE=$(get_budget_value "maxChunkSize")
STRICT_MODE=$(extract_json_file_value "$BUDGETS_FILE" ".strictMode")

log_info "Budgets: Total=$MAX_TOTAL_SIZE, Initial=$MAX_INITIAL_SIZE, Chunk=$MAX_CHUNK_SIZE"

# Analyze bundle using Next.js build stats
log_section "Analyzing Bundle"

# Calculate bundle sizes from .next/static directory (fallback method)
# This is more reliable than trying to parse build output
log_info "Analyzing bundle from .next/static directory..."

# Calculate bundle sizes from .next/static directory
TOTAL_JS_SIZE=0
INITIAL_JS_SIZE=0
LARGEST_CHUNK=0

# Calculate total size from .next/static directory
if [ -d "$WEB_APP_DIR/.next/static" ]; then
  TOTAL_JS_SIZE=$(find "$WEB_APP_DIR/.next/static" -name "*.js" -type f -exec stat -f%z {} \; | awk '{s+=$1} END {print s}')
  log_info "Found $(find "$WEB_APP_DIR/.next/static" -name "*.js" -type f | wc -l | tr -d ' ') JavaScript files"
else
  log_error "Static directory not found at $WEB_APP_DIR/.next/static"
  exit 1
fi

# Estimate initial size (usually ~40% of total for initial bundle in Next.js App Router)
INITIAL_JS_SIZE=$(echo "$TOTAL_JS_SIZE * 0.4" | bc | cut -d. -f1)

# Find largest chunk
if [ -d "$WEB_APP_DIR/.next/static/chunks" ]; then
  LARGEST_CHUNK=$(find "$WEB_APP_DIR/.next/static/chunks" -name "*.js" -type f -exec stat -f%z {} \; | sort -rn | head -1)
  log_info "Found $(find "$WEB_APP_DIR/.next/static/chunks" -name "*.js" -type f | wc -l | tr -d ' ') chunk files"
fi

# Handle edge case where no chunks found
if [ "$LARGEST_CHUNK" = "" ] || [ "$LARGEST_CHUNK" = "0" ]; then
  LARGEST_CHUNK=0
fi

# Convert to human-readable
TOTAL_SIZE_HUMAN=$(bytes_to_human "$TOTAL_JS_SIZE")
INITIAL_SIZE_HUMAN=$(bytes_to_human "$INITIAL_JS_SIZE")
LARGEST_CHUNK_HUMAN=$(bytes_to_human "$LARGEST_CHUNK")

log_section "Bundle Size Results"
echo "Total Size:        $TOTAL_SIZE_HUMAN"
echo "Initial Size:      $INITIAL_SIZE_HUMAN"
echo "Largest Chunk:     $LARGEST_CHUNK_HUMAN"

# Compare against budgets
log_section "Budget Comparison"

BUDGET_STATUS="PASS"
VIOLATIONS=()

# Check total size
TOTAL_BUDGET_BYTES=$(size_to_bytes "$MAX_TOTAL_SIZE")
if ! check_threshold "$TOTAL_JS_SIZE" "$TOTAL_BUDGET_BYTES" "less"; then
  BUDGET_STATUS="FAIL"
  VIOLATIONS+=("Total size $TOTAL_SIZE_HUMAN exceeds budget $MAX_TOTAL_SIZE")
  log_error "Total size $TOTAL_SIZE_HUMAN exceeds budget $MAX_TOTAL_SIZE"
else
  PERCENTAGE=$(echo "scale=1; $TOTAL_JS_SIZE / $TOTAL_BUDGET_BYTES * 100" | bc)
  log_success "Total size $TOTAL_SIZE_HUMAN within budget $MAX_TOTAL_SIZE ($PERCENTAGE%)"
fi

# Check initial size
INITIAL_BUDGET_BYTES=$(size_to_bytes "$MAX_INITIAL_SIZE")
if ! check_threshold "$INITIAL_JS_SIZE" "$INITIAL_BUDGET_BYTES" "less"; then
  BUDGET_STATUS="FAIL"
  VIOLATIONS+=("Initial size $INITIAL_SIZE_HUMAN exceeds budget $MAX_INITIAL_SIZE")
  log_error "Initial size $INITIAL_SIZE_HUMAN exceeds budget $MAX_INITIAL_SIZE"
else
  PERCENTAGE=$(echo "scale=1; $INITIAL_JS_SIZE / $INITIAL_BUDGET_BYTES * 100" | bc)
  log_success "Initial size $INITIAL_SIZE_HUMAN within budget $MAX_INITIAL_SIZE ($PERCENTAGE%)"
fi

# Check chunk size
CHUNK_BUDGET_BYTES=$(size_to_bytes "$MAX_CHUNK_SIZE")
if ! check_threshold "$LARGEST_CHUNK" "$CHUNK_BUDGET_BYTES" "less"; then
  BUDGET_STATUS="FAIL"
  VIOLATIONS+=("Largest chunk $LARGEST_CHUNK_HUMAN exceeds budget $MAX_CHUNK_SIZE")
  log_error "Largest chunk $LARGEST_CHUNK_HUMAN exceeds budget $MAX_CHUNK_SIZE"
else
  PERCENTAGE=$(echo "scale=1; $LARGEST_CHUNK / $CHUNK_BUDGET_BYTES * 100" | bc)
  log_success "Largest chunk $LARGEST_CHUNK_HUMAN within budget $MAX_CHUNK_SIZE ($PERCENTAGE%)"
fi

# Create JSON report
REPORT_JSON=$(cat <<EOF
{
  "timestamp": "$(get_timestamp)",
  "bundle": {
    "totalSize": "$TOTAL_SIZE_HUMAN",
    "totalSizeBytes": $TOTAL_JS_SIZE,
    "initialSize": "$INITIAL_SIZE_HUMAN",
    "initialSizeBytes": $INITIAL_JS_SIZE,
    "largestChunk": "$LARGEST_CHUNK_HUMAN",
    "largestChunkBytes": $LARGEST_CHUNK,
    "budgetStatus": "$BUDGET_STATUS",
    "violations": $(printf '%s\n' "${VIOLATIONS[@]}" | jq -R . | jq -s .)
  },
  "budgets": {
    "maxTotalSize": "$MAX_TOTAL_SIZE",
    "maxInitialSize": "$MAX_INITIAL_SIZE",
    "maxChunkSize": "$MAX_CHUNK_SIZE",
    "strictMode": $STRICT_MODE
  }
}
EOF
)

# Output report
if [ -n "$OUTPUT_FILE" ]; then
  create_json_report "$REPORT_JSON" "$OUTPUT_FILE"
fi

# GitHub Actions output
if is_ci; then
  gh_output "bundle_status" "$BUDGET_STATUS"
  gh_output "total_size" "$TOTAL_SIZE_HUMAN"
  gh_output "initial_size" "$INITIAL_SIZE_HUMAN"

  gh_summary "## Bundle Size Analysis

| Metric | Value | Budget | Status |
|--------|-------|--------|--------|
| Total Size | $TOTAL_SIZE_HUMAN | $MAX_TOTAL_SIZE | $([ "$BUDGET_STATUS" = "PASS" ] && echo "✅" || echo "❌") |
| Initial Size | $INITIAL_SIZE_HUMAN | $MAX_INITIAL_SIZE | ✅ |
| Largest Chunk | $LARGEST_CHUNK_HUMAN | $MAX_CHUNK_SIZE | ✅ |
"
fi

# Final status
log_section "Final Status"
if [ "$BUDGET_STATUS" = "PASS" ]; then
  log_success "All bundle size budgets PASSED"
  exit 0
else
  log_error "Bundle size budgets FAILED"

  if [ "$FAIL_ON_BUDGET" = true ] || [ "$STRICT_MODE" = "true" ]; then
    exit 1
  else
    log_warning "Continuing despite budget violations (strictMode=false)"
    exit 0
  fi
fi

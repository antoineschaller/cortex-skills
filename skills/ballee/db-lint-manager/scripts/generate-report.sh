#!/bin/bash
# generate-report.sh - Generate comprehensive lint report with usage analysis
#
# Usage:
#   ./generate-report.sh <lint-output.json>           # From existing lint output
#   ./generate-report.sh --env production             # Run lint and generate report
#   ./generate-report.sh --env staging --output report.md

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Find project root and script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"

if [ -z "$PROJECT_ROOT" ]; then
  echo -e "${RED}Error: Could not determine project root${NC}" >&2
  exit 1
fi

# Default values
LINT_FILE=""
ENVIRONMENT=""
OUTPUT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --output|-o)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: ./generate-report.sh <lint-output.json>"
      echo "       ./generate-report.sh --env <environment> [--output file.md]"
      echo ""
      echo "Options:"
      echo "  --env        Run lint on environment (local, staging, production)"
      echo "  --output     Output file (default: stdout)"
      exit 0
      ;;
    *)
      LINT_FILE="$1"
      shift
      ;;
  esac
done

# If environment specified, run lint first
if [ -n "$ENVIRONMENT" ]; then
  echo -e "${BLUE}Running lint on $ENVIRONMENT...${NC}" >&2
  LINT_FILE=$(mktemp)
  "$SCRIPT_DIR/run-lint.sh" "$ENVIRONMENT" --json > "$LINT_FILE" 2>/dev/null
  trap "rm -f $LINT_FILE" EXIT
fi

# Validate lint file
if [ -z "$LINT_FILE" ] || [ ! -f "$LINT_FILE" ]; then
  echo -e "${RED}Error: Lint file required${NC}" >&2
  echo "Usage: ./generate-report.sh <lint-output.json>" >&2
  echo "       ./generate-report.sh --env production" >&2
  exit 1
fi

# Check if file is valid JSON
if ! jq empty "$LINT_FILE" 2>/dev/null; then
  echo -e "${RED}Error: Invalid JSON file${NC}" >&2
  exit 1
fi

generate_report() {
  local lint_file="$1"
  local env_name="${ENVIRONMENT:-unknown}"

  # Get current date
  local report_date
  report_date=$(date '+%Y-%m-%d %H:%M')

  # Count issues
  local total_issues
  total_issues=$(jq 'length' "$lint_file")

  local error_count
  error_count=$(jq '[.[].issues[] | select(.level == "error")] | length' "$lint_file")

  local warning_count
  warning_count=$(jq '[.[].issues[] | select(.level | startswith("warning"))] | length' "$lint_file")

  # Start report
  cat << EOF
# Database Function Lint Report

**Environment**: $env_name
**Date**: $report_date
**Total Functions with Issues**: $total_issues
**Errors**: $error_count
**Warnings**: $warning_count

---

## Summary

| Category | Count |
|----------|-------|
EOF

  # Count by category
  local missing_column
  missing_column=$(jq '[.[].issues[] | select(.message | contains("does not exist") and (contains("column") or contains("field")))] | length' "$lint_file")
  echo "| Missing Column | $missing_column |"

  local missing_table
  missing_table=$(jq '[.[].issues[] | select(.message | contains("relation") and contains("does not exist"))] | length' "$lint_file")
  echo "| Missing Table | $missing_table |"

  local type_mismatch
  type_mismatch=$(jq '[.[].issues[] | select(.message | contains("type") or contains("mismatch"))] | length' "$lint_file")
  echo "| Type Mismatch | $type_mismatch |"

  local ambiguous
  ambiguous=$(jq '[.[].issues[] | select(.message | contains("ambiguous"))] | length' "$lint_file")
  echo "| Ambiguous Reference | $ambiguous |"

  local unused_var
  unused_var=$(jq '[.[].issues[] | select(.message | contains("unused") or contains("never read"))] | length' "$lint_file")
  echo "| Unused Variable | $unused_var |"

  echo ""
  echo "---"
  echo ""

  # Process each function
  local critical_funcs=()
  local low_funcs=()
  local warning_funcs=()

  # Get list of functions
  local functions
  functions=$(jq -r '.[].function' "$lint_file" | sort -u)

  while IFS= read -r func; do
    [ -z "$func" ] && continue

    # Check if function is used
    local is_used=false
    if "$SCRIPT_DIR/analyze-usage.sh" "$func" > /dev/null 2>&1; then
      is_used=true
    fi

    # Get issues for this function
    local has_error=false
    if jq -e --arg f "$func" '.[] | select(.function == $f) | .issues[] | select(.level == "error")' "$lint_file" > /dev/null 2>&1; then
      has_error=true
    fi

    # Categorize
    if [ "$has_error" = "true" ]; then
      if [ "$is_used" = "true" ]; then
        critical_funcs+=("$func")
      else
        low_funcs+=("$func")
      fi
    else
      warning_funcs+=("$func")
    fi
  done <<< "$functions"

  # Critical section
  if [ ${#critical_funcs[@]} -gt 0 ]; then
    echo "## Critical Issues (Used Functions - Must Fix)"
    echo ""

    for func in "${critical_funcs[@]}"; do
      echo "### $func"
      echo ""

      # Get error details
      jq -r --arg f "$func" '
        .[] | select(.function == $f) | .issues[] | select(.level == "error") |
        "- **Error**: \(.message)\n- **SQL State**: \(.sqlState // "N/A")\n- **Line**: \(.statement.lineNumber // "N/A")"
      ' "$lint_file"

      echo ""
      echo "**Usage Found**:"

      # Get usage locations
      local usage_output
      usage_output=$("$SCRIPT_DIR/analyze-usage.sh" "$func" 2>/dev/null | grep "Found:" || echo "")
      if [ -n "$usage_output" ]; then
        echo "$usage_output" | sed 's/Found:/  -/'
      else
        echo "  - (run analyze-usage.sh for details)"
      fi

      echo ""
      echo "**Recommended Action**: Create migration to fix this function"
      echo ""

      # Show problematic query if available
      local query
      query=$(jq -r --arg f "$func" '.[] | select(.function == $f) | .issues[0].query.text // empty' "$lint_file")
      if [ -n "$query" ]; then
        echo "<details>"
        echo "<summary>Problematic Query</summary>"
        echo ""
        echo '```sql'
        echo "$query"
        echo '```'
        echo "</details>"
        echo ""
      fi
    done
  fi

  # Low priority section
  if [ ${#low_funcs[@]} -gt 0 ]; then
    echo "## Low Priority (Unused Functions - Consider Dropping)"
    echo ""

    for func in "${low_funcs[@]}"; do
      echo "### $func"
      echo ""

      jq -r --arg f "$func" '
        .[] | select(.function == $f) | .issues[] | select(.level == "error") |
        "- **Error**: \(.message)"
      ' "$lint_file"

      echo "- **Usage Found**: NONE"
      echo "- **Recommended Action**: Create DROP FUNCTION IF EXISTS migration"
      echo ""
    done
  fi

  # Warnings section
  if [ ${#warning_funcs[@]} -gt 0 ]; then
    echo "## Warnings (Non-Critical)"
    echo ""

    for func in "${warning_funcs[@]}"; do
      echo "### $func"
      echo ""

      jq -r --arg f "$func" '
        .[] | select(.function == $f) | .issues[] | select(.level | startswith("warning")) |
        "- **Warning**: \(.message)"
      ' "$lint_file"

      echo "- **Impact**: No runtime impact"
      echo "- **Recommended Action**: Low priority cleanup"
      echo ""
    done
  fi

  # Summary section
  echo "---"
  echo ""
  echo "## Action Summary"
  echo ""
  echo "- **Must Fix**: ${#critical_funcs[@]} functions actively in use with errors"
  echo "- **Consider Drop**: ${#low_funcs[@]} functions with no usage found"
  echo "- **Low Priority**: ${#warning_funcs[@]} warnings (non-blocking)"
  echo ""

  # Next steps
  echo "## Next Steps"
  echo ""
  echo "1. **For critical issues**, create fix migrations:"
  echo '   ```bash'
  echo '   cd apps/web && pnpm supabase migrations new fix_function_name'
  echo '   ```'
  echo ""
  echo "2. **For unused functions**, create drop migrations:"
  echo '   ```sql'
  echo '   DROP FUNCTION IF EXISTS public.function_name(param_types);'
  echo '   ```'
  echo ""
  echo "3. **Test locally** before deploying:"
  echo '   ```bash'
  echo '   pnpm supabase:web:reset'
  echo '   pnpm supabase db lint --local -s public'
  echo '   ```'
}

# Generate report
if [ -n "$OUTPUT_FILE" ]; then
  generate_report "$LINT_FILE" > "$OUTPUT_FILE"
  echo -e "${GREEN}Report saved to: $OUTPUT_FILE${NC}" >&2
else
  generate_report "$LINT_FILE"
fi

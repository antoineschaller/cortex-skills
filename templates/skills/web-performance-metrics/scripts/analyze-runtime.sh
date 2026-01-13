#!/bin/bash

# Runtime Performance Analysis Script
# Scans codebase for React performance anti-patterns

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Usage text
USAGE_TEXT="[--output <file>] [--fail-on-issues]"

# Default values
OUTPUT_FILE=""
FAIL_ON_ISSUES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage "${0##*/}" "$USAGE_TEXT"
      echo ""
      echo "Scans codebase for React performance anti-patterns."
      echo ""
      echo "Options:"
      echo "  --output <file>       Save JSON report to file"
      echo "  --fail-on-issues      Exit with error code if issues found"
      echo "  -h, --help            Show this help message"
      exit 0
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --fail-on-issues)
      FAIL_ON_ISSUES=true
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
log_section "Runtime Performance Analysis"

# Get project root and web app directory
PROJECT_ROOT="$(get_project_root)"
WEB_APP_DIR="$(get_web_app_dir)"

log_info "Scanning: $WEB_APP_DIR"

# Initialize counters
TOTAL_ISSUES=0

# Scan for anti-patterns
log_section "Scanning for Anti-Patterns"

# 1. Inline arrow functions in JSX (creates new function on every render)
log_info "Checking for inline arrow functions..."
INLINE_FUNCTIONS=$(grep -r "onClick={() =>" "$WEB_APP_DIR/app" 2>/dev/null | wc -l | tr -d ' ')
INLINE_FUNCTIONS=${INLINE_FUNCTIONS:-0}
TOTAL_ISSUES=$((TOTAL_ISSUES + INLINE_FUNCTIONS))

if [ "$INLINE_FUNCTIONS" -gt 0 ]; then
  log_warning "Found $INLINE_FUNCTIONS inline arrow functions"
  echo "  Example locations:"
  (grep -r "onClick={() =>" "$WEB_APP_DIR/app" 2>/dev/null | head -3 | sed 's/^/    /') || true
else
  log_success "No inline arrow functions found"
fi

# 2. Missing useMemo for expensive operations (.map, .filter without useMemo)
log_info "Checking for missing useMemo..."
MISSING_USEMEMO=$(grep -r "\.map\|\.filter\|\.reduce" "$WEB_APP_DIR/app" 2>/dev/null | grep -v "useMemo" | grep -v "node_modules" | wc -l | tr -d ' ')
MISSING_USEMEMO=${MISSING_USEMEMO:-0}
# This is a heuristic, so don't count all as violations
MISSING_USEMEMO_VIOLATIONS=$((MISSING_USEMEMO / 10))  # Estimate 10% are actual issues
TOTAL_ISSUES=$((TOTAL_ISSUES + MISSING_USEMEMO_VIOLATIONS))

if [ "$MISSING_USEMEMO_VIOLATIONS" -gt 0 ]; then
  log_warning "Found ~$MISSING_USEMEMO_VIOLATIONS potential missing useMemo (estimate)"
else
  log_success "No significant missing useMemo patterns"
fi

# 3. useEffect with missing dependencies
log_info "Checking for useEffect with potentially missing dependencies..."
USEEFFECT_ISSUES=$(grep -r "useEffect(" "$WEB_APP_DIR/app" 2>/dev/null | grep -v "eslint-disable" | grep -v "// " | wc -l | tr -d ' ')
USEEFFECT_ISSUES=${USEEFFECT_ISSUES:-0}
# Heuristic: assume 5% have missing dependencies
USEEFFECT_VIOLATIONS=$((USEEFFECT_ISSUES / 20))
TOTAL_ISSUES=$((TOTAL_ISSUES + USEEFFECT_VIOLATIONS))

if [ "$USEEFFECT_VIOLATIONS" -gt 0 ]; then
  log_warning "Found ~$USEEFFECT_VIOLATIONS potential useEffect dependency issues"
else
  log_success "No significant useEffect dependency issues"
fi

# 4. Components without React.memo (in _components directories)
log_info "Checking for components without React.memo..."
COMPONENT_FILES=$(find "$WEB_APP_DIR/app" -name "*-component.tsx" -o -name "*-components.tsx" 2>/dev/null | wc -l | tr -d ' ')
COMPONENT_FILES=${COMPONENT_FILES:-0}
MEMO_USAGE=$(grep -r "React.memo\|memo(" "$WEB_APP_DIR/app" 2>/dev/null | wc -l | tr -d ' ')
MEMO_USAGE=${MEMO_USAGE:-0}
MISSING_MEMO=$((COMPONENT_FILES > MEMO_USAGE ? COMPONENT_FILES - MEMO_USAGE : 0))
TOTAL_ISSUES=$((TOTAL_ISSUES + MISSING_MEMO))

if [ "$MISSING_MEMO" -gt 0 ]; then
  log_warning "Found $MISSING_MEMO components potentially missing React.memo"
else
  log_success "Good React.memo usage in components"
fi

# 5. Client Components that could be Server Components
log_info "Checking for unnecessary 'use client' directives..."
CLIENT_COMPONENTS=$(grep -r "^'use client'" "$WEB_APP_DIR/app" 2>/dev/null | wc -l | tr -d ' ')
CLIENT_COMPONENTS=${CLIENT_COMPONENTS:-0}
# Check if they use client-only features
INTERACTIVE_FEATURES=$(grep -r "useState\|useEffect\|onClick\|onChange" "$WEB_APP_DIR/app" 2>/dev/null | wc -l | tr -d ' ')
INTERACTIVE_FEATURES=${INTERACTIVE_FEATURES:-0}
UNNECESSARY_CLIENT=$((CLIENT_COMPONENTS > INTERACTIVE_FEATURES / 2 ? (CLIENT_COMPONENTS - INTERACTIVE_FEATURES / 2) : 0))
TOTAL_ISSUES=$((TOTAL_ISSUES + UNNECESSARY_CLIENT))

if [ "$UNNECESSARY_CLIENT" -gt 0 ]; then
  log_warning "Found ~$UNNECESSARY_CLIENT potentially unnecessary 'use client' directives"
else
  log_success "Good Server/Client Component split"
fi

# 6. Large bundle imports (importing entire libraries)
log_info "Checking for non-tree-shakeable imports..."
FULL_IMPORTS=$(grep -r "import \* as\|import _ from 'lodash'" "$WEB_APP_DIR" 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ')
FULL_IMPORTS=${FULL_IMPORTS:-0}
TOTAL_ISSUES=$((TOTAL_ISSUES + FULL_IMPORTS))

if [ "$FULL_IMPORTS" -gt 0 ]; then
  log_warning "Found $FULL_IMPORTS non-tree-shakeable imports"
  echo "  Example locations:"
  (grep -r "import \* as\|import _ from 'lodash'" "$WEB_APP_DIR" 2>/dev/null | grep -v "node_modules" | head -3 | sed 's/^/    /') || true
else
  log_success "No non-tree-shakeable imports found"
fi

# Generate recommendations
log_section "Recommendations"

RECOMMENDATIONS=()

if [ "$INLINE_FUNCTIONS" -gt 0 ]; then
  RECOMMENDATIONS+=("Use useCallback for event handlers instead of inline arrow functions")
fi

if [ "$MISSING_USEMEMO_VIOLATIONS" -gt 0 ]; then
  RECOMMENDATIONS+=("Wrap expensive computations (.map, .filter, .reduce) with useMemo")
fi

if [ "$USEEFFECT_VIOLATIONS" -gt 0 ]; then
  RECOMMENDATIONS+=("Review useEffect dependency arrays for missing dependencies")
fi

if [ "$MISSING_MEMO" -gt 0 ]; then
  RECOMMENDATIONS+=("Consider wrapping pure components with React.memo")
fi

if [ "$UNNECESSARY_CLIENT" -gt 0 ]; then
  RECOMMENDATIONS+=("Convert Client Components to Server Components where possible")
fi

if [ "$FULL_IMPORTS" -gt 0 ]; then
  RECOMMENDATIONS+=("Use named imports instead of importing entire libraries")
fi

if [ ${#RECOMMENDATIONS[@]} -eq 0 ]; then
  log_success "No major performance issues detected!"
else
  echo ""
  for i in "${!RECOMMENDATIONS[@]}"; do
    echo "$((i + 1)). ${RECOMMENDATIONS[$i]}"
  done
fi

# Create JSON report
RECOMMENDATIONS_JSON=$(printf '%s\n' "${RECOMMENDATIONS[@]}" | jq -R . | jq -s .)

REPORT_JSON=$(cat <<EOF
{
  "timestamp": "$(get_timestamp)",
  "runtime": {
    "antiPatterns": {
      "inlineFunctions": $INLINE_FUNCTIONS,
      "missingUseMemo": $MISSING_USEMEMO_VIOLATIONS,
      "useEffectDependencies": $USEEFFECT_VIOLATIONS,
      "missingMemo": $MISSING_MEMO,
      "unnecessaryClient": $UNNECESSARY_CLIENT,
      "fullImports": $FULL_IMPORTS
    },
    "totalIssues": $TOTAL_ISSUES,
    "recommendations": $RECOMMENDATIONS_JSON,
    "status": "$([ "$TOTAL_ISSUES" -le 10 ] && echo "PASS" || echo "WARN")"
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
  STATUS=$([ "$TOTAL_ISSUES" -le 10 ] && echo "PASS" || echo "WARN")
  gh_output "runtime_status" "$STATUS"
  gh_output "total_issues" "$TOTAL_ISSUES"

  gh_summary "## Runtime Performance Analysis

**Total Issues Found**: $TOTAL_ISSUES

| Anti-Pattern | Count |
|--------------|-------|
| Inline Arrow Functions | $INLINE_FUNCTIONS |
| Missing useMemo | $MISSING_USEMEMO_VIOLATIONS |
| useEffect Dependencies | $USEEFFECT_VIOLATIONS |
| Missing React.memo | $MISSING_MEMO |
| Unnecessary Client Components | $UNNECESSARY_CLIENT |
| Non-tree-shakeable Imports | $FULL_IMPORTS |

**Recommendations**:
$(for rec in "${RECOMMENDATIONS[@]}"; do echo "- $rec"; done)
"
fi

# Final status
log_section "Final Status"

if [ "$TOTAL_ISSUES" -le 5 ]; then
  log_success "Excellent runtime performance patterns (≤5 issues)"
  exit 0
elif [ "$TOTAL_ISSUES" -le 10 ]; then
  log_warning "Good runtime performance with minor improvements (6-10 issues)"

  if [ "$FAIL_ON_ISSUES" = true ]; then
    exit 1
  else
    exit 0
  fi
else
  log_warning "Runtime performance needs improvement (>10 issues)"

  if [ "$FAIL_ON_ISSUES" = true ]; then
    exit 1
  else
    exit 0
  fi
fi

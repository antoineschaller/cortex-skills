#!/bin/bash

# Core Web Vitals Measurement Script
# Uses Lighthouse CI to measure Core Web Vitals (LCP, FID/INP, CLS)

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Usage text
USAGE_TEXT="<url> [--mobile] [--output <file>]"

# Default values
URL=""
PRESET="desktop"
OUTPUT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage "${0##*/}" "$USAGE_TEXT"
      echo ""
      echo "Measures Core Web Vitals using Lighthouse CI."
      echo ""
      echo "Arguments:"
      echo "  url                   URL to test (e.g., https://staging.ballee.io)"
      echo ""
      echo "Options:"
      echo "  --mobile              Use mobile preset instead of desktop"
      echo "  --output <file>       Save JSON report to file"
      echo "  -h, --help            Show this help message"
      exit 0
      ;;
    --mobile)
      PRESET="mobile"
      shift
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -*)
      log_error "Unknown option: $1"
      print_usage "${0##*/}" "$USAGE_TEXT"
      exit 1
      ;;
    *)
      if [ -z "$URL" ]; then
        URL="$1"
      else
        log_error "Too many arguments"
        print_usage "${0##*/}" "$USAGE_TEXT"
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate required arguments
if [ -z "$URL" ]; then
  log_error "URL is required"
  print_usage "${0##*/}" "$USAGE_TEXT"
  exit 1
fi

# Validate URL format
validate_url "$URL"

# Initialize
init_script
log_section "Core Web Vitals Measurement"
log_info "URL: $URL"
log_info "Preset: $PRESET"

# Check if Lighthouse CI is installed
if ! command_exists lhci; then
  log_warning "Lighthouse CI not found, installing..."

  WEB_APP_DIR="$(get_web_app_dir)"
  cd "$WEB_APP_DIR"

  pnpm add -D @lhci/cli

  if ! command_exists lhci; then
    log_error "Failed to install Lighthouse CI"
    exit 1
  fi
fi

# Get Lighthouse config
LIGHTHOUSE_CONFIG="$(get_lighthouse_config)"
log_info "Using config: $LIGHTHOUSE_CONFIG"

# Create temporary directory for Lighthouse output
TEMP_DIR=$(create_temp_dir)
LIGHTHOUSE_DIR="$TEMP_DIR/.lighthouseci"
mkdir -p "$LIGHTHOUSE_DIR"

cleanup_on_exit() {
  cleanup_temp_dir "$TEMP_DIR"
}

# Run Lighthouse
log_section "Running Lighthouse"

# Update config with current URL and preset
TEMP_CONFIG="$TEMP_DIR/lighthouse-config.json"
jq ".ci.collect.url = [\"$URL\"] | .ci.collect.settings.preset = \"$PRESET\"" "$LIGHTHOUSE_CONFIG" > "$TEMP_CONFIG"

# Run lhci
log_info "Running Lighthouse (3 runs, ~90 seconds)..."

WEB_APP_DIR="$(get_web_app_dir)"
cd "$WEB_APP_DIR"

if ! npx --yes @lhci/cli@latest collect \
  --url="$URL" \
  --numberOfRuns=3 \
  --settings.preset="$PRESET" \
  --settings.onlyCategories=performance 2>&1 | tee "$TEMP_DIR/lighthouse.log"; then
  log_error "Lighthouse run failed"
  cat "$TEMP_DIR/lighthouse.log"
  exit 1
fi

# Find latest Lighthouse report
LIGHTHOUSE_REPORT=$(find "$LIGHTHOUSE_DIR" -name "lhr-*.json" 2>/dev/null | sort | tail -1)

if [ -z "$LIGHTHOUSE_REPORT" ] || [ ! -f "$LIGHTHOUSE_REPORT" ]; then
  # Try alternative location
  LIGHTHOUSE_REPORT=$(find . -name "lhr-*.json" 2>/dev/null | sort | tail -1)

  if [ -z "$LIGHTHOUSE_REPORT" ] || [ ! -f "$LIGHTHOUSE_REPORT" ]; then
    log_error "Lighthouse report not found"
    log_info "Looked in: $LIGHTHOUSE_DIR and current directory"
    exit 1
  fi
fi

log_success "Lighthouse report found: $LIGHTHOUSE_REPORT"

# Parse Lighthouse results
log_section "Parsing Results"

# Extract metrics using jq
PERFORMANCE_SCORE=$(jq -r '.categories.performance.score' "$LIGHTHOUSE_REPORT")
FCP=$(jq -r '.audits["first-contentful-paint"].numericValue' "$LIGHTHOUSE_REPORT")
LCP=$(jq -r '.audits["largest-contentful-paint"].numericValue' "$LIGHTHOUSE_REPORT")
CLS=$(jq -r '.audits["cumulative-layout-shift"].numericValue' "$LIGHTHOUSE_REPORT")
TBT=$(jq -r '.audits["total-blocking-time"].numericValue' "$LIGHTHOUSE_REPORT")
SI=$(jq -r '.audits["speed-index"].numericValue' "$LIGHTHOUSE_REPORT")
TTI=$(jq -r '.audits["interactive"].numericValue' "$LIGHTHOUSE_REPORT")

# Convert to human-readable
PERFORMANCE_SCORE_PCT=$(format_percentage "$PERFORMANCE_SCORE")
FCP_S=$(format_ms_to_s "$FCP")
LCP_S=$(format_ms_to_s "$LCP")
TBT_MS="${TBT}ms"
SI_S=$(format_ms_to_s "$SI")
TTI_S=$(format_ms_to_s "$TTI")

# Get INP if available (newer Lighthouse versions)
INP=$(jq -r '.audits["interaction-to-next-paint"]?.numericValue // "null"' "$LIGHTHOUSE_REPORT")
if [ "$INP" = "null" ]; then
  INP="N/A"
  INP_STATUS="N/A"
else
  INP_MS="${INP}ms"
  if check_threshold "$INP" 200 "less"; then
    INP_STATUS="PASS"
  else
    INP_STATUS="FAIL"
  fi
fi

# Display results
log_section "Core Web Vitals Results"

echo "Performance Score: $PERFORMANCE_SCORE_PCT"
echo ""
echo "Core Web Vitals:"
echo "  FCP (First Contentful Paint):    $FCP_S"
echo "  LCP (Largest Contentful Paint):  $LCP_S"
echo "  CLS (Cumulative Layout Shift):   $CLS"
if [ "$INP" != "N/A" ]; then
  echo "  INP (Interaction to Next Paint): $INP_MS"
fi
echo ""
echo "Additional Metrics:"
echo "  TBT (Total Blocking Time):       $TBT_MS"
echo "  SI (Speed Index):                $SI_S"
echo "  TTI (Time to Interactive):       $TTI_S"

# Check against thresholds
log_section "Threshold Comparison"

OVERALL_STATUS="PASS"
FAILURES=()

# Performance Score (>= 90)
SCORE_THRESHOLD=0.9
if check_threshold "$PERFORMANCE_SCORE" "$SCORE_THRESHOLD" "greater"; then
  log_success "Performance Score $PERFORMANCE_SCORE_PCT >= 90%"
else
  OVERALL_STATUS="FAIL"
  FAILURES+=("Performance score $PERFORMANCE_SCORE_PCT < 90%")
  log_error "Performance Score $PERFORMANCE_SCORE_PCT < 90%"
fi

# LCP (<= 2.5s = 2500ms)
LCP_THRESHOLD=2500
if check_threshold "$LCP" "$LCP_THRESHOLD" "less"; then
  log_success "LCP $LCP_S <= 2.5s"
else
  OVERALL_STATUS="FAIL"
  FAILURES+=("LCP $LCP_S > 2.5s")
  log_error "LCP $LCP_S > 2.5s"
fi

# CLS (<= 0.1)
CLS_THRESHOLD=0.1
if check_threshold "$CLS" "$CLS_THRESHOLD" "less"; then
  log_success "CLS $CLS <= 0.1"
else
  OVERALL_STATUS="FAIL"
  FAILURES+=("CLS $CLS > 0.1")
  log_error "CLS $CLS > 0.1"
fi

# INP (<= 200ms) - if available
if [ "$INP" != "N/A" ]; then
  INP_THRESHOLD=200
  if check_threshold "$INP" "$INP_THRESHOLD" "less"; then
    log_success "INP $INP_MS <= 200ms"
  else
    OVERALL_STATUS="WARN"
    FAILURES+=("INP $INP_MS > 200ms (warning)")
    log_warning "INP $INP_MS > 200ms"
  fi
fi

# Create JSON report
FCP_FORMATTED=$(printf "%.0f" "$FCP")
LCP_FORMATTED=$(printf "%.0f" "$LCP")
TBT_FORMATTED=$(printf "%.0f" "$TBT")
SI_FORMATTED=$(printf "%.0f" "$SI")
TTI_FORMATTED=$(printf "%.0f" "$TTI")

REPORT_JSON=$(cat <<EOF
{
  "timestamp": "$(get_timestamp)",
  "url": "$URL",
  "preset": "$PRESET",
  "coreWebVitals": {
    "performanceScore": $(printf "%.0f" "$(echo "$PERFORMANCE_SCORE * 100" | bc)"),
    "fcp": $FCP_FORMATTED,
    "fcpFormatted": "$FCP_S",
    "lcp": $LCP_FORMATTED,
    "lcpFormatted": "$LCP_S",
    "cls": $CLS,
    "inp": $([ "$INP" = "N/A" ] && echo "null" || printf "%.0f" "$INP"),
    "inpFormatted": "$([ "$INP" = "N/A" ] && echo "N/A" || echo "$INP_MS")",
    "tbt": $TBT_FORMATTED,
    "tbtFormatted": "$TBT_MS",
    "speedIndex": $SI_FORMATTED,
    "speedIndexFormatted": "$SI_S",
    "tti": $TTI_FORMATTED,
    "ttiFormatted": "$TTI_S",
    "status": "$OVERALL_STATUS",
    "failures": $(printf '%s\n' "${FAILURES[@]}" | jq -R . | jq -s .)
  },
  "lighthouseReport": "$LIGHTHOUSE_REPORT"
}
EOF
)

# Output report
if [ -n "$OUTPUT_FILE" ]; then
  create_json_report "$REPORT_JSON" "$OUTPUT_FILE"
fi

# GitHub Actions output
if is_ci; then
  gh_output "vitals_status" "$OVERALL_STATUS"
  gh_output "performance_score" "$PERFORMANCE_SCORE_PCT"
  gh_output "lcp" "$LCP_S"
  gh_output "cls" "$CLS"

  gh_summary "## Core Web Vitals ($PRESET)

**URL**: $URL

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Performance Score | $PERFORMANCE_SCORE_PCT | ≥ 90% | $([ "$OVERALL_STATUS" = "PASS" ] && echo "✅" || echo "❌") |
| LCP | $LCP_S | ≤ 2.5s | $(check_threshold "$LCP" 2500 "less" && echo "✅" || echo "❌") |
| CLS | $CLS | ≤ 0.1 | $(check_threshold "$CLS" 0.1 "less" && echo "✅" || echo "❌") |
| FCP | $FCP_S | ≤ 2.0s | $(check_threshold "$FCP" 2000 "less" && echo "✅" || echo "⚠️") |
$([ "$INP" != "N/A" ] && echo "| INP | $INP_MS | ≤ 200ms | $INP_STATUS |" || echo "")

**Additional Metrics**:
- Total Blocking Time: $TBT_MS
- Speed Index: $SI_S
- Time to Interactive: $TTI_S
"
fi

# Final status
log_section "Final Status"
if [ "$OVERALL_STATUS" = "PASS" ]; then
  log_success "All Core Web Vitals thresholds PASSED"
  exit 0
elif [ "$OVERALL_STATUS" = "WARN" ]; then
  log_warning "Core Web Vitals thresholds PASSED with warnings"
  exit 0
else
  log_error "Core Web Vitals thresholds FAILED"
  exit 1
fi

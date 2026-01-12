#!/bin/bash

# Network Performance Check Script
# Analyzes network and loading performance metrics from Lighthouse report

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Usage text
USAGE_TEXT="[--lighthouse-report <file>] [--output <file>]"

# Default values
LIGHTHOUSE_REPORT=""
OUTPUT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage "${0##*/}" "$USAGE_TEXT"
      echo ""
      echo "Analyzes network and loading performance from Lighthouse report."
      echo ""
      echo "Options:"
      echo "  --lighthouse-report <file>   Path to Lighthouse JSON report"
      echo "  --output <file>              Save JSON report to file"
      echo "  -h, --help                   Show this help message"
      echo ""
      echo "If no Lighthouse report is specified, will look for the latest one."
      exit 0
      ;;
    --lighthouse-report)
      LIGHTHOUSE_REPORT="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
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
log_section "Network Performance Check"

# Find Lighthouse report if not specified
if [ -z "$LIGHTHOUSE_REPORT" ]; then
  log_info "Looking for Lighthouse report..."

  WEB_APP_DIR="$(get_web_app_dir)"

  # Look in common locations
  LIGHTHOUSE_REPORT=$(find "$WEB_APP_DIR" -name "lhr-*.json" 2>/dev/null | sort | tail -1)

  if [ -z "$LIGHTHOUSE_REPORT" ] || [ ! -f "$LIGHTHOUSE_REPORT" ]; then
    # Try .lighthouseci directory
    LIGHTHOUSE_REPORT=$(find . -name "lhr-*.json" 2>/dev/null | sort | tail -1)
  fi

  if [ -z "$LIGHTHOUSE_REPORT" ] || [ ! -f "$LIGHTHOUSE_REPORT" ]; then
    log_error "Lighthouse report not found"
    log_info "Run: ./measure-core-vitals.sh <url> first"
    exit 1
  fi
fi

log_info "Using Lighthouse report: $LIGHTHOUSE_REPORT"

# Extract network metrics from Lighthouse report
log_section "Extracting Network Metrics"

# TTFB (Time to First Byte)
TTFB=$(jq -r '.audits["server-response-time"]?.numericValue // 0' "$LIGHTHOUSE_REPORT")
TTFB_MS="${TTFB}ms"

# Total requests
TOTAL_REQUESTS=$(jq -r '.audits.diagnostics?.details?.items[0]?.numRequests // 0' "$LIGHTHOUSE_REPORT")

# Total transfer size
TOTAL_SIZE=$(jq -r '.audits.diagnostics?.details?.items[0]?.totalByteWeight // 0' "$LIGHTHOUSE_REPORT")
TOTAL_SIZE_HUMAN=$(bytes_to_human "$TOTAL_SIZE")

# Resource breakdown
JS_SIZE=$(jq -r '[.audits["resource-summary"]?.details?.items[]? | select(.resourceType == "script") | .transferSize] | add // 0' "$LIGHTHOUSE_REPORT")
CSS_SIZE=$(jq -r '[.audits["resource-summary"]?.details?.items[]? | select(.resourceType == "stylesheet") | .transferSize] | add // 0' "$LIGHTHOUSE_REPORT")
IMAGE_SIZE=$(jq -r '[.audits["resource-summary"]?.details?.items[]? | select(.resourceType == "image") | .transferSize] | add // 0' "$LIGHTHOUSE_REPORT")
FONT_SIZE=$(jq -r '[.audits["resource-summary"]?.details?.items[]? | select(.resourceType == "font") | .transferSize] | add // 0' "$LIGHTHOUSE_REPORT")

JS_SIZE_HUMAN=$(bytes_to_human "$JS_SIZE")
CSS_SIZE_HUMAN=$(bytes_to_human "$CSS_SIZE")
IMAGE_SIZE_HUMAN=$(bytes_to_human "$IMAGE_SIZE")
FONT_SIZE_HUMAN=$(bytes_to_human "$FONT_SIZE")

# Render-blocking resources
RENDER_BLOCKING=$(jq -r '[.audits["render-blocking-resources"]?.details?.items[]? | .url] | length' "$LIGHTHOUSE_REPORT")

# Modern image formats (WebP/AVIF)
MODERN_IMAGE_SCORE=$(jq -r '.audits["modern-image-formats"]?.score // 1' "$LIGHTHOUSE_REPORT")
MODERN_IMAGE_SAVINGS=$(jq -r '.audits["modern-image-formats"]?.details?.overallSavingsBytes // 0' "$LIGHTHOUSE_REPORT")

# Font display
FONT_DISPLAY_SCORE=$(jq -r '.audits["font-display"]?.score // 1' "$LIGHTHOUSE_REPORT")

# Display results
log_section "Network Performance Results"

echo "TTFB (Time to First Byte):    $TTFB_MS"
echo "Total Requests:                $TOTAL_REQUESTS"
echo "Total Transfer Size:           $TOTAL_SIZE_HUMAN"
echo ""
echo "Resource Breakdown:"
echo "  JavaScript:                  $JS_SIZE_HUMAN"
echo "  CSS:                         $CSS_SIZE_HUMAN"
echo "  Images:                      $IMAGE_SIZE_HUMAN"
echo "  Fonts:                       $FONT_SIZE_HUMAN"
echo ""
echo "Optimization Opportunities:"
echo "  Render-blocking resources:   $RENDER_BLOCKING"
echo "  Modern image format savings: $(bytes_to_human "$MODERN_IMAGE_SAVINGS")"
echo "  Font display optimization:   $([ "$FONT_DISPLAY_SCORE" = "1" ] && echo "✓ Good" || echo "⚠ Needs improvement")"

# Check against thresholds
log_section "Threshold Comparison"

OVERALL_STATUS="PASS"
WARNINGS=()

# TTFB threshold: < 600ms
TTFB_THRESHOLD=600
if check_threshold "$TTFB" "$TTFB_THRESHOLD" "less"; then
  log_success "TTFB $TTFB_MS < 600ms"
else
  OVERALL_STATUS="WARN"
  WARNINGS+=("TTFB $TTFB_MS > 600ms")
  log_warning "TTFB $TTFB_MS > 600ms"
fi

# Total requests threshold: < 50
REQUESTS_THRESHOLD=50
if [ "$TOTAL_REQUESTS" -lt "$REQUESTS_THRESHOLD" ]; then
  log_success "Total requests $TOTAL_REQUESTS < 50"
else
  OVERALL_STATUS="WARN"
  WARNINGS+=("Total requests $TOTAL_REQUESTS >= 50")
  log_warning "Total requests $TOTAL_REQUESTS >= 50"
fi

# Total size threshold: < 2MB
SIZE_THRESHOLD=2097152  # 2MB in bytes
if check_threshold "$TOTAL_SIZE" "$SIZE_THRESHOLD" "less"; then
  log_success "Total size $TOTAL_SIZE_HUMAN < 2MB"
else
  OVERALL_STATUS="WARN"
  WARNINGS+=("Total size $TOTAL_SIZE_HUMAN >= 2MB")
  log_warning "Total size $TOTAL_SIZE_HUMAN >= 2MB"
fi

# Render-blocking resources
if [ "$RENDER_BLOCKING" -eq 0 ]; then
  log_success "No render-blocking resources"
elif [ "$RENDER_BLOCKING" -le 2 ]; then
  log_warning "$RENDER_BLOCKING render-blocking resources (minimal)"
else
  OVERALL_STATUS="WARN"
  WARNINGS+=("$RENDER_BLOCKING render-blocking resources")
  log_warning "$RENDER_BLOCKING render-blocking resources"
fi

# Modern image formats
if [ "$MODERN_IMAGE_SAVINGS" -eq 0 ]; then
  log_success "Images optimally formatted"
elif [ "$MODERN_IMAGE_SAVINGS" -lt 102400 ]; then  # < 100KB
  log_warning "$(bytes_to_human "$MODERN_IMAGE_SAVINGS") potential image savings (minor)"
else
  OVERALL_STATUS="WARN"
  WARNINGS+=("$(bytes_to_human "$MODERN_IMAGE_SAVINGS") potential image savings")
  log_warning "$(bytes_to_human "$MODERN_IMAGE_SAVINGS") potential image savings"
fi

# Create JSON report
TTFB_FORMATTED=$(printf "%.0f" "$TTFB")
JS_SIZE_FORMATTED=$(printf "%.0f" "$JS_SIZE")
CSS_SIZE_FORMATTED=$(printf "%.0f" "$CSS_SIZE")
IMAGE_SIZE_FORMATTED=$(printf "%.0f" "$IMAGE_SIZE")
FONT_SIZE_FORMATTED=$(printf "%.0f" "$FONT_SIZE")
TOTAL_SIZE_FORMATTED=$(printf "%.0f" "$TOTAL_SIZE")
MODERN_IMAGE_SAVINGS_FORMATTED=$(printf "%.0f" "$MODERN_IMAGE_SAVINGS")

REPORT_JSON=$(cat <<EOF
{
  "timestamp": "$(get_timestamp)",
  "network": {
    "ttfb": $TTFB_FORMATTED,
    "ttfbFormatted": "$TTFB_MS",
    "totalRequests": $TOTAL_REQUESTS,
    "totalSize": $TOTAL_SIZE_FORMATTED,
    "totalSizeFormatted": "$TOTAL_SIZE_HUMAN",
    "resourceBreakdown": {
      "javascript": $JS_SIZE_FORMATTED,
      "javascriptFormatted": "$JS_SIZE_HUMAN",
      "css": $CSS_SIZE_FORMATTED,
      "cssFormatted": "$CSS_SIZE_HUMAN",
      "images": $IMAGE_SIZE_FORMATTED,
      "imagesFormatted": "$IMAGE_SIZE_HUMAN",
      "fonts": $FONT_SIZE_FORMATTED,
      "fontsFormatted": "$FONT_SIZE_HUMAN"
    },
    "renderBlockingResources": $RENDER_BLOCKING,
    "modernImageSavings": $MODERN_IMAGE_SAVINGS_FORMATTED,
    "modernImageSavingsFormatted": "$(bytes_to_human "$MODERN_IMAGE_SAVINGS")",
    "fontDisplayScore": $FONT_DISPLAY_SCORE,
    "status": "$OVERALL_STATUS",
    "warnings": $(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)
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
  gh_output "network_status" "$OVERALL_STATUS"
  gh_output "ttfb" "$TTFB_MS"
  gh_output "total_size" "$TOTAL_SIZE_HUMAN"

  gh_summary "## Network Performance

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| TTFB | $TTFB_MS | < 600ms | $(check_threshold "$TTFB" 600 "less" && echo "✅" || echo "⚠️") |
| Total Requests | $TOTAL_REQUESTS | < 50 | $([ "$TOTAL_REQUESTS" -lt 50 ] && echo "✅" || echo "⚠️") |
| Total Size | $TOTAL_SIZE_HUMAN | < 2MB | $(check_threshold "$TOTAL_SIZE" 2097152 "less" && echo "✅" || echo "⚠️") |

**Resource Breakdown**:
- JavaScript: $JS_SIZE_HUMAN
- CSS: $CSS_SIZE_HUMAN
- Images: $IMAGE_SIZE_HUMAN
- Fonts: $FONT_SIZE_HUMAN

**Optimization Opportunities**:
- Render-blocking resources: $RENDER_BLOCKING
- Modern image format savings: $(bytes_to_human "$MODERN_IMAGE_SAVINGS")
"
fi

# Final status
log_section "Final Status"
if [ "$OVERALL_STATUS" = "PASS" ]; then
  log_success "All network performance metrics PASSED"
  exit 0
else
  log_warning "Network performance has warnings (not critical)"
  exit 0
fi

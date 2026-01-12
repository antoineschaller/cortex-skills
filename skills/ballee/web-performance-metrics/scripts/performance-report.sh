#!/bin/bash

# Performance Report Generator
# Runs all performance checks and generates consolidated report

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Usage text
USAGE_TEXT="--url <url> [--output <file>] [--skip-bundle] [--skip-vitals] [--skip-runtime] [--skip-network] [--mobile]"

# Default values
URL=""
OUTPUT_FILE="report.json"
SKIP_BUNDLE=false
SKIP_VITALS=false
SKIP_RUNTIME=false
SKIP_NETWORK=false
PRESET="desktop"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_usage "${0##*/}" "$USAGE_TEXT"
      echo ""
      echo "Runs all performance checks and generates consolidated report."
      echo ""
      echo "Arguments:"
      echo "  --url <url>           URL to test (required for vitals/network checks)"
      echo ""
      echo "Options:"
      echo "  --output <file>       Save report to file (default: report.json)"
      echo "  --skip-bundle         Skip bundle size analysis"
      echo "  --skip-vitals         Skip Core Web Vitals measurement"
      echo "  --skip-runtime        Skip runtime performance analysis"
      echo "  --skip-network        Skip network performance check"
      echo "  --mobile              Use mobile preset for Lighthouse"
      echo "  -h, --help            Show this help message"
      exit 0
      ;;
    --url)
      URL="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --skip-bundle)
      SKIP_BUNDLE=true
      shift
      ;;
    --skip-vitals)
      SKIP_VITALS=true
      shift
      ;;
    --skip-runtime)
      SKIP_RUNTIME=true
      shift
      ;;
    --skip-network)
      SKIP_NETWORK=true
      shift
      ;;
    --mobile)
      PRESET="mobile"
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
log_section "Performance Report Generator"

# Create temporary directory for individual reports
TEMP_DIR=$(create_temp_dir)
BUNDLE_REPORT="$TEMP_DIR/bundle.json"
VITALS_REPORT="$TEMP_DIR/vitals.json"
RUNTIME_REPORT="$TEMP_DIR/runtime.json"
NETWORK_REPORT="$TEMP_DIR/network.json"

cleanup_on_exit() {
  cleanup_temp_dir "$TEMP_DIR"
}

# Track overall status
OVERALL_STATUS="PASS"

# 1. Bundle Size Analysis
if [ "$SKIP_BUNDLE" = false ]; then
  log_section "1/4 Bundle Size Analysis"

  if "$SCRIPT_DIR/analyze-bundle.sh" --output "$BUNDLE_REPORT"; then
    log_success "Bundle analysis completed"
  else
    log_warning "Bundle analysis had issues"
    OVERALL_STATUS="WARN"
  fi
else
  log_info "Skipping bundle analysis"
  echo '{"bundle": {"budgetStatus": "SKIPPED"}}' > "$BUNDLE_REPORT"
fi

# 2. Core Web Vitals
if [ "$SKIP_VITALS" = false ]; then
  log_section "2/4 Core Web Vitals Measurement"

  if [ -z "$URL" ]; then
    log_error "URL is required for Core Web Vitals measurement"
    log_info "Use: --url https://staging.ballee.io"
    exit 1
  fi

  VITALS_ARGS="$URL --output $VITALS_REPORT"
  if [ "$PRESET" = "mobile" ]; then
    VITALS_ARGS="$VITALS_ARGS --mobile"
  fi

  if "$SCRIPT_DIR/measure-core-vitals.sh" $VITALS_ARGS; then
    log_success "Core Web Vitals measurement completed"
  else
    log_error "Core Web Vitals measurement failed"
    OVERALL_STATUS="FAIL"
  fi
else
  log_info "Skipping Core Web Vitals measurement"
  echo '{"coreWebVitals": {"status": "SKIPPED"}}' > "$VITALS_REPORT"
fi

# 3. Runtime Performance Analysis
if [ "$SKIP_RUNTIME" = false ]; then
  log_section "3/4 Runtime Performance Analysis"

  if "$SCRIPT_DIR/analyze-runtime.sh" --output "$RUNTIME_REPORT"; then
    log_success "Runtime analysis completed"
  else
    log_warning "Runtime analysis had issues"
  fi
else
  log_info "Skipping runtime analysis"
  echo '{"runtime": {"status": "SKIPPED"}}' > "$RUNTIME_REPORT"
fi

# 4. Network Performance Check
if [ "$SKIP_NETWORK" = false ]; then
  log_section "4/4 Network Performance Check"

  if "$SCRIPT_DIR/check-network-perf.sh" --output "$NETWORK_REPORT"; then
    log_success "Network performance check completed"
  else
    log_warning "Network performance check had issues"
  fi
else
  log_info "Skipping network performance check"
  echo '{"network": {"status": "SKIPPED"}}' > "$NETWORK_REPORT"
fi

# Consolidate reports
log_section "Consolidating Results"

# Merge all JSON reports
CONSOLIDATED_JSON=$(jq -s '
  {
    timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    url: $url,
    preset: $preset,
    bundle: (.[0].bundle // {budgetStatus: "SKIPPED"}),
    coreWebVitals: (.[1].coreWebVitals // {status: "SKIPPED"}),
    runtime: (.[2].runtime // {status: "SKIPPED"}),
    network: (.[3].network // {status: "SKIPPED"}),
    overallStatus: $overallStatus
  }
' \
  --arg url "$URL" \
  --arg preset "$PRESET" \
  --arg overallStatus "$OVERALL_STATUS" \
  "$BUNDLE_REPORT" "$VITALS_REPORT" "$RUNTIME_REPORT" "$NETWORK_REPORT")

# Save consolidated report
echo "$CONSOLIDATED_JSON" | jq '.' > "$OUTPUT_FILE"
log_success "Consolidated report saved to: $OUTPUT_FILE"

# Display summary
log_section "Performance Summary"

# Extract key metrics
BUNDLE_STATUS=$(echo "$CONSOLIDATED_JSON" | jq -r '.bundle.budgetStatus // "N/A"')
BUNDLE_SIZE=$(echo "$CONSOLIDATED_JSON" | jq -r '.bundle.totalSize // "N/A"')

VITALS_STATUS=$(echo "$CONSOLIDATED_JSON" | jq -r '.coreWebVitals.status // "N/A"')
PERF_SCORE=$(echo "$CONSOLIDATED_JSON" | jq -r '.coreWebVitals.performanceScore // "N/A"')
LCP=$(echo "$CONSOLIDATED_JSON" | jq -r '.coreWebVitals.lcpFormatted // "N/A"')
CLS=$(echo "$CONSOLIDATED_JSON" | jq -r '.coreWebVitals.cls // "N/A"')

RUNTIME_ISSUES=$(echo "$CONSOLIDATED_JSON" | jq -r '.runtime.totalIssues // "N/A"')

NETWORK_STATUS=$(echo "$CONSOLIDATED_JSON" | jq -r '.network.status // "N/A"')
TTFB=$(echo "$CONSOLIDATED_JSON" | jq -r '.network.ttfbFormatted // "N/A"')
TOTAL_SIZE=$(echo "$CONSOLIDATED_JSON" | jq -r '.network.totalSizeFormatted // "N/A"')

echo ""
echo "╔═══════════════════════════════════════════════════╗"
echo "║           PERFORMANCE REPORT SUMMARY              ║"
echo "╠═══════════════════════════════════════════════════╣"
echo "║                                                   ║"
echo "║  Bundle Size                                      ║"
echo "║    Status: $(printf "%-38s" "$BUNDLE_STATUS") ║"
echo "║    Total:  $(printf "%-38s" "$BUNDLE_SIZE") ║"
echo "║                                                   ║"
echo "║  Core Web Vitals                                  ║"
echo "║    Status: $(printf "%-38s" "$VITALS_STATUS") ║"
echo "║    Score:  $(printf "%-38s" "$PERF_SCORE") ║"
echo "║    LCP:    $(printf "%-38s" "$LCP") ║"
echo "║    CLS:    $(printf "%-38s" "$CLS") ║"
echo "║                                                   ║"
echo "║  Runtime Performance                              ║"
echo "║    Issues: $(printf "%-38s" "$RUNTIME_ISSUES") ║"
echo "║                                                   ║"
echo "║  Network Performance                              ║"
echo "║    Status: $(printf "%-38s" "$NETWORK_STATUS") ║"
echo "║    TTFB:   $(printf "%-38s" "$TTFB") ║"
echo "║    Size:   $(printf "%-38s" "$TOTAL_SIZE") ║"
echo "║                                                   ║"
echo "╠═══════════════════════════════════════════════════╣"
echo "║  Overall Status: $(printf "%-32s" "$OVERALL_STATUS") ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

# GitHub Actions output
if is_ci; then
  gh_output "overall_status" "$OVERALL_STATUS"
  gh_output "report_file" "$OUTPUT_FILE"

  # Generate comprehensive summary
  SUMMARY="## 🚀 Performance Report

**URL**: $URL
**Preset**: $PRESET
**Timestamp**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

### Bundle Size
| Metric | Value | Status |
|--------|-------|--------|
| Total Size | $BUNDLE_SIZE | $BUNDLE_STATUS |

### Core Web Vitals
| Metric | Value | Status |
|--------|-------|--------|
| Performance Score | $PERF_SCORE | $VITALS_STATUS |
| LCP | $LCP | - |
| CLS | $CLS | - |

### Runtime Performance
| Metric | Value |
|--------|-------|
| Total Issues | $RUNTIME_ISSUES |

### Network Performance
| Metric | Value | Status |
|--------|-------|--------|
| TTFB | $TTFB | $NETWORK_STATUS |
| Total Size | $TOTAL_SIZE | - |

---

**Overall Status**: $([ "$OVERALL_STATUS" = "PASS" ] && echo "✅ PASS" || echo "⚠️ $OVERALL_STATUS")

📊 [View detailed report](https://github.com/\${{ github.repository }}/actions/runs/\${{ github.run_id }})
"

  gh_summary "$SUMMARY"
fi

# Final status
log_section "Final Status"

if [ "$OVERALL_STATUS" = "PASS" ]; then
  log_success "All performance checks PASSED"
  exit 0
elif [ "$OVERALL_STATUS" = "WARN" ]; then
  log_warning "Performance checks completed with WARNINGS"
  exit 0
else
  log_error "Performance checks FAILED"
  exit 1
fi

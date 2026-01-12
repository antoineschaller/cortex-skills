#!/bin/bash

# Common utilities for web performance metrics scripts
# Shared functions for logging, JSON parsing, and threshold checking

set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_success() {
  echo -e "${GREEN}✓${NC} $1"
}

log_error() {
  echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
  echo -e "${YELLOW}!${NC} $1"
}

log_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

log_section() {
  echo -e "\n${BLUE}═══ $1 ═══${NC}\n"
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Require command or exit with error
require_command() {
  if ! command_exists "$1"; then
    log_error "Required command not found: $1"
    if [ -n "${2:-}" ]; then
      log_info "Install with: $2"
    fi
    exit 1
  fi
}

# Load environment variables from .env.local
load_env() {
  local env_file="${1:-.env.local}"

  if [ -f "$env_file" ]; then
    log_info "Loading environment from $env_file"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  else
    log_warning "Environment file not found: $env_file"
  fi
}

# JSON parsing - extract value from JSON
# Usage: extract_json_value '{"key": "value"}' '.key'
extract_json_value() {
  local json="$1"
  local path="$2"

  if command_exists jq; then
    echo "$json" | jq -r "$path"
  else
    log_error "jq is required for JSON parsing"
    exit 1
  fi
}

# JSON parsing from file
# Usage: extract_json_file_value "file.json" '.key'
extract_json_file_value() {
  local file="$1"
  local path="$2"

  if [ ! -f "$file" ]; then
    log_error "JSON file not found: $file"
    exit 1
  fi

  if command_exists jq; then
    jq -r "$path" "$file"
  else
    log_error "jq is required for JSON parsing"
    exit 1
  fi
}

# Convert human-readable size to bytes
# Usage: size_to_bytes "500kb" -> 512000
size_to_bytes() {
  local size="$1"
  local number="${size//[^0-9.]/}"
  local unit="${size//[0-9.]/}"
  # Convert to lowercase for bash 3.2 compatibility
  unit=$(echo "$unit" | tr '[:upper:]' '[:lower:]')

  case "$unit" in
    b)
      echo "$number"
      ;;
    kb)
      echo "$(echo "$number * 1024" | bc)"
      ;;
    mb)
      echo "$(echo "$number * 1024 * 1024" | bc)"
      ;;
    gb)
      echo "$(echo "$number * 1024 * 1024 * 1024" | bc)"
      ;;
    *)
      log_error "Unknown size unit: $unit"
      exit 1
      ;;
  esac
}

# Convert bytes to human-readable size
# Usage: bytes_to_human 512000 -> "500kb"
bytes_to_human() {
  local bytes="$1"

  if command_exists numfmt; then
    numfmt --to=iec-i --suffix=B --format="%.2f" "$bytes" | sed 's/iB/b/'
  else
    # Fallback without numfmt
    if [ "$bytes" -lt 1024 ]; then
      echo "${bytes}b"
    elif [ "$bytes" -lt 1048576 ]; then
      echo "$(echo "scale=2; $bytes / 1024" | bc)kb"
    elif [ "$bytes" -lt 1073741824 ]; then
      echo "$(echo "scale=2; $bytes / 1048576" | bc)mb"
    else
      echo "$(echo "scale=2; $bytes / 1073741824" | bc)gb"
    fi
  fi
}

# Compare numeric values with threshold
# Returns 0 (pass) if value is within threshold, 1 (fail) otherwise
# Usage: check_threshold 450 500 "less" -> 0 (pass)
# Usage: check_threshold 550 500 "less" -> 1 (fail)
check_threshold() {
  local value="$1"
  local threshold="$2"
  local comparison="${3:-less}"  # less or greater

  case "$comparison" in
    less)
      if (( $(echo "$value <= $threshold" | bc -l) )); then
        return 0  # Pass
      else
        return 1  # Fail
      fi
      ;;
    greater)
      if (( $(echo "$value >= $threshold" | bc -l) )); then
        return 0  # Pass
      else
        return 1  # Fail
      fi
      ;;
    *)
      log_error "Unknown comparison: $comparison"
      exit 1
      ;;
  esac
}

# Format percentage
# Usage: format_percentage 0.94 -> "94%"
format_percentage() {
  local value="$1"
  echo "$(echo "scale=0; $value * 100" | bc)%"
}

# Format milliseconds to seconds
# Usage: format_ms_to_s 2100 -> "2.1s"
format_ms_to_s() {
  local ms="$1"
  echo "$(echo "scale=1; $ms / 1000" | bc)s"
}

# Get project root directory (assumes this script is in .claude/skills/*/scripts/lib/)
get_project_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "$(cd "$script_dir/../../../../.." && pwd)"
}

# Get web app directory
get_web_app_dir() {
  echo "$(get_project_root)/apps/web"
}

# Check if running in CI environment
is_ci() {
  [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]
}

# GitHub Actions output
# Usage: gh_output "name" "value"
gh_output() {
  if is_ci && [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "$1=$2" >> "$GITHUB_OUTPUT"
  fi
}

# GitHub Actions summary (PR comment)
# Usage: gh_summary "## Performance Results\n\nAll tests passed"
gh_summary() {
  if is_ci && [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo -e "$1" >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Create temporary directory
create_temp_dir() {
  mktemp -d -t perf-metrics-XXXXXX
}

# Cleanup temporary directory on exit
cleanup_temp_dir() {
  local temp_dir="$1"
  if [ -d "$temp_dir" ]; then
    rm -rf "$temp_dir"
  fi
}

# Validate URL format
validate_url() {
  local url="$1"

  if [[ ! "$url" =~ ^https?:// ]]; then
    log_error "Invalid URL format: $url"
    log_info "URL must start with http:// or https://"
    exit 1
  fi
}

# Load performance budgets from JSON
# Returns path to budgets file
get_budgets_file() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # From lib/, go up to scripts/, then up to skill root, then to resources/
  echo "$script_dir/../../resources/bundle-budgets.json"
}

# Load Lighthouse config from JSON
# Returns path to Lighthouse config file
get_lighthouse_config() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # From lib/, go up to scripts/, then up to skill root, then to resources/
  echo "$script_dir/../../resources/lighthouse-config.json"
}

# Extract budget value from JSON
# Usage: get_budget_value "maxTotalSize" -> "500kb"
get_budget_value() {
  local key="$1"
  local budgets_file
  budgets_file="$(get_budgets_file)"

  if [ ! -f "$budgets_file" ]; then
    log_error "Budgets file not found: $budgets_file"
    exit 1
  fi

  extract_json_file_value "$budgets_file" ".$key"
}

# Get route-specific budget
# Usage: get_route_budget "/admin" -> "300kb"
get_route_budget() {
  local route="$1"
  local budgets_file
  budgets_file="$(get_budgets_file)"

  if [ ! -f "$budgets_file" ]; then
    log_error "Budgets file not found: $budgets_file"
    exit 1
  fi

  local budget
  budget=$(extract_json_file_value "$budgets_file" ".routes[\"$route\"]")

  if [ "$budget" = "null" ]; then
    # Fallback to maxTotalSize if route-specific budget not defined
    budget=$(get_budget_value "maxTotalSize")
  fi

  echo "$budget"
}

# Create JSON report file
# Usage: create_json_report '{"status": "pass"}' "report.json"
create_json_report() {
  local json="$1"
  local output_file="$2"

  echo "$json" | jq '.' > "$output_file"
  log_info "Report saved to: $output_file"
}

# Timestamp for reports
get_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Check if jq is available
check_jq() {
  require_command jq "brew install jq"
}

# Initialize script (common setup)
init_script() {
  check_jq

  # Set trap to cleanup on exit
  trap 'cleanup_on_exit' EXIT INT TERM
}

# Cleanup function called on script exit
cleanup_on_exit() {
  # Can be overridden by individual scripts
  :
}

# Print script usage
print_usage() {
  local script_name="$1"
  local usage_text="$2"

  echo "Usage: $script_name $usage_text"
  echo ""
  echo "Options:"
  echo "  -h, --help     Show this help message"
}

# Parse common arguments
parse_common_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        print_usage "${0##*/}" "${USAGE_TEXT:-[options]}"
        exit 0
        ;;
      *)
        # Unknown argument, handle in calling script
        break
        ;;
    esac
    shift
  done
}

# Export functions for use in other scripts
export -f log_success log_error log_warning log_info log_section
export -f command_exists require_command
export -f load_env
export -f extract_json_value extract_json_file_value
export -f size_to_bytes bytes_to_human
export -f check_threshold
export -f format_percentage format_ms_to_s
export -f get_project_root get_web_app_dir
export -f is_ci gh_output gh_summary
export -f create_temp_dir cleanup_temp_dir
export -f validate_url
export -f get_budgets_file get_lighthouse_config
export -f get_budget_value get_route_budget
export -f create_json_report get_timestamp
export -f check_jq init_script cleanup_on_exit
export -f print_usage parse_common_args

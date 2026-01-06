#!/bin/bash
# analyze-usage.sh - Find which database functions are called in the codebase
#
# Usage:
#   ./analyze-usage.sh <function_name>     # Check single function
#   ./analyze-usage.sh --all <lint.json>   # Check all functions from lint output
#   ./analyze-usage.sh --list              # List all known database functions
#
# Exit codes:
#   0 - Function is used
#   1 - Function is NOT used (or error)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Find project root
PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}"
if [ -z "$PROJECT_ROOT" ]; then
  echo -e "${RED}Error: Could not determine project root${NC}" >&2
  exit 1
fi

# Search locations
SEARCH_PATHS=(
  "$PROJECT_ROOT/apps/web/app"
  "$PROJECT_ROOT/packages/features"
  "$PROJECT_ROOT/apps/web/supabase/migrations"
  "$PROJECT_ROOT/apps/web/supabase/schemas"
  "$PROJECT_ROOT/apps/web/app/__tests__"
)

analyze_function() {
  local func_name="$1"
  local verbose="${2:-false}"

  if [ -z "$func_name" ]; then
    echo -e "${RED}Error: Function name required${NC}" >&2
    return 1
  fi

  local found=0
  local locations=()

  # Search patterns
  local patterns=(
    "rpc(['\"]${func_name}['\"]"           # supabase.rpc('func')
    "\.rpc\(['\"]${func_name}['\"]"        # .rpc('func')
    "FUNCTION.*${func_name}"               # CREATE/DROP FUNCTION
    "EXECUTE.*${func_name}"                # EXECUTE func
    "SELECT.*${func_name}\s*\("            # SELECT func()
    "public\.${func_name}\s*\("            # public.func()
  )

  if [ "$verbose" = "true" ]; then
    echo -e "${BLUE}Analyzing: ${CYAN}$func_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  fi

  for search_path in "${SEARCH_PATHS[@]}"; do
    if [ ! -d "$search_path" ]; then
      continue
    fi

    for pattern in "${patterns[@]}"; do
      # Search for pattern, exclude the function definition itself
      local matches
      matches=$(grep -rn "$pattern" "$search_path" 2>/dev/null | \
                grep -v "CREATE.*FUNCTION.*${func_name}" | \
                grep -v "DROP.*FUNCTION.*${func_name}" | \
                grep -v "REPLACE.*FUNCTION.*${func_name}" | \
                grep -v "GRANT.*FUNCTION.*${func_name}" | \
                grep -v "COMMENT.*FUNCTION.*${func_name}" | \
                grep -v "\.backup-" || true)

      if [ -n "$matches" ]; then
        found=1
        while IFS= read -r line; do
          # Get relative path
          local rel_path="${line#$PROJECT_ROOT/}"
          locations+=("$rel_path")

          if [ "$verbose" = "true" ]; then
            echo -e "${GREEN}Found:${NC} $rel_path"
          fi
        done <<< "$matches"
      fi
    done
  done

  if [ "$verbose" = "true" ]; then
    echo ""
    if [ $found -eq 1 ]; then
      echo -e "${GREEN}Status: USED${NC} (${#locations[@]} references found)"
    else
      echo -e "${YELLOW}Status: UNUSED${NC} (no references found)"
    fi
    echo ""
  else
    # Simple output for scripting
    if [ $found -eq 1 ]; then
      echo "USED:$func_name:${#locations[@]}"
    else
      echo "UNUSED:$func_name:0"
    fi
  fi

  return $((1 - found))
}

analyze_all_from_lint() {
  local lint_file="$1"

  if [ ! -f "$lint_file" ]; then
    echo -e "${RED}Error: Lint file not found: $lint_file${NC}" >&2
    exit 1
  fi

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}Function Usage Analysis${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  # Extract function names from lint JSON
  local functions
  functions=$(jq -r '.[].function' "$lint_file" 2>/dev/null | sort -u)

  if [ -z "$functions" ]; then
    echo -e "${RED}Error: Could not extract functions from lint file${NC}" >&2
    echo "Make sure the file is valid JSON from 'supabase db lint -o json'"
    exit 1
  fi

  local used_count=0
  local unused_count=0
  local used_funcs=()
  local unused_funcs=()

  while IFS= read -r func; do
    # Remove 'public.' prefix if present
    func="${func#public.}"

    if analyze_function "$func" "false" > /dev/null 2>&1; then
      ((used_count++))
      used_funcs+=("$func")
      echo -e "${GREEN}[USED]${NC}   $func"
    else
      ((unused_count++))
      unused_funcs+=("$func")
      echo -e "${YELLOW}[UNUSED]${NC} $func"
    fi
  done <<< "$functions"

  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}Summary${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo -e "Total functions: $((used_count + unused_count))"
  echo -e "${GREEN}Used:${NC}   $used_count"
  echo -e "${YELLOW}Unused:${NC} $unused_count"
  echo ""

  if [ $used_count -gt 0 ]; then
    echo -e "${GREEN}Used Functions (require fixing):${NC}"
    for f in "${used_funcs[@]}"; do
      echo "  - $f"
    done
    echo ""
  fi

  if [ $unused_count -gt 0 ]; then
    echo -e "${YELLOW}Unused Functions (consider dropping):${NC}"
    for f in "${unused_funcs[@]}"; do
      echo "  - $f"
    done
  fi
}

list_database_functions() {
  echo -e "${BLUE}Searching for database functions in migrations...${NC}"
  echo ""

  local migrations_dir="$PROJECT_ROOT/apps/web/supabase/migrations"

  if [ ! -d "$migrations_dir" ]; then
    echo -e "${RED}Error: Migrations directory not found${NC}" >&2
    exit 1
  fi

  # Find CREATE FUNCTION statements
  grep -rh "CREATE.*FUNCTION\s\+public\.\w\+" "$migrations_dir" 2>/dev/null | \
    sed -E 's/.*FUNCTION\s+public\.([a-zA-Z_][a-zA-Z0-9_]*).*/\1/' | \
    sort -u | \
    while read -r func; do
      echo "  $func"
    done
}

# Main
case "${1:-}" in
  --all)
    if [ -z "$2" ]; then
      echo "Usage: ./analyze-usage.sh --all <lint-output.json>"
      exit 1
    fi
    analyze_all_from_lint "$2"
    ;;
  --list)
    list_database_functions
    ;;
  --help|-h)
    echo "Usage: ./analyze-usage.sh <function_name>     # Check single function"
    echo "       ./analyze-usage.sh --all <lint.json>   # Check all from lint"
    echo "       ./analyze-usage.sh --list              # List all functions"
    echo ""
    echo "Exit codes:"
    echo "  0 - Function is used"
    echo "  1 - Function is NOT used"
    ;;
  "")
    echo -e "${RED}Error: Function name required${NC}"
    echo "Usage: ./analyze-usage.sh <function_name>"
    exit 1
    ;;
  *)
    analyze_function "$1" "true"
    ;;
esac

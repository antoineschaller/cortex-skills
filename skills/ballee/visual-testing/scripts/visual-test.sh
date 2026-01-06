#!/bin/bash
# =====================================================================================
# Visual Testing CLI - Screenshot Automation for Ballee
# =====================================================================================
#
# Take screenshots of the running app using Puppeteer for visual verification.
#
# Usage:
#   ./visual-test.sh <command> [options]
#
# Commands:
#   status                      - Check if dev server is running
#   start                       - Start dev server in background
#   stop                        - Stop dev server
#   screenshot <url>            - Take screenshot of URL
#   demo [slide-id]             - Screenshot demo showcase page
#   demo-all                    - Screenshot all demo slides
#   list-slides                 - List available demo slide IDs
#
# Options:
#   --debug           Add ?debug=true to URLs (shows target markers)
#   --viewport WxH    Set viewport (default: 1200x900)
#   --name <name>     Custom screenshot filename
#   --full-page       Capture full page height
#   --wait <ms>       Extra wait time after load (default: 2000)
#
# Examples:
#   ./visual-test.sh status
#   ./visual-test.sh demo cast-assignment --debug
#   ./visual-test.sh demo-all --debug
#   ./visual-test.sh screenshot http://localhost:3012/admin/events
#
# =====================================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DEV_SERVER_PORT="${DEV_SERVER_PORT:-3012}"
DEV_SERVER_URL="http://localhost:$DEV_SERVER_PORT"
SCREENSHOT_DIR="/tmp/ballee-screenshots"
DEMO_BASE_PATH="/demo/fever/showcase"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Demo slide IDs
DEMO_SLIDES=(
  "cast-assignment"
  "contract-acceptance"
  "event-creation"
  "hire-order-view"
  "invoice-download"
  "invoice-validate"
  "reimbursement-upload"
)

# Default options
DEBUG_MODE=false
VIEWPORT="1200x900"
CUSTOM_NAME=""
FULL_PAGE=false
WAIT_TIME=2000

# =====================================================================================
# Helper Functions
# =====================================================================================

print_usage() {
  head -40 "$0" | tail -38
}

check_server() {
  if curl -s -o /dev/null -w "%{http_code}" "$DEV_SERVER_URL" 2>/dev/null | grep -q "200\|304"; then
    return 0
  else
    return 1
  fi
}

ensure_screenshot_dir() {
  mkdir -p "$SCREENSHOT_DIR"
}

get_timestamp() {
  date +"%Y%m%d-%H%M%S"
}

# =====================================================================================
# Commands
# =====================================================================================

cmd_status() {
  echo -e "${BLUE}Checking dev server status...${NC}"

  if check_server; then
    echo -e "${GREEN}Dev server is running on port $DEV_SERVER_PORT${NC}"
    return 0
  else
    echo -e "${RED}Dev server is not running${NC}"
    echo ""
    echo "Start it with:"
    echo "  ./.claude/skills/visual-testing/scripts/visual-test.sh start"
    echo "  or: pnpm dev"
    return 1
  fi
}

cmd_start() {
  echo -e "${BLUE}Starting dev server...${NC}"

  if check_server; then
    echo -e "${YELLOW}Dev server is already running on port $DEV_SERVER_PORT${NC}"
    return 0
  fi

  cd "$PROJECT_ROOT"

  # Start server in background
  nohup pnpm dev > /tmp/ballee-dev-server.log 2>&1 &
  DEV_PID=$!

  echo -e "${GRAY}Started with PID $DEV_PID${NC}"
  echo -e "${GRAY}Waiting for server to be ready...${NC}"

  # Wait for server to be ready (max 60 seconds)
  for i in {1..60}; do
    if check_server; then
      echo -e "${GREEN}Dev server is ready on port $DEV_SERVER_PORT${NC}"
      return 0
    fi
    sleep 1
    echo -n "."
  done

  echo ""
  echo -e "${RED}Timeout waiting for dev server${NC}"
  echo "Check logs at /tmp/ballee-dev-server.log"
  return 1
}

cmd_stop() {
  echo -e "${BLUE}Stopping dev server...${NC}"

  # Find and kill processes on the port
  PIDS=$(lsof -ti:$DEV_SERVER_PORT 2>/dev/null || true)

  if [ -z "$PIDS" ]; then
    echo -e "${YELLOW}No process found on port $DEV_SERVER_PORT${NC}"
    return 0
  fi

  echo "$PIDS" | xargs kill -9 2>/dev/null || true
  echo -e "${GREEN}Dev server stopped${NC}"
}

cmd_list_slides() {
  echo -e "${BLUE}Available demo slide IDs:${NC}"
  echo ""
  for slide in "${DEMO_SLIDES[@]}"; do
    echo "  - $slide"
  done
  echo ""
  echo -e "${GRAY}Usage: ./visual-test.sh demo <slide-id> [--debug]${NC}"
}

cmd_screenshot() {
  local url="$1"

  if [ -z "$url" ]; then
    echo -e "${RED}Error: URL required${NC}"
    echo "Usage: ./visual-test.sh screenshot <url> [options]"
    return 1
  fi

  # Ensure server is running
  if ! check_server; then
    echo -e "${RED}Error: Dev server is not running${NC}"
    echo "Start it with: ./visual-test.sh start"
    return 1
  fi

  ensure_screenshot_dir

  # Add debug param if requested
  if [ "$DEBUG_MODE" = true ]; then
    if [[ "$url" == *"?"* ]]; then
      url="${url}&debug=true"
    else
      url="${url}?debug=true"
    fi
  fi

  # Determine output filename
  local timestamp=$(get_timestamp)
  local output_file
  if [ -n "$CUSTOM_NAME" ]; then
    output_file="$SCREENSHOT_DIR/${CUSTOM_NAME}.png"
  else
    output_file="$SCREENSHOT_DIR/screenshot-${timestamp}.png"
  fi

  echo -e "${BLUE}Taking screenshot...${NC}"
  echo -e "${GRAY}URL: $url${NC}"
  echo -e "${GRAY}Viewport: $VIEWPORT${NC}"
  echo -e "${GRAY}Output: $output_file${NC}"

  # Run the TypeScript screenshot script
  cd "$PROJECT_ROOT"
  pnpm exec tsx "$SCRIPT_DIR/screenshot.ts" \
    --url "$url" \
    --output "$output_file" \
    --viewport "$VIEWPORT" \
    --wait "$WAIT_TIME" \
    $([ "$FULL_PAGE" = true ] && echo "--full-page")

  if [ -f "$output_file" ]; then
    echo ""
    echo -e "${GREEN}Screenshot saved!${NC}"
    echo -e "${CYAN}$output_file${NC}"
  else
    echo -e "${RED}Failed to save screenshot${NC}"
    return 1
  fi
}

cmd_demo() {
  local slide_id="$1"

  # Ensure server is running
  if ! check_server; then
    echo -e "${RED}Error: Dev server is not running${NC}"
    echo "Start it with: ./visual-test.sh start"
    return 1
  fi

  ensure_screenshot_dir

  # Build URL
  local url="$DEV_SERVER_URL$DEMO_BASE_PATH"
  if [ -n "$slide_id" ]; then
    url="${url}?slide=${slide_id}"
  fi

  # Add debug param if requested
  if [ "$DEBUG_MODE" = true ]; then
    if [[ "$url" == *"?"* ]]; then
      url="${url}&debug=true"
    else
      url="${url}?debug=true"
    fi
  fi

  # Determine output filename
  local timestamp=$(get_timestamp)
  local output_file
  if [ -n "$CUSTOM_NAME" ]; then
    output_file="$SCREENSHOT_DIR/${CUSTOM_NAME}.png"
  elif [ -n "$slide_id" ]; then
    output_file="$SCREENSHOT_DIR/demo-${slide_id}-${timestamp}.png"
  else
    output_file="$SCREENSHOT_DIR/demo-showcase-${timestamp}.png"
  fi

  echo -e "${BLUE}Capturing demo screenshot...${NC}"
  echo -e "${GRAY}Slide: ${slide_id:-'(default)'}${NC}"
  echo -e "${GRAY}URL: $url${NC}"
  echo -e "${GRAY}Debug mode: $DEBUG_MODE${NC}"

  # Run the TypeScript screenshot script
  cd "$PROJECT_ROOT"
  pnpm exec tsx "$SCRIPT_DIR/screenshot.ts" \
    --url "$url" \
    --output "$output_file" \
    --viewport "$VIEWPORT" \
    --wait "$WAIT_TIME" \
    $([ "$FULL_PAGE" = true ] && echo "--full-page")

  if [ -f "$output_file" ]; then
    echo ""
    echo -e "${GREEN}Screenshot saved!${NC}"
    echo -e "${CYAN}$output_file${NC}"
  else
    echo -e "${RED}Failed to save screenshot${NC}"
    return 1
  fi
}

cmd_demo_all() {
  echo -e "${BLUE}Capturing all demo slides...${NC}"
  echo ""

  # Ensure server is running
  if ! check_server; then
    echo -e "${RED}Error: Dev server is not running${NC}"
    echo "Start it with: ./visual-test.sh start"
    return 1
  fi

  ensure_screenshot_dir

  local timestamp=$(get_timestamp)
  local success_count=0
  local total=${#DEMO_SLIDES[@]}

  for slide in "${DEMO_SLIDES[@]}"; do
    echo -e "${GRAY}[$((success_count + 1))/$total] Capturing $slide...${NC}"

    # Build URL
    local url="$DEV_SERVER_URL$DEMO_BASE_PATH?slide=${slide}"
    if [ "$DEBUG_MODE" = true ]; then
      url="${url}&debug=true"
    fi

    local output_file="$SCREENSHOT_DIR/demo-${slide}-${timestamp}.png"

    # Run the TypeScript screenshot script
    cd "$PROJECT_ROOT"
    if pnpm exec tsx "$SCRIPT_DIR/screenshot.ts" \
      --url "$url" \
      --output "$output_file" \
      --viewport "$VIEWPORT" \
      --wait "$WAIT_TIME" 2>/dev/null; then
      success_count=$((success_count + 1))
      echo -e "  ${GREEN}Saved: $output_file${NC}"
    else
      echo -e "  ${RED}Failed: $slide${NC}"
    fi
  done

  echo ""
  echo -e "${GREEN}Completed: $success_count/$total screenshots${NC}"
  echo -e "${CYAN}Output directory: $SCREENSHOT_DIR${NC}"
}

# =====================================================================================
# Main
# =====================================================================================

main() {
  local command="${1:-}"
  shift || true

  # Collect positional arguments while parsing options
  local positional_args=()

  # Parse all arguments (options can appear anywhere)
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --debug)
        DEBUG_MODE=true
        shift
        ;;
      --viewport)
        VIEWPORT="$2"
        shift 2
        ;;
      --name)
        CUSTOM_NAME="$2"
        shift 2
        ;;
      --full-page)
        FULL_PAGE=true
        shift
        ;;
      --wait)
        WAIT_TIME="$2"
        shift 2
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      -*)
        echo -e "${RED}Unknown option: $1${NC}"
        exit 1
        ;;
      *)
        # Collect positional arguments
        positional_args+=("$1")
        shift
        ;;
    esac
  done

  # Restore positional arguments
  set -- "${positional_args[@]}"

  case "$command" in
    status)
      cmd_status
      ;;
    start)
      cmd_start
      ;;
    stop)
      cmd_stop
      ;;
    screenshot)
      cmd_screenshot "$@"
      ;;
    demo)
      cmd_demo "$@"
      ;;
    demo-all)
      cmd_demo_all
      ;;
    list-slides)
      cmd_list_slides
      ;;
    ""|help|-h|--help)
      print_usage
      ;;
    *)
      echo -e "${RED}Unknown command: $command${NC}"
      echo ""
      print_usage
      exit 1
      ;;
  esac
}

main "$@"

#!/bin/bash
# =====================================================================================
# Sentry CLI Helper - Comprehensive Sentry API Interface
# =====================================================================================
#
# Unified CLI tool for Sentry error management.
#
# Usage:
#   ./scripts/sentry.sh <command> [options]
#
# Commands:
#   list [--status STATUS] [--since DAYS]  - List issues
#   get <issue-id> [--events]              - Get issue details
#   resolve <issue-id...>                  - Resolve one or more issues
#   unresolve <issue-id...>                - Reopen resolved issues
#   ignore <issue-id...>                   - Ignore/mute issues
#   assign <issue-id> [user-id]            - Assign issue (default: Claude Code 3990106)
#   unassign <issue-id>                    - Unassign issue
#   stats [--weekly]                       - Show statistics
#   search <query>                         - Search issues by keyword
#   comment <issue-id> <text>              - Add comment to issue
#   comments <issue-id>                    - List comments on issue
#   edit-comment <issue-id> <comment-id> <text> - Edit existing comment
#   delete-comment <issue-id> <comment-id> - Delete comment
#
# Examples:
#   ./scripts/sentry.sh list
#   ./scripts/sentry.sh list --status unresolved --since 7
#   ./scripts/sentry.sh get 6966580554
#   ./scripts/sentry.sh get 6966580554 --events
#   ./scripts/sentry.sh resolve 6966580554 6966048323
#   ./scripts/sentry.sh stats
#   ./scripts/sentry.sh search "dancers/slug"
#   ./scripts/sentry.sh comment 7034568465 "🔍 INVESTIGATING - analyzing root cause"
#   ./scripts/sentry.sh comments 7034568465
#   ./scripts/sentry.sh assign 7034568465
#   ./scripts/sentry.sh ignore 7034568465
#
# =====================================================================================

set -e

SENTRY_ORG="${SENTRY_ORG:-ballee}"
SENTRY_PROJECT="${SENTRY_PROJECT:-ballee}"
SENTRY_API_BASE="https://sentry.io/api/0"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Check for auth token
check_auth() {
  if [ -z "$SENTRY_AUTH_TOKEN" ]; then
    # Try to load from .env.local
    if [ -f .env.local ]; then
      export $(grep SENTRY_AUTH_TOKEN .env.local | xargs)
    fi

    if [ -z "$SENTRY_AUTH_TOKEN" ]; then
      echo -e "${RED}Error: SENTRY_AUTH_TOKEN not set${NC}"
      echo ""
      echo "Get your auth token from:"
      echo "  https://sentry.io/settings/account/api/auth-tokens/"
      echo ""
      echo "Then set it:"
      echo "  export SENTRY_AUTH_TOKEN='your-token-here'"
      echo ""
      echo "Or add to .env.local:"
      echo "  echo 'SENTRY_AUTH_TOKEN=your-token' >> .env.local"
      exit 1
    fi
  fi
}

# Make API request
api_request() {
  local method="$1"
  local endpoint="$2"
  local data="$3"

  local url="${SENTRY_API_BASE}${endpoint}"

  if [ "$method" = "GET" ]; then
    curl -s -X GET "$url" \
      -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
      -H "Content-Type: application/json"
  else
    curl -s -X "$method" "$url" \
      -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$data"
  fi
}

# Format timestamp to relative time
relative_time() {
  local timestamp="$1"
  local now=$(date +%s)
  local then=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" +%s 2>/dev/null || echo "$now")
  local diff=$((now - then))
  local days=$((diff / 86400))

  if [ $days -eq 0 ]; then
    echo "today"
  elif [ $days -eq 1 ]; then
    echo "1 day ago"
  else
    echo "$days days ago"
  fi
}

# Command: list
cmd_list() {
  local status="unresolved"
  local query="is:$status"

  # Parse options
  while [[ $# -gt 0 ]]; do
    case $1 in
      --status)
        status="$2"
        query="is:$status"
        shift 2
        ;;
      --since)
        local days="$2"
        local since_date=$(date -v-${days}d +%Y-%m-%d 2>/dev/null || date -d "$days days ago" +%Y-%m-%d)
        query="$query lastSeen:>=$since_date"
        shift 2
        ;;
      *)
        echo -e "${RED}Unknown option: $1${NC}"
        exit 1
        ;;
    esac
  done

  echo -e "${BLUE}Fetching Sentry issues...${NC}"
  echo "Organization: $SENTRY_ORG"
  echo "Project: $SENTRY_PROJECT"
  echo "Query: $query"
  echo ""

  local response=$(api_request GET "/organizations/$SENTRY_ORG/issues/")

  # Parse and display issues
  echo "$response" | jq -r '
    if type == "array" then
      if length == 0 then
        "No issues found."
      else
        "📊 Found \(length) issue(s)\n" +
        "=" * 60 + "\n" +
        (
          .[] |
          "\n\(.priority // "unknown" | ascii_upcase) PRIORITY - Issue #\(.id)\n" +
          "  Title: \(.title)\n" +
          "  Events: \(.count) events, \(.userCount) user(s) affected\n" +
          "  Last seen: \(.lastSeen)\n" +
          "  Route: \(.culprit // "N/A")\n" +
          "  Status: \(.status)\n" +
          "  Link: \(.permalink)\n" +
          "-" * 60
        )
      end
    else
      "Error: \(.detail // "Unknown error")"
    end
  ' 2>/dev/null || echo -e "${RED}Failed to parse response${NC}"
}

# Command: get
cmd_get() {
  local issue_id="$1"
  local show_events=false

  if [ -z "$issue_id" ]; then
    echo -e "${RED}Error: Issue ID required${NC}"
    echo "Usage: $0 get <issue-id> [--events]"
    exit 1
  fi

  shift
  while [[ $# -gt 0 ]]; do
    case $1 in
      --events)
        show_events=true
        shift
        ;;
      *)
        echo -e "${RED}Unknown option: $1${NC}"
        exit 1
        ;;
    esac
  done

  echo -e "${BLUE}Fetching issue #$issue_id...${NC}"
  echo ""

  local response=$(api_request GET "/issues/$issue_id/")

  # Display issue details
  echo "$response" | jq -r '
    if .id then
      "🔍 Issue #\(.id) - \(.shortId)\n" +
      "=" * 60 + "\n" +
      "Title: \(.title)\n" +
      "Status: \(.status) (\(.substatus))\n" +
      "Priority: \(.priority // "unknown")\n" +
      "Type: \(.type)\n" +
      "Platform: \(.platform)\n" +
      "\n" +
      "📊 Statistics:\n" +
      "  Events: \(.count) total, \(.userCount) user(s) affected\n" +
      "  First seen: \(.firstSeen)\n" +
      "  Last seen: \(.lastSeen)\n" +
      "\n" +
      "📍 Location:\n" +
      "  Route: \(.culprit // "N/A")\n" +
      "  File: \(.metadata.filename // "N/A")\n" +
      "  Function: \(.metadata.function // "N/A")\n" +
      "\n" +
      "🔗 Links:\n" +
      "  Permalink: \(.permalink)\n" +
      "\n" +
      "=" * 60
    else
      "Error: \(.detail // "Unknown error")"
    end
  ' 2>/dev/null || echo -e "${RED}Failed to parse response${NC}"

  if [ "$show_events" = true ]; then
    echo ""
    echo -e "${BLUE}Recent events:${NC}"
    local events=$(api_request GET "/issues/$issue_id/events/")
    echo "$events" | jq -r '.[] | "  - \(.dateCreated): \(.message // .title)"' 2>/dev/null || echo "No events found"
  fi
}

# Command: resolve
cmd_resolve() {
  if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage: $0 resolve <issue-id-1> [issue-id-2] ...${NC}"
    exit 1
  fi

  echo "Resolving Sentry issues..."
  echo "Organization: $SENTRY_ORG"
  echo "Project: $SENTRY_PROJECT"
  echo ""

  local resolved_count=0
  local failed_count=0

  for issue_id in "$@"; do
    echo -n "Resolving issue #$issue_id... "

    local response=$(api_request PUT "/issues/$issue_id/" '{"status": "resolved"}' 2>&1)

    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
      echo -e "${GREEN}✅ Resolved${NC}"
      ((resolved_count++))
    else
      echo -e "${RED}❌ Failed${NC}"
      local error=$(echo "$response" | jq -r '.detail // "Unknown error"' 2>/dev/null || echo "$response")
      echo "   Error: $error"
      ((failed_count++))
    fi
  done

  echo ""
  echo "=================================="
  echo "Summary:"
  echo "  Resolved: $resolved_count"
  echo "  Failed:   $failed_count"
  echo "  Total:    $(($resolved_count + $failed_count))"
  echo "=================================="

  if [ $failed_count -gt 0 ]; then
    exit 1
  fi
}

# Command: stats
cmd_stats() {
  local weekly=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --weekly)
        weekly=true
        shift
        ;;
      *)
        echo -e "${RED}Unknown option: $1${NC}"
        exit 1
        ;;
    esac
  done

  echo -e "${BLUE}Fetching Sentry statistics...${NC}"
  echo ""

  local response=$(api_request GET "/organizations/$SENTRY_ORG/issues/")

  # Calculate stats
  echo "$response" | jq -r '
    if type == "array" then
      {
        total: length,
        by_status: (group_by(.status) | map({key: .[0].status, value: length}) | from_entries),
        by_priority: (group_by(.priority) | map({key: (.[0].priority // "unknown"), value: length}) | from_entries),
        total_events: map(.count | tonumber) | add,
        total_users: map(.userCount | tonumber) | add
      } |
      "📊 Sentry Statistics\n" +
      "=" * 60 + "\n" +
      "\n" +
      "Total Issues: \(.total)\n" +
      "Total Events: \(.total_events)\n" +
      "Users Affected: \(.total_users)\n" +
      "\n" +
      "By Status:\n" +
      (.by_status | to_entries | map("  \(.key): \(.value)") | join("\n")) +
      "\n\n" +
      "By Priority:\n" +
      (.by_priority | to_entries | map("  \(.key): \(.value)") | join("\n")) +
      "\n" +
      "=" * 60
    else
      "Error: \(.detail // "Unknown error")"
    end
  ' 2>/dev/null || echo -e "${RED}Failed to parse response${NC}"
}

# Command: search
cmd_search() {
  local query="$1"

  if [ -z "$query" ]; then
    echo -e "${RED}Error: Search query required${NC}"
    echo "Usage: $0 search <query>"
    exit 1
  fi

  echo -e "${BLUE}Searching for: $query${NC}"
  echo ""

  local response=$(api_request GET "/organizations/$SENTRY_ORG/issues/")

  # Search in titles and culprits
  echo "$response" | jq -r --arg query "$query" '
    if type == "array" then
      map(select(.title | test($query; "i") or (.culprit // "" | test($query; "i")))) |
      if length == 0 then
        "No issues found matching: \($query)"
      else
        "🔍 Found \(length) issue(s) matching: \($query)\n" +
        "=" * 60 + "\n" +
        (
          .[] |
          "\nIssue #\(.id)\n" +
          "  Title: \(.title)\n" +
          "  Route: \(.culprit // "N/A")\n" +
          "  Events: \(.count), Last seen: \(.lastSeen)\n" +
          "  Link: \(.permalink)\n" +
          "-" * 60
        )
      end
    else
      "Error: \(.detail // "Unknown error")"
    end
  ' 2>/dev/null || echo -e "${RED}Failed to parse response${NC}"
}

# Command: unresolve
cmd_unresolve() {
  if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage: $0 unresolve <issue-id-1> [issue-id-2] ...${NC}"
    exit 1
  fi

  echo "Reopening Sentry issues..."
  echo ""

  local success_count=0
  local failed_count=0

  for issue_id in "$@"; do
    echo -n "Reopening issue #$issue_id... "

    local response=$(api_request PUT "/issues/$issue_id/" '{"status": "unresolved"}' 2>&1)

    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
      echo -e "${GREEN}✅ Reopened${NC}"
      ((success_count++))
    else
      echo -e "${RED}❌ Failed${NC}"
      local error=$(echo "$response" | jq -r '.detail // "Unknown error"' 2>/dev/null || echo "$response")
      echo "   Error: $error"
      ((failed_count++))
    fi
  done

  echo ""
  echo "Summary: $success_count reopened, $failed_count failed"
}

# Command: ignore
cmd_ignore() {
  if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage: $0 ignore <issue-id-1> [issue-id-2] ...${NC}"
    exit 1
  fi

  echo "Ignoring Sentry issues..."
  echo ""

  local success_count=0
  local failed_count=0

  for issue_id in "$@"; do
    echo -n "Ignoring issue #$issue_id... "

    local response=$(api_request PUT "/issues/$issue_id/" '{"status": "ignored"}' 2>&1)

    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
      echo -e "${GREEN}✅ Ignored${NC}"
      ((success_count++))
    else
      echo -e "${RED}❌ Failed${NC}"
      local error=$(echo "$response" | jq -r '.detail // "Unknown error"' 2>/dev/null || echo "$response")
      echo "   Error: $error"
      ((failed_count++))
    fi
  done

  echo ""
  echo "Summary: $success_count ignored, $failed_count failed"
}

# Command: assign
cmd_assign() {
  local issue_id="$1"
  local user_id="${2:-3990106}"  # Default to Claude Code user ID

  if [ -z "$issue_id" ]; then
    echo -e "${RED}Error: Issue ID required${NC}"
    echo "Usage: $0 assign <issue-id> [user-id]"
    echo ""
    echo "Default user ID: 3990106 (Claude Code / Antoine Schaller)"
    exit 1
  fi

  echo -n "Assigning issue #$issue_id to user $user_id... "

  local response=$(api_request PUT "/organizations/$SENTRY_ORG/issues/$issue_id/" "{\"assignedTo\": \"user:$user_id\"}" 2>&1)

  if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
    local assignee=$(echo "$response" | jq -r '.assignedTo.name // "Unknown"' 2>/dev/null)
    echo -e "${GREEN}✅ Assigned to $assignee${NC}"
  else
    echo -e "${RED}❌ Failed${NC}"
    local error=$(echo "$response" | jq -r '.detail // "Unknown error"' 2>/dev/null || echo "$response")
    echo "   Error: $error"
    exit 1
  fi
}

# Command: unassign
cmd_unassign() {
  local issue_id="$1"

  if [ -z "$issue_id" ]; then
    echo -e "${RED}Error: Issue ID required${NC}"
    echo "Usage: $0 unassign <issue-id>"
    exit 1
  fi

  echo -n "Unassigning issue #$issue_id... "

  local response=$(api_request PUT "/organizations/$SENTRY_ORG/issues/$issue_id/" '{"assignedTo": null}' 2>&1)

  if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Unassigned${NC}"
  else
    echo -e "${RED}❌ Failed${NC}"
    local error=$(echo "$response" | jq -r '.detail // "Unknown error"' 2>/dev/null || echo "$response")
    echo "   Error: $error"
    exit 1
  fi
}

# Command: comment (add)
cmd_comment() {
  local issue_id="$1"
  local text="$2"

  if [ -z "$issue_id" ] || [ -z "$text" ]; then
    echo -e "${RED}Error: Issue ID and comment text required${NC}"
    echo "Usage: $0 comment <issue-id> <text>"
    echo ""
    echo "Examples:"
    echo "  $0 comment 7034568465 '🔍 INVESTIGATING - analyzing root cause'"
    echo "  $0 comment 7034568465 '🔧 FIX DEPLOYED - commit abc123'"
    echo "  $0 comment 7034568465 '✅ RESOLVED - 3+ days zero recurrence'"
    exit 1
  fi

  echo -n "Adding comment to issue #$issue_id... "

  # Escape the text for JSON
  local escaped_text=$(echo "$text" | jq -Rs '.')
  local response=$(api_request POST "/issues/$issue_id/comments/" "{\"text\": $escaped_text}" 2>&1)

  if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
    local comment_id=$(echo "$response" | jq -r '.id')
    echo -e "${GREEN}✅ Comment added (ID: $comment_id)${NC}"
  else
    echo -e "${RED}❌ Failed${NC}"
    local error=$(echo "$response" | jq -r '.detail // "Unknown error"' 2>/dev/null || echo "$response")
    echo "   Error: $error"
    exit 1
  fi
}

# Command: comments (list)
cmd_comments() {
  local issue_id="$1"

  if [ -z "$issue_id" ]; then
    echo -e "${RED}Error: Issue ID required${NC}"
    echo "Usage: $0 comments <issue-id>"
    exit 1
  fi

  echo -e "${BLUE}Fetching comments for issue #$issue_id...${NC}"
  echo ""

  local response=$(api_request GET "/issues/$issue_id/activities/")

  # Filter to show only notes (comments)
  echo "$response" | jq -r '
    if .activity then
      .activity | map(select(.type == "note")) |
      if length == 0 then
        "No comments found."
      else
        "💬 Found \(length) comment(s)\n" +
        "=" * 60 + "\n" +
        (
          .[] |
          "\n📝 Comment ID: \(.id)\n" +
          "   Date: \(.dateCreated)\n" +
          "   Author: \(.user.name // "Unknown")\n" +
          "   Text:\n" +
          (.data.text | split("\n") | map("      " + .) | join("\n")) +
          "\n" +
          "-" * 60
        )
      end
    else
      "Error: \(.detail // "Unknown error")"
    end
  ' 2>/dev/null || echo -e "${RED}Failed to parse response${NC}"
}

# Command: edit-comment
cmd_edit_comment() {
  local issue_id="$1"
  local comment_id="$2"
  local text="$3"

  if [ -z "$issue_id" ] || [ -z "$comment_id" ] || [ -z "$text" ]; then
    echo -e "${RED}Error: Issue ID, comment ID, and new text required${NC}"
    echo "Usage: $0 edit-comment <issue-id> <comment-id> <text>"
    echo ""
    echo "Get comment IDs with: $0 comments <issue-id>"
    exit 1
  fi

  echo -n "Editing comment $comment_id on issue #$issue_id... "

  local escaped_text=$(echo "$text" | jq -Rs '.')
  local response=$(api_request PUT "/issues/$issue_id/comments/$comment_id/" "{\"text\": $escaped_text}" 2>&1)

  if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Comment updated${NC}"
  else
    echo -e "${RED}❌ Failed${NC}"
    local error=$(echo "$response" | jq -r '.detail // "Unknown error"' 2>/dev/null || echo "$response")
    echo "   Error: $error"
    exit 1
  fi
}

# Command: delete-comment
cmd_delete_comment() {
  local issue_id="$1"
  local comment_id="$2"

  if [ -z "$issue_id" ] || [ -z "$comment_id" ]; then
    echo -e "${RED}Error: Issue ID and comment ID required${NC}"
    echo "Usage: $0 delete-comment <issue-id> <comment-id>"
    echo ""
    echo "Get comment IDs with: $0 comments <issue-id>"
    exit 1
  fi

  echo -n "Deleting comment $comment_id from issue #$issue_id... "

  local response=$(curl -s -X DELETE \
    "${SENTRY_API_BASE}/issues/$issue_id/comments/$comment_id/" \
    -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
    -w "%{http_code}" 2>&1)

  # Check if delete was successful (204 No Content or 200 OK)
  if [[ "$response" =~ 20[04]$ ]]; then
    echo -e "${GREEN}✅ Comment deleted${NC}"
  else
    echo -e "${RED}❌ Failed${NC}"
    echo "   Response: $response"
    exit 1
  fi
}

# Main command router
main() {
  if [ $# -eq 0 ]; then
    echo "Sentry CLI Helper"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Issue Viewing:"
    echo "  list [--status STATUS] [--since DAYS]  - List issues"
    echo "  get <issue-id> [--events]              - Get issue details"
    echo "  search <query>                         - Search issues by keyword"
    echo "  stats [--weekly]                       - Show statistics"
    echo ""
    echo "Issue Management:"
    echo "  resolve <issue-id...>                  - Resolve issues"
    echo "  unresolve <issue-id...>                - Reopen resolved issues"
    echo "  ignore <issue-id...>                   - Ignore/mute issues"
    echo "  assign <issue-id> [user-id]            - Assign issue (default: 3990106)"
    echo "  unassign <issue-id>                    - Unassign issue"
    echo ""
    echo "Comments:"
    echo "  comment <issue-id> <text>              - Add comment to issue"
    echo "  comments <issue-id>                    - List comments on issue"
    echo "  edit-comment <issue-id> <cmt-id> <txt> - Edit existing comment"
    echo "  delete-comment <issue-id> <cmt-id>     - Delete comment"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 get 7034568465 --events"
    echo "  $0 resolve 7034568465"
    echo "  $0 comment 7034568465 '🔍 INVESTIGATING - analyzing root cause'"
    echo ""
    exit 0
  fi

  check_auth

  local command="$1"
  shift

  case "$command" in
    list)
      cmd_list "$@"
      ;;
    get)
      cmd_get "$@"
      ;;
    resolve)
      cmd_resolve "$@"
      ;;
    unresolve)
      cmd_unresolve "$@"
      ;;
    ignore)
      cmd_ignore "$@"
      ;;
    assign)
      cmd_assign "$@"
      ;;
    unassign)
      cmd_unassign "$@"
      ;;
    stats)
      cmd_stats "$@"
      ;;
    search)
      cmd_search "$@"
      ;;
    comment)
      cmd_comment "$@"
      ;;
    comments)
      cmd_comments "$@"
      ;;
    edit-comment)
      cmd_edit_comment "$@"
      ;;
    delete-comment)
      cmd_delete_comment "$@"
      ;;
    *)
      echo -e "${RED}Unknown command: $command${NC}"
      echo "Run '$0' without arguments to see usage"
      exit 1
      ;;
  esac
}

main "$@"

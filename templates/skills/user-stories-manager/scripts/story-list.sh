#!/bin/bash
# story-list.sh - List user stories with filtering options
#
# Usage:
#   ./story-list.sh                    # All stories summary
#   ./story-list.sh --status draft     # Filter by status
#   ./story-list.sh --module invoices  # Filter by module
#   ./story-list.sh --priority high    # Filter by priority
#   ./story-list.sh --verbose          # Show full details

set -euo pipefail

# Get the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
STORIES_DIR="$REPO_ROOT/docs/user-stories"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
FILTER_STATUS=""
FILTER_MODULE=""
FILTER_PRIORITY=""
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --status)
            FILTER_STATUS="$2"
            shift 2
            ;;
        --module)
            FILTER_MODULE="$2"
            shift 2
            ;;
        --priority)
            FILTER_PRIORITY="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: story-list.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --status STATUS     Filter by status (draft, in-progress, testing, done)"
            echo "  --module MODULE     Filter by module name"
            echo "  --priority PRIORITY Filter by priority (low, medium, high, critical)"
            echo "  --verbose, -v       Show full details"
            echo "  --help, -h          Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to extract YAML frontmatter value
extract_yaml() {
    local file="$1"
    local key="$2"
    grep -m1 "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | tr -d '"' || echo ""
}

# Function to get status color
status_color() {
    case "$1" in
        done) echo -e "${GREEN}" ;;
        in-progress) echo -e "${YELLOW}" ;;
        testing) echo -e "${CYAN}" ;;
        draft) echo -e "${BLUE}" ;;
        *) echo -e "${NC}" ;;
    esac
}

# Function to get priority indicator
priority_indicator() {
    case "$1" in
        critical) echo "!!!" ;;
        high) echo "!!" ;;
        medium) echo "!" ;;
        low) echo "-" ;;
        *) echo " " ;;
    esac
}

# Count variables
total=0
done_count=0
in_progress_count=0
testing_count=0
draft_count=0

# Header
echo -e "${BOLD}User Stories${NC}"
echo "=============================================="
echo ""

# Find and process all story files
if $VERBOSE; then
    printf "%-8s %-40s %-15s %-12s %-4s\n" "ID" "TITLE" "MODULE" "STATUS" "PRI"
    echo "-------- ---------------------------------------- --------------- ------------ ----"
else
    printf "%-8s %-50s %-12s\n" "ID" "TITLE" "STATUS"
    echo "-------- -------------------------------------------------- ------------"
fi

find "$STORIES_DIR" -name "US-*.md" -type f | sort | while read -r file; do
    # Skip template
    if [[ "$file" == *"story-template.md"* ]] || [[ "$file" == *"US-XXX"* ]]; then
        continue
    fi

    # Extract frontmatter values
    id=$(extract_yaml "$file" "id")
    title=$(extract_yaml "$file" "title")
    module=$(extract_yaml "$file" "module")
    status=$(extract_yaml "$file" "status")
    priority=$(extract_yaml "$file" "priority")

    # Apply filters
    if [[ -n "$FILTER_STATUS" ]] && [[ "$status" != "$FILTER_STATUS" ]]; then
        continue
    fi
    if [[ -n "$FILTER_MODULE" ]] && [[ "$module" != "$FILTER_MODULE" ]]; then
        continue
    fi
    if [[ -n "$FILTER_PRIORITY" ]] && [[ "$priority" != "$FILTER_PRIORITY" ]]; then
        continue
    fi

    # Truncate title if needed
    if [[ ${#title} -gt 48 ]]; then
        title="${title:0:45}..."
    fi

    # Get colors
    color=$(status_color "$status")
    pri=$(priority_indicator "$priority")

    # Print row
    if $VERBOSE; then
        printf "%-8s %-40s %-15s ${color}%-12s${NC} %-4s\n" "$id" "$title" "$module" "$status" "$pri"
    else
        printf "%-8s %-50s ${color}%-12s${NC}\n" "$id" "$title" "$status"
    fi
done

echo ""

# Summary statistics
echo -e "${BOLD}Summary${NC}"
echo "------"

# Count by status using a subshell to capture counts
stats=$(find "$STORIES_DIR" -name "US-*.md" -type f | while read -r file; do
    if [[ "$file" == *"story-template.md"* ]] || [[ "$file" == *"US-XXX"* ]]; then
        continue
    fi
    status=$(extract_yaml "$file" "status")

    # Apply module filter for stats too
    if [[ -n "$FILTER_MODULE" ]]; then
        module=$(extract_yaml "$file" "module")
        if [[ "$module" != "$FILTER_MODULE" ]]; then
            continue
        fi
    fi

    echo "$status"
done | sort | uniq -c)

done_count=$(echo "$stats" | grep "done" | awk '{print $1}' || echo "0")
in_progress_count=$(echo "$stats" | grep "in-progress" | awk '{print $1}' || echo "0")
testing_count=$(echo "$stats" | grep "testing" | awk '{print $1}' || echo "0")
draft_count=$(echo "$stats" | grep "draft" | awk '{print $1}' || echo "0")

# Set defaults if empty
done_count=${done_count:-0}
in_progress_count=${in_progress_count:-0}
testing_count=${testing_count:-0}
draft_count=${draft_count:-0}

total=$((done_count + in_progress_count + testing_count + draft_count))

if [[ $total -gt 0 ]]; then
    completion=$((done_count * 100 / total))
else
    completion=0
fi

echo -e "${GREEN}Done:${NC}        $done_count"
echo -e "${CYAN}Testing:${NC}     $testing_count"
echo -e "${YELLOW}In Progress:${NC} $in_progress_count"
echo -e "${BLUE}Draft:${NC}       $draft_count"
echo "------"
echo -e "Total:       $total"
echo -e "Completion:  ${completion}%"

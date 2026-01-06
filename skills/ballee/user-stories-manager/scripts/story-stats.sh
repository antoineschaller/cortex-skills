#!/bin/bash
# story-stats.sh - Show user story statistics
#
# Usage:
#   ./story-stats.sh                 # Overall stats
#   ./story-stats.sh --by-module     # Breakdown by module
#   ./story-stats.sh --by-status     # Breakdown by status
#   ./story-stats.sh --by-priority   # Breakdown by priority

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
NC='\033[0m'
BOLD='\033[1m'

# Variables
BY_MODULE=false
BY_STATUS=false
BY_PRIORITY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --by-module)
            BY_MODULE=true
            shift
            ;;
        --by-status)
            BY_STATUS=true
            shift
            ;;
        --by-priority)
            BY_PRIORITY=true
            shift
            ;;
        --all)
            BY_MODULE=true
            BY_STATUS=true
            BY_PRIORITY=true
            shift
            ;;
        --help|-h)
            echo "Usage: story-stats.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --by-module     Show breakdown by module"
            echo "  --by-status     Show breakdown by status"
            echo "  --by-priority   Show breakdown by priority"
            echo "  --all           Show all breakdowns"
            echo "  --help, -h      Show this help"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
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

# Collect data using temp files (bash 3.2 compatible)
tmpdir=$(mktemp -d)
trap "rm -rf $tmpdir" EXIT

# Collect all story data
find "$STORIES_DIR" -name "US-*.md" -type f | while read -r file; do
    # Skip template
    if [[ "$file" == *"story-template.md"* ]] || [[ "$file" == *"US-XXX"* ]]; then
        continue
    fi

    status=$(extract_yaml "$file" "status")
    module=$(extract_yaml "$file" "module")
    priority=$(extract_yaml "$file" "priority")

    echo "$status" >> "$tmpdir/statuses.txt"
    echo "$module" >> "$tmpdir/modules.txt"
    echo "$priority" >> "$tmpdir/priorities.txt"
    echo "$module:$status" >> "$tmpdir/module_status.txt"
done

# Count totals
total=$(wc -l < "$tmpdir/statuses.txt" 2>/dev/null | tr -d ' ' || echo "0")

# Header
echo -e "${BOLD}User Story Statistics${NC}"
echo "=============================================="
echo ""

# Overall summary
echo -e "${BOLD}Overview${NC}"
echo "------"
echo -e "Total stories: ${BOLD}$total${NC}"
echo ""

# Calculate completion
done_count=$(grep -c "^done$" "$tmpdir/statuses.txt" 2>/dev/null || echo "0")
if [[ $total -gt 0 ]]; then
    completion=$((done_count * 100 / total))
else
    completion=0
fi

# Progress bar
bar_width=30
filled=$((completion * bar_width / 100))
empty=$((bar_width - filled))
bar=$(printf "%${filled}s" | tr ' ' '#')
bar_empty=$(printf "%${empty}s" | tr ' ' '-')

echo -e "Completion: [${GREEN}${bar}${NC}${bar_empty}] ${completion}%"
echo ""

# Status breakdown
echo -e "${BOLD}By Status${NC}"
echo "------"
printf "%-15s %5s %s\n" "STATUS" "COUNT" "BAR"
for status in done testing in-progress draft; do
    count=$(grep -c "^${status}$" "$tmpdir/statuses.txt" 2>/dev/null || echo "0")
    count=${count//[^0-9]/}  # Remove non-numeric chars
    count=${count:-0}  # Default to 0 if empty
    if [[ $total -gt 0 ]] && [[ $count -gt 0 ]]; then
        pct=$((count * 100 / total))
        bar_len=$((count * 20 / total))
    else
        pct=0
        bar_len=0
    fi
    if [[ $bar_len -gt 0 ]]; then
        bar=$(printf "%${bar_len}s" | tr ' ' '#')
    else
        bar=""
    fi

    case $status in
        done) color=$GREEN ;;
        testing) color=$CYAN ;;
        in-progress) color=$YELLOW ;;
        draft) color=$BLUE ;;
        *) color=$NC ;;
    esac

    printf "${color}%-15s${NC} %5s ${color}%s${NC} (%d%%)\n" "$status" "$count" "$bar" "$pct"
done
echo ""

# Module breakdown
if $BY_MODULE; then
    echo -e "${BOLD}By Module${NC}"
    echo "------"
    printf "%-25s %5s %5s %s\n" "MODULE" "TOTAL" "DONE" "PROGRESS"

    # Get unique modules and count
    sort "$tmpdir/modules.txt" | uniq -c | sort -rn | while read -r count module; do
        done_in_module=$(grep "^${module}:done$" "$tmpdir/module_status.txt" 2>/dev/null | wc -l | tr -d ' ')
        if [[ $count -gt 0 ]]; then
            pct=$((done_in_module * 100 / count))
        else
            pct=0
        fi

        # Mini progress bar
        bar_len=$((pct / 10))
        bar=$(printf "%${bar_len}s" | tr ' ' '#')
        bar_empty=$(printf "%$((10 - bar_len))s" | tr ' ' '-')

        if [[ $pct -eq 100 ]]; then
            color=$GREEN
        elif [[ $pct -ge 50 ]]; then
            color=$YELLOW
        else
            color=$NC
        fi

        printf "%-25s %5s %5s ${color}[%s%s]${NC} %d%%\n" "$module" "$count" "$done_in_module" "$bar" "$bar_empty" "$pct"
    done
    echo ""
fi

# Priority breakdown
if $BY_PRIORITY; then
    echo -e "${BOLD}By Priority${NC}"
    echo "------"
    printf "%-12s %5s %s\n" "PRIORITY" "COUNT" "BAR"
    for priority in critical high medium low; do
        count=$(grep -c "^${priority}$" "$tmpdir/priorities.txt" 2>/dev/null || echo "0")
        count=${count//[^0-9]/}
        count=${count:-0}
        if [[ $total -gt 0 ]] && [[ $count -gt 0 ]]; then
            pct=$((count * 100 / total))
            bar_len=$((count * 20 / total))
        else
            pct=0
            bar_len=0
        fi
        if [[ $bar_len -gt 0 ]]; then
            bar=$(printf "%${bar_len}s" | tr ' ' '#')
        else
            bar=""
        fi

        case $priority in
            critical) color=$RED ;;
            high) color=$YELLOW ;;
            medium) color=$NC ;;
            low) color=$BLUE ;;
        esac

        printf "${color}%-12s${NC} %5s ${color}%s${NC} (%d%%)\n" "$priority" "$count" "$bar" "$pct"
    done
    echo ""
fi

# Recent activity
echo -e "${BOLD}Recent Updates${NC}"
echo "------"
echo "Stories updated in last 7 days:"

week_ago=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d 2>/dev/null || echo "")

if [[ -n "$week_ago" ]]; then
    recent=0
    while IFS= read -r file; do
        if [[ "$file" == *"story-template.md"* ]] || [[ "$file" == *"US-XXX"* ]]; then
            continue
        fi
        updated=$(extract_yaml "$file" "updated_at")
        if [[ "$updated" > "$week_ago" ]] || [[ "$updated" == "$week_ago" ]]; then
            id=$(extract_yaml "$file" "id")
            title=$(extract_yaml "$file" "title")
            status=$(extract_yaml "$file" "status")
            echo -e "  ${CYAN}$id${NC}: $title (${status})"
            recent=$((recent + 1))
        fi
    done < <(find "$STORIES_DIR" -name "US-*.md" -type f)

    if [[ $recent -eq 0 ]]; then
        echo -e "  ${YELLOW}No recent updates${NC}"
    fi
else
    echo -e "  ${YELLOW}Could not determine date range${NC}"
fi

echo ""
echo "=============================================="

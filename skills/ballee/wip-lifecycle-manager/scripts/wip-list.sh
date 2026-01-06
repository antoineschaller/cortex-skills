#!/bin/bash
# List all active WIPs with their status
# Usage: ./wip-list.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
WIP_DIR="$PROJECT_ROOT/docs/wip/active"

if [ ! -d "$WIP_DIR" ]; then
    echo "No active WIP directory found at $WIP_DIR"
    exit 1
fi

echo "📋 Active WIPs"
echo "=============="
echo ""

count=0
for file in "$WIP_DIR"/WIP_*.md; do
    [ -e "$file" ] || continue
    count=$((count + 1))

    filename=$(basename "$file")

    # Extract status from file
    status=$(grep -m1 "^\*\*Status\*\*:" "$file" 2>/dev/null | sed 's/.*: //' || echo "Unknown")

    # Extract priority
    priority=$(grep -m1 "^\*\*Priority\*\*:" "$file" 2>/dev/null | sed 's/.*: //' || echo "-")

    # Extract last updated
    updated=$(grep -m1 "^\*\*Last Updated\*\*:" "$file" 2>/dev/null | sed 's/.*: //' || echo "-")

    # Count completed vs total tasks (ensure numeric value only)
    total_tasks=$(grep -c "^\- \[" "$file" 2>/dev/null | tr -d '\n' || echo "0")
    done_tasks=$(grep -c "^\- \[x\]" "$file" 2>/dev/null | tr -d '\n' || echo "0")
    [ -z "$total_tasks" ] && total_tasks=0
    [ -z "$done_tasks" ] && done_tasks=0

    # Determine status emoji
    case "$status" in
        *"Complete"*) emoji="✅" ;;
        *"In Progress"*|*"Active"*) emoji="🔄" ;;
        *"On Hold"*|*"Draft"*) emoji="⏸️" ;;
        *"Blocked"*) emoji="🚫" ;;
        *"Planned"*|*"Planning"*) emoji="📝" ;;
        *) emoji="❓" ;;
    esac

    echo "$emoji $filename"
    echo "   Status: $status | Priority: $priority"
    echo "   Tasks: $done_tasks/$total_tasks | Updated: $updated"
    echo ""
done

if [ $count -eq 0 ]; then
    echo "No active WIPs found."
else
    echo "------------"
    echo "Total: $count active WIPs"
fi

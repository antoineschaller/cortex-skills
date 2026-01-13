#!/bin/bash
# Review all WIPs and identify which ones can be archived
# Usage: ./wip-review.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
WIP_DIR="$PROJECT_ROOT/docs/wip/active"

if [ ! -d "$WIP_DIR" ]; then
    echo "No active WIP directory found at $WIP_DIR"
    exit 1
fi

echo "🔍 WIP Review Report"
echo "===================="
echo ""

ready_to_archive=()
in_progress=()
on_hold=()
needs_attention=()

for file in "$WIP_DIR"/WIP_*.md; do
    [ -e "$file" ] || continue

    filename=$(basename "$file")

    # Extract status
    status=$(grep -m1 "^\*\*Status\*\*:" "$file" 2>/dev/null | sed 's/.*: //' || echo "Unknown")

    # Count tasks (ensure numeric value only)
    total_tasks=$(grep -c "^\- \[" "$file" 2>/dev/null | tr -d '\n' || echo "0")
    done_tasks=$(grep -c "^\- \[x\]" "$file" 2>/dev/null | tr -d '\n' || echo "0")
    [ -z "$total_tasks" ] && total_tasks=0
    [ -z "$done_tasks" ] && done_tasks=0
    pending_tasks=$((total_tasks - done_tasks))

    # Count phases (ensure numeric value only)
    total_phases=$(grep -c "| Phase" "$file" 2>/dev/null | tr -d '\n' || echo "0")
    [ -z "$total_phases" ] && total_phases=0
    # Subtract header row
    [ "$total_phases" -gt 0 ] && total_phases=$((total_phases - 1))
    done_phases=$(grep -c "| ✅\|| Complete" "$file" 2>/dev/null | tr -d '\n' || echo "0")
    [ -z "$done_phases" ] && done_phases=0

    # Determine if ready to archive
    is_complete=false

    # Check explicit complete status
    if [[ "$status" == *"Complete"* ]]; then
        is_complete=true
    fi

    # Check if all tasks done (and has tasks)
    if [ "$total_tasks" -gt 0 ] && [ "$pending_tasks" -eq 0 ]; then
        is_complete=true
    fi

    # Categorize
    if [ "$is_complete" = true ]; then
        ready_to_archive+=("$filename")
    elif [[ "$status" == *"Hold"* ]] || [[ "$status" == *"Draft"* ]]; then
        on_hold+=("$filename")
    elif [[ "$status" == *"Progress"* ]] || [[ "$status" == *"Active"* ]]; then
        in_progress+=("$filename")
    else
        needs_attention+=("$filename")
    fi
done

# Print results
if [ ${#ready_to_archive[@]} -gt 0 ]; then
    echo "✅ READY TO ARCHIVE (${#ready_to_archive[@]})"
    echo "   These WIPs appear complete and can be archived:"
    for f in "${ready_to_archive[@]}"; do
        echo "   - $f"
    done
    echo ""
    echo "   Run: ./wip-archive.sh ${ready_to_archive[*]}"
    echo ""
fi

if [ ${#in_progress[@]} -gt 0 ]; then
    echo "🔄 IN PROGRESS (${#in_progress[@]})"
    for f in "${in_progress[@]}"; do
        echo "   - $f"
    done
    echo ""
fi

if [ ${#on_hold[@]} -gt 0 ]; then
    echo "⏸️  ON HOLD (${#on_hold[@]})"
    for f in "${on_hold[@]}"; do
        echo "   - $f"
    done
    echo ""
fi

if [ ${#needs_attention[@]} -gt 0 ]; then
    echo "❓ NEEDS ATTENTION (${#needs_attention[@]})"
    echo "   These WIPs have unclear status:"
    for f in "${needs_attention[@]}"; do
        echo "   - $f"
    done
    echo ""
fi

total=$((${#ready_to_archive[@]} + ${#in_progress[@]} + ${#on_hold[@]} + ${#needs_attention[@]}))
echo "===================="
echo "Total: $total active WIPs"

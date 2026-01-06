#!/bin/bash
# Archive completed WIP files to docs/wip/archive/YYYY-MM/
# Usage: ./wip-archive.sh WIP_file1.md WIP_file2.md ...

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
WIP_DIR="$PROJECT_ROOT/docs/wip/active"
ARCHIVE_BASE="$PROJECT_ROOT/docs/wip/archive"

if [ $# -eq 0 ]; then
    echo "Usage: ./wip-archive.sh <WIP_file1.md> [WIP_file2.md] ..."
    echo ""
    echo "Example: ./wip-archive.sh WIP_feature_2025_12_20.md"
    echo ""
    echo "Run ./wip-review.sh to see which WIPs are ready to archive."
    exit 1
fi

# Get current month for archive folder
ARCHIVE_MONTH=$(date +%Y-%m)
ARCHIVE_DIR="$ARCHIVE_BASE/$ARCHIVE_MONTH"

# Create archive directory if needed
mkdir -p "$ARCHIVE_DIR"

archived=0
failed=0

for filename in "$@"; do
    # Handle both full path and just filename
    if [[ "$filename" == *"/"* ]]; then
        source_file="$filename"
        filename=$(basename "$filename")
    else
        source_file="$WIP_DIR/$filename"
    fi

    if [ ! -f "$source_file" ]; then
        echo "❌ Not found: $filename"
        failed=$((failed + 1))
        continue
    fi

    dest_file="$ARCHIVE_DIR/$filename"

    # Check if already archived
    if [ -f "$dest_file" ]; then
        echo "⚠️  Already in archive: $filename (removing from active)"
        rm "$source_file"
        archived=$((archived + 1))
        continue
    fi

    # Move to archive
    mv "$source_file" "$dest_file"
    echo "✅ Archived: $filename → archive/$ARCHIVE_MONTH/"
    archived=$((archived + 1))
done

echo ""
echo "===================="
echo "Archived: $archived | Failed: $failed"

if [ $archived -gt 0 ]; then
    echo ""
    echo "Don't forget to update docs/wip/README.md if needed."
fi

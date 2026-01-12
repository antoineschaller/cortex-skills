#!/usr/bin/env bash
# Generic WIP (Work In Progress) document validation
#
# Validates WIP documents have proper structure and lifecycle management.
# Can be used in any project that follows WIP documentation patterns.
#
# Usage:
#   ./validate-wip.sh [file1.md file2.md ...]
#   ./validate-wip.sh  # Validates all WIP files in docs/wip/active/
#
# Checks:
# 1. Required sections (Last Updated, Target Completion, Objective, Progress Tracker)
# 2. Completion status (completed WIPs should be in completed/ folder)
# 3. Staleness (warns if >7 days since last update)

set -e

# Configuration (can be overridden via environment variables)
PROJECT_ROOT="${PROJECT_ROOT:-.}"
WIP_ACTIVE_DIR="${WIP_ACTIVE_DIR:-docs/wip/active}"
WIP_COMPLETED_DIR="${WIP_COMPLETED_DIR:-docs/wip/completed}"
STALENESS_DAYS="${STALENESS_DAYS:-7}"

# Get staged WIP files or check all active WIPs
if [ -n "$1" ]; then
  WIP_FILES="$@"
else
  WIP_FILES=$(find "$PROJECT_ROOT/$WIP_ACTIVE_DIR" -name "WIP_*.md" 2>/dev/null || true)
fi

if [ -z "$WIP_FILES" ]; then
  echo "ℹ️  No WIP files to validate"
  exit 0
fi

ERRORS=0
WARNINGS=0

for file in $WIP_FILES; do
  if [ ! -f "$file" ]; then
    continue
  fi

  filename=$(basename "$file")

  # 1. Check required sections
  MISSING_SECTIONS=""

  if ! grep -q "^\*\*Last Updated\*\*:" "$file"; then
    MISSING_SECTIONS="$MISSING_SECTIONS **Last Updated**:"
  fi

  if ! grep -q "^\*\*Target Completion\*\*:" "$file"; then
    MISSING_SECTIONS="$MISSING_SECTIONS **Target Completion**:"
  fi

  if ! grep -q "^## 🎯 Objective" "$file" && ! grep -q "^## Objective" "$file"; then
    MISSING_SECTIONS="$MISSING_SECTIONS '## Objective'"
  fi

  if ! grep -q "^## 📋 Progress Tracker" "$file" && ! grep -q "^## Progress Tracker" "$file"; then
    MISSING_SECTIONS="$MISSING_SECTIONS '## Progress Tracker'"
  fi

  if [ -n "$MISSING_SECTIONS" ]; then
    echo "❌ $filename: Missing required sections:$MISSING_SECTIONS"
    ERRORS=$((ERRORS + 1))
  fi

  # 2. Check if WIP is marked as complete (should be in completed/ folder)
  STATUS=$(grep '^\*\*Status\*\*:' "$file" 2>/dev/null | sed 's/\*\*Status\*\*:[[:space:]]*//' || echo "")
  if echo "$STATUS" | grep -qiE "(✅|complete|completed|done)"; then
    echo "❌ $filename: Marked as complete but still in active/ folder"
    echo "   Move to $WIP_COMPLETED_DIR/ with: mv $file $PROJECT_ROOT/$WIP_COMPLETED_DIR/"
    ERRORS=$((ERRORS + 1))
  fi

  # 3. Check staleness (>N days since last update)
  # Use sed instead of grep -oP for BSD/macOS compatibility
  LAST_UPDATED=$(grep '^\*\*Last Updated\*\*:' "$file" 2>/dev/null | sed 's/\*\*Last Updated\*\*:[[:space:]]*\([0-9-]*\).*/\1/' || echo "")
  if [ -n "$LAST_UPDATED" ]; then
    # Try macOS date format first, then Linux
    LAST_UPDATED_TS=$(date -j -f "%Y-%m-%d" "$LAST_UPDATED" "+%s" 2>/dev/null || date -d "$LAST_UPDATED" "+%s" 2>/dev/null || echo "0")
    NOW_TS=$(date "+%s")
    DAYS_OLD=$(( (NOW_TS - LAST_UPDATED_TS) / 86400 ))

    if [ "$DAYS_OLD" -gt "$STALENESS_DAYS" ]; then
      echo "⚠️  $filename: Stale (last updated $DAYS_OLD days ago, threshold: $STALENESS_DAYS days)"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
done

# Summary
if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "❌ WIP validation failed with $ERRORS error(s)"
  exit 1
fi

if [ $WARNINGS -gt 0 ]; then
  echo ""
  echo "⚠️  WIP validation passed with $WARNINGS warning(s)"
fi

echo "✅ WIP validation complete"
exit 0

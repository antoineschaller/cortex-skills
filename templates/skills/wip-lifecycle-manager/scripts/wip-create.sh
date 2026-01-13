#!/bin/bash
# Create a new WIP document from template
# Usage: ./wip-create.sh "implementing_new_feature"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
WIP_DIR="$PROJECT_ROOT/docs/wip/active"

if [ $# -eq 0 ]; then
    echo "Usage: ./wip-create.sh <description_in_gerund_form>"
    echo ""
    echo "Examples:"
    echo "  ./wip-create.sh implementing_user_auth"
    echo "  ./wip-create.sh fixing_rls_policies"
    echo "  ./wip-create.sh building_mobile_app"
    echo ""
    echo "The description should:"
    echo "  - Start with a gerund (verb ending in -ing)"
    echo "  - Use underscores between words"
    echo "  - Be descriptive but concise"
    exit 1
fi

description="$1"
date=$(date +%Y_%m_%d)
today=$(date +%Y-%m-%d)
filename="WIP_${description}_${date}.md"
filepath="$WIP_DIR/$filename"

# Check if already exists
if [ -f "$filepath" ]; then
    echo "❌ WIP already exists: $filename"
    echo "   Edit the existing file or choose a different name."
    exit 1
fi

# Convert description to title case for display
title=$(echo "$description" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

# Create the WIP file
cat > "$filepath" << EOF
# WIP: $title

**Created**: $today
**Last Updated**: $today
**Status**: In Progress
**Priority**: P2 (Medium)
**Target Completion**: TBD

## 🎯 Objective

Describe what we're building and why.

## 📋 Progress Tracker

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1: Research | ⬜ Pending | Understand requirements |
| Phase 2: Implementation | ⬜ Pending | Build the feature |
| Phase 3: Testing | ⬜ Pending | Verify it works |
| Phase 4: Documentation | ⬜ Pending | Update docs |

## Phase 1: Research

- [ ] Understand current state
- [ ] Identify files to modify
- [ ] Document approach

## Phase 2: Implementation

- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

## Phase 3: Testing

- [ ] Manual testing
- [ ] Automated tests

## Files Modified

| File | Change |
|------|--------|
| TBD | TBD |

## Decisions & Notes

-

## Completion Criteria

- [ ] All phases complete
- [ ] Tests passing
- [ ] Reviewed by team (if needed)
EOF

echo "✅ Created: $filename"
echo "   Path: $filepath"
echo ""
echo "Next steps:"
echo "  1. Edit the file to add your specific tasks"
echo "  2. Update the objective and phases"
echo "  3. Start working!"

#!/bin/bash
# story-update.sh - Update user story fields
#
# Usage:
#   ./story-update.sh US-001 --status in-progress
#   ./story-update.sh US-001 --priority high
#   ./story-update.sh US-001 --assigned-to "dev@example.com"

set -euo pipefail

# Get the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
STORIES_DIR="$REPO_ROOT/docs/user-stories"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
BOLD='\033[1m'

# Variables
STORY_ID=""
NEW_STATUS=""
NEW_PRIORITY=""
NEW_ASSIGNED=""
NEW_BLOCKERS=""
NEW_NOTES=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --status)
            NEW_STATUS="$2"
            shift 2
            ;;
        --priority)
            NEW_PRIORITY="$2"
            shift 2
            ;;
        --assigned-to)
            NEW_ASSIGNED="$2"
            shift 2
            ;;
        --blockers)
            NEW_BLOCKERS="$2"
            shift 2
            ;;
        --notes)
            NEW_NOTES="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: story-update.sh STORY_ID [OPTIONS]"
            echo ""
            echo "Arguments:"
            echo "  STORY_ID            Story ID (e.g., US-001)"
            echo ""
            echo "Options:"
            echo "  --status STATUS     Update status (draft, in-progress, testing, done)"
            echo "  --priority PRIORITY Update priority (low, medium, high, critical)"
            echo "  --assigned-to EMAIL Update assignee"
            echo "  --blockers TEXT     Update blockers"
            echo "  --notes TEXT        Update notes"
            echo "  --help, -h          Show this help"
            exit 0
            ;;
        US-*)
            STORY_ID="$1"
            shift
            ;;
        -*)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            exit 1
            ;;
        *)
            if [[ -z "$STORY_ID" ]]; then
                STORY_ID="$1"
            else
                echo -e "${RED}Error: Unexpected argument: $1${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate story ID
if [[ -z "$STORY_ID" ]]; then
    echo -e "${RED}Error: Story ID is required${NC}"
    echo "Usage: story-update.sh STORY_ID --status STATUS"
    exit 1
fi

# Validate status if provided
if [[ -n "$NEW_STATUS" ]]; then
    case "$NEW_STATUS" in
        draft|in-progress|testing|done) ;;
        *)
            echo -e "${RED}Error: Invalid status: $NEW_STATUS${NC}"
            echo "Valid statuses: draft, in-progress, testing, done"
            exit 1
            ;;
    esac
fi

# Validate priority if provided
if [[ -n "$NEW_PRIORITY" ]]; then
    case "$NEW_PRIORITY" in
        low|medium|high|critical) ;;
        *)
            echo -e "${RED}Error: Invalid priority: $NEW_PRIORITY${NC}"
            echo "Valid priorities: low, medium, high, critical"
            exit 1
            ;;
    esac
fi

# Find the story file
STORY_FILE=""
while IFS= read -r file; do
    if grep -q "^id: $STORY_ID" "$file" 2>/dev/null; then
        STORY_FILE="$file"
        break
    fi
done < <(find "$STORIES_DIR" -name "US-*.md" -type f)

if [[ -z "$STORY_FILE" ]]; then
    echo -e "${RED}Error: Story not found: $STORY_ID${NC}"
    exit 1
fi

echo -e "${BOLD}Updating story: $STORY_ID${NC}"
echo -e "  File: $STORY_FILE"
echo ""

# Get today's date
today=$(date +%Y-%m-%d)

# Track changes
changes_made=false

# Update status
if [[ -n "$NEW_STATUS" ]]; then
    old_status=$(grep -m1 "^status:" "$STORY_FILE" | sed 's/status:[[:space:]]*//')
    sed -i.bak "s/^status:.*/status: $NEW_STATUS/" "$STORY_FILE"
    echo -e "  Status: ${YELLOW}$old_status${NC} → ${GREEN}$NEW_STATUS${NC}"
    changes_made=true

    # If marking as done, set completed_at
    if [[ "$NEW_STATUS" == "done" ]]; then
        if grep -q "^completed_at:" "$STORY_FILE"; then
            sed -i.bak "s/^completed_at:.*/completed_at: $today/" "$STORY_FILE"
        else
            # Add completed_at after updated_at
            sed -i.bak "/^updated_at:/a completed_at: $today" "$STORY_FILE"
        fi
        echo -e "  Completed: ${GREEN}$today${NC}"
    fi
fi

# Update priority
if [[ -n "$NEW_PRIORITY" ]]; then
    old_priority=$(grep -m1 "^priority:" "$STORY_FILE" | sed 's/priority:[[:space:]]*//')
    sed -i.bak "s/^priority:.*/priority: $NEW_PRIORITY/" "$STORY_FILE"
    echo -e "  Priority: ${YELLOW}$old_priority${NC} → ${GREEN}$NEW_PRIORITY${NC}"
    changes_made=true
fi

# Update assigned_to
if [[ -n "$NEW_ASSIGNED" ]]; then
    if grep -q "^assigned_to:" "$STORY_FILE"; then
        sed -i.bak "s/^assigned_to:.*/assigned_to: $NEW_ASSIGNED/" "$STORY_FILE"
    else
        sed -i.bak "/^priority:/a assigned_to: $NEW_ASSIGNED" "$STORY_FILE"
    fi
    echo -e "  Assigned: ${GREEN}$NEW_ASSIGNED${NC}"
    changes_made=true
fi

# Update blockers
if [[ -n "$NEW_BLOCKERS" ]]; then
    if grep -q "^blockers:" "$STORY_FILE"; then
        sed -i.bak "s/^blockers:.*/blockers: \"$NEW_BLOCKERS\"/" "$STORY_FILE"
    else
        sed -i.bak "/^notes:/i blockers: \"$NEW_BLOCKERS\"" "$STORY_FILE"
    fi
    echo -e "  Blockers: ${YELLOW}$NEW_BLOCKERS${NC}"
    changes_made=true
fi

# Update notes
if [[ -n "$NEW_NOTES" ]]; then
    if grep -q "^notes:" "$STORY_FILE"; then
        sed -i.bak "s/^notes:.*/notes: \"$NEW_NOTES\"/" "$STORY_FILE"
    fi
    echo -e "  Notes: $NEW_NOTES"
    changes_made=true
fi

# Update updated_at timestamp
if $changes_made; then
    sed -i.bak "s/^updated_at:.*/updated_at: $today/" "$STORY_FILE"
    echo ""
    echo -e "  Updated: ${GREEN}$today${NC}"
fi

# Clean up backup files
rm -f "${STORY_FILE}.bak"

if $changes_made; then
    echo ""
    echo -e "${GREEN}Story updated successfully!${NC}"
else
    echo -e "${YELLOW}No changes specified${NC}"
    echo "Use --status, --priority, --assigned-to, --blockers, or --notes to update fields"
fi

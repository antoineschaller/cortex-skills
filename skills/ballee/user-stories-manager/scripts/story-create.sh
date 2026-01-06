#!/bin/bash
# story-create.sh - Create a new user story from template
#
# Usage:
#   ./story-create.sh "feature-name" --module admin-events
#   ./story-create.sh "feature-name" --module invoices --priority high

set -euo pipefail

# Get the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
STORIES_DIR="$REPO_ROOT/docs/user-stories"
TEMPLATE_FILE="$STORIES_DIR/story-template.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
BOLD='\033[1m'

# Default values
FEATURE_NAME=""
MODULE=""
PRIORITY="medium"
STATUS="draft"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --module)
            MODULE="$2"
            shift 2
            ;;
        --priority)
            PRIORITY="$2"
            shift 2
            ;;
        --status)
            STATUS="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: story-create.sh FEATURE_NAME --module MODULE [OPTIONS]"
            echo ""
            echo "Arguments:"
            echo "  FEATURE_NAME        Name of the feature (will be converted to slug)"
            echo ""
            echo "Options:"
            echo "  --module MODULE     Module name (required)"
            echo "  --priority PRIORITY Priority level (default: medium)"
            echo "  --status STATUS     Initial status (default: draft)"
            echo "  --help, -h          Show this help"
            echo ""
            echo "Available modules:"
            echo "  authentication, cast-management, communications, admin-events,"
            echo "  dancer-experience, admin-productions, admin-cast-assignment,"
            echo "  admin-reporting, invoices, hire-orders, clients, ai-chatbot,"
            echo "  venues, reimbursements, legal-compliance, airtable-sync,"
            echo "  payments, repertoire"
            exit 0
            ;;
        -*)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            exit 1
            ;;
        *)
            if [[ -z "$FEATURE_NAME" ]]; then
                FEATURE_NAME="$1"
            else
                echo -e "${RED}Error: Unexpected argument: $1${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$FEATURE_NAME" ]]; then
    echo -e "${RED}Error: Feature name is required${NC}"
    echo "Usage: story-create.sh FEATURE_NAME --module MODULE"
    exit 1
fi

if [[ -z "$MODULE" ]]; then
    echo -e "${RED}Error: Module is required (use --module)${NC}"
    echo "Usage: story-create.sh FEATURE_NAME --module MODULE"
    exit 1
fi

# Check template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo -e "${RED}Error: Template file not found: $TEMPLATE_FILE${NC}"
    exit 1
fi

# Find the next available ID
echo -e "${BOLD}Finding next available ID...${NC}"
max_id=0
while IFS= read -r file; do
    if [[ "$file" == *"US-XXX"* ]] || [[ "$file" == *"story-template"* ]]; then
        continue
    fi
    # Extract number from filename
    num=$(basename "$file" | sed 's/US-0*//' | sed 's/-.*//')
    if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -gt $max_id ]]; then
        max_id=$num
    fi
done < <(find "$STORIES_DIR" -name "US-*.md" -type f)

next_id=$((max_id + 1))
padded_id=$(printf "%03d" $next_id)
story_id="US-$padded_id"

echo -e "  Next ID: ${GREEN}$story_id${NC}"

# Convert feature name to slug
slug=$(echo "$FEATURE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')

# Convert feature name to title case
title=$(echo "$FEATURE_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

# Create module directory if it doesn't exist
MODULE_DIR="$STORIES_DIR/$MODULE"
if [[ ! -d "$MODULE_DIR" ]]; then
    echo -e "${YELLOW}Creating module directory: $MODULE${NC}"
    mkdir -p "$MODULE_DIR"
fi

# Generate filename
filename="$story_id-$slug.md"
filepath="$MODULE_DIR/$filename"

# Check if file already exists
if [[ -f "$filepath" ]]; then
    echo -e "${RED}Error: File already exists: $filepath${NC}"
    exit 1
fi

# Get today's date
today=$(date +%Y-%m-%d)

# Create story from template
echo -e "${BOLD}Creating story...${NC}"

# Read template and replace placeholders
sed -e "s/US-XXX/$story_id/g" \
    -e "s/Story Title Here/$title/g" \
    -e "s/module-name/$MODULE/g" \
    -e "s/status: draft/status: $STATUS/g" \
    -e "s/priority: medium/priority: $PRIORITY/g" \
    -e "s/created_at: 2025-11-19/created_at: $today/g" \
    -e "s/updated_at: 2025-11-19/updated_at: $today/g" \
    "$TEMPLATE_FILE" > "$filepath"

echo ""
echo -e "${GREEN}Story created successfully!${NC}"
echo ""
echo -e "  ID:       ${BOLD}$story_id${NC}"
echo -e "  Title:    $title"
echo -e "  Module:   $MODULE"
echo -e "  Priority: $PRIORITY"
echo -e "  Status:   $STATUS"
echo -e "  File:     $filepath"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Edit the story file to add acceptance criteria"
echo "  2. Update the User Story Statement section"
echo "  3. Add technical implementation details as you build"
echo "  4. Link migrations and tests as they're created"

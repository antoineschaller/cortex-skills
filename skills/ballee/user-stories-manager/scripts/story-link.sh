#!/bin/bash
# story-link.sh - Link migrations, tests, and tables to a user story
#
# Usage:
#   ./story-link.sh US-001 --migration 20251224_add_feature
#   ./story-link.sh US-001 --test apps/web/__tests__/e2e/feature/test.ts
#   ./story-link.sh US-001 --table users

set -euo pipefail

# Get the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
STORIES_DIR="$REPO_ROOT/docs/user-stories"
MIGRATIONS_DIR="$REPO_ROOT/apps/web/supabase/migrations"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
BOLD='\033[1m'

# Variables
STORY_ID=""
MIGRATIONS=()
TESTS=()
TABLES=()
DEPENDENCIES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --migration)
            MIGRATIONS+=("$2")
            shift 2
            ;;
        --test)
            TESTS+=("$2")
            shift 2
            ;;
        --table)
            TABLES+=("$2")
            shift 2
            ;;
        --dependency)
            DEPENDENCIES+=("$2")
            shift 2
            ;;
        --help|-h)
            echo "Usage: story-link.sh STORY_ID [OPTIONS]"
            echo ""
            echo "Arguments:"
            echo "  STORY_ID              Story ID (e.g., US-001)"
            echo ""
            echo "Options:"
            echo "  --migration ID        Link a migration ID (can be used multiple times)"
            echo "  --test PATH           Link a test file path (can be used multiple times)"
            echo "  --table NAME          Link a database table (can be used multiple times)"
            echo "  --dependency STORY_ID Link a dependency story (can be used multiple times)"
            echo "  --help, -h            Show this help"
            echo ""
            echo "Examples:"
            echo "  story-link.sh US-001 --migration 20251224_add_feature"
            echo "  story-link.sh US-001 --test apps/web/__tests__/e2e/auth/test.ts"
            echo "  story-link.sh US-001 --table users --table profiles"
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
    echo "Usage: story-link.sh STORY_ID --migration ID"
    exit 1
fi

# Check if any links provided
if [[ ${#MIGRATIONS[@]} -eq 0 ]] && [[ ${#TESTS[@]} -eq 0 ]] && [[ ${#TABLES[@]} -eq 0 ]] && [[ ${#DEPENDENCIES[@]} -eq 0 ]]; then
    echo -e "${RED}Error: At least one link is required${NC}"
    echo "Use --migration, --test, --table, or --dependency"
    exit 1
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

echo -e "${BOLD}Linking resources to story: $STORY_ID${NC}"
echo -e "  File: $STORY_FILE"
echo ""

# Function to add item to YAML array
add_to_array() {
    local file="$1"
    local array_name="$2"
    local value="$3"

    # Check if array is empty (has [])
    if grep -q "^${array_name}: \[\]" "$file"; then
        # Replace empty array with single item
        sed -i.bak "s/^${array_name}: \[\]/${array_name}:\n  - \"$value\"/" "$file"
    elif grep -q "^${array_name}:" "$file"; then
        # Check if value already exists
        if grep -A 50 "^${array_name}:" "$file" | grep -q "\"$value\""; then
            echo -e "  ${YELLOW}Already linked:${NC} $value"
            return 1
        fi
        # Add to existing array - find the line and add after it
        # Find line number of array start
        line_num=$(grep -n "^${array_name}:" "$file" | head -1 | cut -d: -f1)
        # Insert new item after that line
        sed -i.bak "${line_num}a\\  - \"$value\"" "$file"
    else
        echo -e "  ${RED}Array not found:${NC} $array_name"
        return 1
    fi
    return 0
}

changes_made=false

# Link migrations
for migration in "${MIGRATIONS[@]}"; do
    # Validate migration exists
    migration_file=$(find "$MIGRATIONS_DIR" -name "${migration}*.sql" -type f | head -1)
    if [[ -z "$migration_file" ]]; then
        echo -e "  ${YELLOW}Warning: Migration file not found for: $migration${NC}"
        echo -e "  ${YELLOW}Linking anyway...${NC}"
    else
        echo -e "  ${GREEN}Found migration:${NC} $(basename "$migration_file")"
    fi

    if add_to_array "$STORY_FILE" "migration_ids" "$migration"; then
        echo -e "  ${GREEN}Linked migration:${NC} $migration"
        changes_made=true
    fi
done

# Link tests
for test in "${TESTS[@]}"; do
    # Validate test file exists
    test_file="$REPO_ROOT/$test"
    if [[ ! -f "$test_file" ]]; then
        echo -e "  ${YELLOW}Warning: Test file not found: $test${NC}"
        echo -e "  ${YELLOW}Linking anyway...${NC}"
    else
        echo -e "  ${GREEN}Found test:${NC} $test"
    fi

    if add_to_array "$STORY_FILE" "test_files" "$test"; then
        echo -e "  ${GREEN}Linked test:${NC} $test"
        changes_made=true
    fi
done

# Link tables
for table in "${TABLES[@]}"; do
    if add_to_array "$STORY_FILE" "db_tables" "$table"; then
        echo -e "  ${GREEN}Linked table:${NC} $table"
        changes_made=true
    fi
done

# Link dependencies
for dep in "${DEPENDENCIES[@]}"; do
    # Validate dependency story exists
    dep_file=$(find "$STORIES_DIR" -name "*.md" -type f -exec grep -l "^id: $dep" {} \; | head -1)
    if [[ -z "$dep_file" ]]; then
        echo -e "  ${YELLOW}Warning: Dependency story not found: $dep${NC}"
    else
        echo -e "  ${GREEN}Found dependency:${NC} $dep"
    fi

    if add_to_array "$STORY_FILE" "dependencies" "$dep"; then
        echo -e "  ${GREEN}Linked dependency:${NC} $dep"
        changes_made=true
    fi
done

# Update timestamp
if $changes_made; then
    today=$(date +%Y-%m-%d)
    sed -i.bak "s/^updated_at:.*/updated_at: $today/" "$STORY_FILE"
fi

# Clean up backup files
rm -f "${STORY_FILE}.bak"

echo ""
if $changes_made; then
    echo -e "${GREEN}Resources linked successfully!${NC}"
else
    echo -e "${YELLOW}No new links added${NC}"
fi

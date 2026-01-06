#!/bin/bash
# story-validate.sh - Validate user stories
#
# Usage:
#   ./story-validate.sh              # Validate all stories
#   ./story-validate.sh US-001       # Validate specific story
#   ./story-validate.sh --strict     # Fail on warnings

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
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Variables
STORY_ID=""
STRICT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --strict)
            STRICT=true
            shift
            ;;
        --help|-h)
            echo "Usage: story-validate.sh [STORY_ID] [OPTIONS]"
            echo ""
            echo "Arguments:"
            echo "  STORY_ID            Optional: Validate specific story"
            echo ""
            echo "Options:"
            echo "  --strict            Fail on warnings too"
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

echo -e "${BOLD}Validating User Stories${NC}"
echo "=============================================="
echo ""

# Counters
errors=0
warnings=0
validated=0

# Function to extract YAML frontmatter value
extract_yaml() {
    local file="$1"
    local key="$2"
    grep -m1 "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | tr -d '"' || echo ""
}

# Function to extract YAML array items
extract_yaml_array() {
    local file="$1"
    local key="$2"
    # Get lines after the key until next key or end of frontmatter
    awk "/^${key}:/,/^[a-z_]+:/ {print}" "$file" | grep '^\s*-' | sed 's/.*- //' | tr -d '"' || echo ""
}

# Function to validate a single story
validate_story() {
    local file="$1"
    local story_errors=0
    local story_warnings=0

    # Extract fields
    local id=$(extract_yaml "$file" "id")
    local title=$(extract_yaml "$file" "title")
    local module=$(extract_yaml "$file" "module")
    local status=$(extract_yaml "$file" "status")
    local priority=$(extract_yaml "$file" "priority")

    echo -e "${CYAN}$id${NC}: $title"

    # Check required fields
    if [[ -z "$id" ]]; then
        echo -e "  ${RED}ERROR: Missing id${NC}"
        ((story_errors++))
    fi

    if [[ -z "$title" ]]; then
        echo -e "  ${RED}ERROR: Missing title${NC}"
        ((story_errors++))
    fi

    if [[ -z "$module" ]]; then
        echo -e "  ${RED}ERROR: Missing module${NC}"
        ((story_errors++))
    fi

    # Validate status
    case "$status" in
        draft|in-progress|testing|done) ;;
        "")
            echo -e "  ${RED}ERROR: Missing status${NC}"
            ((story_errors++))
            ;;
        *)
            echo -e "  ${RED}ERROR: Invalid status: $status${NC}"
            ((story_errors++))
            ;;
    esac

    # Validate priority
    case "$priority" in
        low|medium|high|critical) ;;
        "")
            echo -e "  ${YELLOW}WARNING: Missing priority${NC}"
            ((story_warnings++))
            ;;
        *)
            echo -e "  ${RED}ERROR: Invalid priority: $priority${NC}"
            ((story_errors++))
            ;;
    esac

    # Check acceptance criteria for non-draft stories
    if [[ "$status" != "draft" ]]; then
        local criteria_count=$(grep -c '^\s*- "' "$file" 2>/dev/null || echo "0")
        if [[ $criteria_count -lt 1 ]]; then
            echo -e "  ${YELLOW}WARNING: No acceptance criteria defined${NC}"
            ((story_warnings++))
        fi
    fi

    # Validate migration_ids exist
    local migrations=$(extract_yaml_array "$file" "migration_ids")
    if [[ -n "$migrations" ]]; then
        while IFS= read -r migration; do
            if [[ -z "$migration" ]]; then continue; fi
            local migration_file=$(find "$MIGRATIONS_DIR" -name "${migration}*.sql" -type f 2>/dev/null | head -1)
            if [[ -z "$migration_file" ]]; then
                echo -e "  ${YELLOW}WARNING: Migration not found: $migration${NC}"
                ((story_warnings++))
            fi
        done <<< "$migrations"
    fi

    # For done stories, require migrations and tests
    if [[ "$status" == "done" ]]; then
        if [[ -z "$migrations" ]] || [[ "$migrations" == "[]" ]]; then
            echo -e "  ${YELLOW}WARNING: Done story has no migrations linked${NC}"
            ((story_warnings++))
        fi

        local tests=$(extract_yaml_array "$file" "test_files")
        if [[ -z "$tests" ]] || [[ "$tests" == "[]" ]]; then
            echo -e "  ${YELLOW}WARNING: Done story has no test files linked${NC}"
            ((story_warnings++))
        fi
    fi

    # Validate test files exist
    local tests=$(extract_yaml_array "$file" "test_files")
    if [[ -n "$tests" ]]; then
        while IFS= read -r test; do
            if [[ -z "$test" ]]; then continue; fi
            local test_file="$REPO_ROOT/$test"
            if [[ ! -f "$test_file" ]]; then
                echo -e "  ${YELLOW}WARNING: Test file not found: $test${NC}"
                ((story_warnings++))
            fi
        done <<< "$tests"
    fi

    # Return counts
    ((validated++))
    ((errors += story_errors))
    ((warnings += story_warnings))

    if [[ $story_errors -eq 0 ]] && [[ $story_warnings -eq 0 ]]; then
        echo -e "  ${GREEN}OK${NC}"
    fi
}

# Find stories to validate
if [[ -n "$STORY_ID" ]]; then
    # Validate specific story
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

    validate_story "$STORY_FILE"
else
    # Validate all stories
    while IFS= read -r file; do
        # Skip template
        if [[ "$file" == *"story-template.md"* ]] || [[ "$file" == *"US-XXX"* ]]; then
            continue
        fi
        validate_story "$file"
    done < <(find "$STORIES_DIR" -name "US-*.md" -type f | sort)
fi

# Check for duplicate IDs
echo ""
echo -e "${BOLD}Checking for duplicates...${NC}"
duplicates=$(find "$STORIES_DIR" -name "US-*.md" -type f -exec grep -h "^id:" {} \; | sort | uniq -d)
if [[ -n "$duplicates" ]]; then
    echo -e "${RED}ERROR: Duplicate story IDs found:${NC}"
    echo "$duplicates"
    ((errors++))
else
    echo -e "${GREEN}No duplicate IDs${NC}"
fi

# Summary
echo ""
echo "=============================================="
echo -e "${BOLD}Summary${NC}"
echo "------"
echo -e "Stories validated: $validated"
echo -e "Errors:           ${RED}$errors${NC}"
echo -e "Warnings:         ${YELLOW}$warnings${NC}"
echo ""

# Exit code
if [[ $errors -gt 0 ]]; then
    echo -e "${RED}Validation failed with errors${NC}"
    exit 1
elif [[ $warnings -gt 0 ]] && $STRICT; then
    echo -e "${YELLOW}Validation failed with warnings (strict mode)${NC}"
    exit 1
else
    echo -e "${GREEN}Validation passed${NC}"
    exit 0
fi

#!/bin/bash
#
# Skill Discovery Test Script
#
# Tests if a skill can be discovered by Claude Code by checking:
# 1. SKILL.md exists and is valid
# 2. YAML frontmatter is properly formatted
# 3. Description contains trigger keywords
# 4. File structure follows best practices
#
# Usage:
#   ./test-discovery.sh skill-name
#   ./test-discovery.sh path/to/skill/
#
# Exit codes:
#   0 - Discovery test passed
#   1 - Discovery test failed
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}❌ $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 skill-name"
        echo "       $0 path/to/skill/"
        echo ""
        echo "Examples:"
        echo "  $0 database-migration-manager"
        echo "  $0 .claude/skills/api-patterns/"
        exit 1
    fi

    local skill_arg="$1"
    local skill_path=""

    # Determine skill path
    if [ -d "$skill_arg" ]; then
        skill_path="$skill_arg"
    elif [ -d ".claude/skills/$skill_arg" ]; then
        skill_path=".claude/skills/$skill_arg"
    else
        error "Skill not found: $skill_arg"
        echo ""
        echo "Try one of these:"
        echo "  - Provide full path: $0 .claude/skills/skill-name/"
        echo "  - Provide skill name: $0 skill-name"
        exit 1
    fi

    # Remove trailing slash
    skill_path="${skill_path%/}"
    local skill_name=$(basename "$skill_path")

    echo ""
    echo "=========================================="
    echo "SKILL DISCOVERY TEST: $skill_name"
    echo "=========================================="
    echo ""

    local failed=0

    # Test 1: Check SKILL.md exists
    echo "Test 1: SKILL.md exists"
    if [ -f "$skill_path/SKILL.md" ]; then
        success "SKILL.md found"
    else
        error "SKILL.md not found in $skill_path"
        ((failed++))
    fi
    echo ""

    if [ ! -f "$skill_path/SKILL.md" ]; then
        error "Cannot proceed without SKILL.md"
        exit 1
    fi

    # Test 2: YAML frontmatter validation
    echo "Test 2: YAML frontmatter validation"

    # Check starts with ---
    if head -n 1 "$skill_path/SKILL.md" | grep -q "^---$"; then
        success "Frontmatter starts with ---"
    else
        error "Frontmatter must start with ---"
        ((failed++))
    fi

    # Check has closing ---
    if sed -n '2,20p' "$skill_path/SKILL.md" | grep -q "^---$"; then
        success "Frontmatter has closing ---"
    else
        error "Frontmatter missing closing ---"
        ((failed++))
    fi

    # Check for required fields
    if grep -q "^name:" "$skill_path/SKILL.md"; then
        local name_value=$(grep "^name:" "$skill_path/SKILL.md" | head -1 | sed 's/name: *//')
        success "Has 'name' field: $name_value"

        # Validate name matches directory
        if [ "$name_value" != "$skill_name" ]; then
            warning "Name in frontmatter ($name_value) doesn't match directory name ($skill_name)"
        fi
    else
        error "Missing 'name' field in frontmatter"
        ((failed++))
    fi

    if grep -q "^description:" "$skill_path/SKILL.md"; then
        success "Has 'description' field"
    else
        error "Missing 'description' field in frontmatter"
        ((failed++))
    fi

    # Check for tabs in frontmatter (YAML doesn't allow tabs)
    if sed -n '/^---$/,/^---$/p' "$skill_path/SKILL.md" | grep -q $'\t'; then
        error "Frontmatter contains tabs (YAML requires spaces)"
        ((failed++))
    else
        success "No tabs in frontmatter"
    fi

    echo ""

    # Test 3: Description quality
    echo "Test 3: Description quality"

    # Extract description (handle multiline)
    local description=$(awk '/^description:/ {found=1; sub(/^description: */, ""); desc=$0} found && /^---$/ {exit} found && !/^---$/ {if (NR>1) desc=desc" "$0} END {print desc}' "$skill_path/SKILL.md" | tr -d '"' | tr -d "'")

    if [ -z "$description" ]; then
        error "Could not extract description"
        ((failed++))
    else
        local desc_length=${#description}
        info "Description length: $desc_length characters"

        if [ $desc_length -gt 1024 ]; then
            error "Description too long ($desc_length chars, max 1024)"
            ((failed++))
        elif [ $desc_length -lt 50 ]; then
            warning "Description seems short ($desc_length chars). Add more trigger keywords."
        else
            success "Description length is good"
        fi

        # Check for trigger keywords (action verbs)
        local has_action_verb=false
        for verb in "create" "analyze" "optimize" "validate" "generate" "test" "deploy" "configure" "monitor" "manage" "integrate" "implement"; do
            if echo "$description" | grep -qi "$verb"; then
                has_action_verb=true
                break
            fi
        done

        if [ "$has_action_verb" = true ]; then
            success "Description contains action verbs"
        else
            warning "Description missing action verbs (create, analyze, optimize, etc.)"
        fi

        # Check for "use when" clause
        if echo "$description" | grep -qi "use when"; then
            success "Description has 'use when' clause"
        else
            warning "Description missing 'use when' clause for better discovery"
        fi

        # Count words
        local word_count=$(echo "$description" | wc -w | tr -d ' ')
        if [ "$word_count" -lt 20 ]; then
            warning "Description may be too short ($word_count words). Add more trigger keywords."
        else
            success "Description has sufficient detail ($word_count words)"
        fi
    fi

    echo ""

    # Test 4: Required sections
    echo "Test 4: Required sections"

    if grep -q "^## When to Use" "$skill_path/SKILL.md"; then
        success "Has 'When to Use' section"
    else
        warning "Missing 'When to Use' section (recommended)"
    fi

    if grep -q "^## Quick Reference" "$skill_path/SKILL.md"; then
        success "Has 'Quick Reference' section"
    else
        warning "Missing 'Quick Reference' section (recommended)"
    fi

    if grep -q "^## Troubleshooting" "$skill_path/SKILL.md"; then
        success "Has 'Troubleshooting' section"
    else
        warning "Missing 'Troubleshooting' section (recommended)"
    fi

    echo ""

    # Test 5: Code examples
    echo "Test 5: Code examples"

    local code_block_count=$(grep -c '```' "$skill_path/SKILL.md" || echo "0")
    local example_count=$((code_block_count / 2))

    if [ $example_count -gt 0 ]; then
        success "Found $example_count code example(s)"
    else
        warning "No code examples found. Add at least one working example."
    fi

    echo ""

    # Test 6: File structure
    echo "Test 6: File structure"

    local line_count=$(wc -l < "$skill_path/SKILL.md")
    info "SKILL.md has $line_count lines"

    if [ $line_count -gt 500 ]; then
        warning "SKILL.md exceeds 500 lines. Consider progressive disclosure."
    else
        success "SKILL.md within 500 line target"
    fi

    # Check for progressive disclosure files
    if [ -f "$skill_path/REFERENCE.md" ]; then
        info "Uses progressive disclosure: REFERENCE.md found"
    fi

    if [ -f "$skill_path/EXAMPLES.md" ]; then
        info "Uses progressive disclosure: EXAMPLES.md found"
    fi

    # Check scripts directory
    if [ -d "$skill_path/scripts" ]; then
        local script_count=$(find "$skill_path/scripts" -type f \( -name "*.py" -o -name "*.sh" \) | wc -l | tr -d ' ')
        if [ $script_count -gt 0 ]; then
            success "Found $script_count script(s) in scripts/"

            # Check execute permissions for shell scripts
            local missing_perms=false
            for script in "$skill_path/scripts"/*.sh; do
                if [ -f "$script" ] && [ ! -x "$script" ]; then
                    warning "Script $(basename "$script") missing execute permission (run: chmod +x $script)"
                    missing_perms=true
                fi
            done

            if [ "$missing_perms" = false ]; then
                success "All shell scripts have execute permissions"
            fi
        fi
    fi

    echo ""

    # Summary
    echo "=========================================="
    echo "SUMMARY"
    echo "=========================================="
    echo ""

    if [ $failed -eq 0 ]; then
        success "Discovery test PASSED - Skill should be discoverable by Claude"
        echo ""
        echo "Next steps:"
        echo "1. Test discovery: Ask Claude 'What Skills are available?'"
        echo "2. Test triggers: Use keywords from description in a request"
        echo "3. Verify skill invokes correctly"
        exit 0
    else
        error "Discovery test FAILED - $failed critical issue(s) found"
        echo ""
        echo "Fix the issues above, then re-run this test."
        exit 1
    fi
}

main "$@"

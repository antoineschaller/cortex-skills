#!/bin/bash
#
# Quick Standards Check
#
# Fast validation script for critical engineering standards.
# Performs basic checks without full analysis for quick feedback.
#
# Usage:
#   ./check-standards.sh [PROJECT_PATH]
#   ./check-standards.sh --help
#
# Exit codes:
#   0 - All critical checks passed
#   1 - Some checks failed

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project path
PROJECT_PATH="${1:-.}"

# Counters
PASSED=0
FAILED=0
WARNED=0

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNED++))
}

check_file_exists() {
    local file="$1"
    local description="$2"

    if [ -f "$PROJECT_PATH/$file" ]; then
        check_pass "$description: $file"
        return 0
    else
        check_fail "$description: $file (not found)"
        return 1
    fi
}

check_file_contains() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if [ ! -f "$PROJECT_PATH/$file" ]; then
        check_warn "$description: $file not found"
        return 1
    fi

    if grep -q "$pattern" "$PROJECT_PATH/$file"; then
        check_pass "$description"
        return 0
    else
        check_warn "$description (not found in $file)"
        return 1
    fi
}

# Header
echo -e "${BLUE}🔍 Quick Standards Check: $PROJECT_PATH${NC}"
echo ""

# ========== Critical Files ==========
echo "Critical Files:"

check_file_exists "CLAUDE.md" "Project documentation"
check_file_exists "README.md" "Project README"
check_file_exists ".gitignore" "Git ignore configuration"

if [ -f "$PROJECT_PATH/package.json" ]; then
    check_pass "Package manifest: package.json"
    ((PASSED++))

    # Check for quality script
    if grep -q '"quality"' "$PROJECT_PATH/package.json"; then
        check_pass "Quality script configured"
        ((PASSED++))
    else
        check_warn "Quality script not found in package.json"
        ((WARNED++))
    fi
fi

echo ""

# ========== Hooks ==========
echo "Hooks Configuration:"

check_file_exists ".lefthook.yml" "Git hooks (lefthook)"

if [ -f "$PROJECT_PATH/.lefthook.yml" ]; then
    # Check for pre-commit hooks
    if grep -q "pre-commit:" "$PROJECT_PATH/.lefthook.yml"; then
        check_pass "Pre-commit hooks configured"
        ((PASSED++))
    else
        check_warn "Pre-commit hooks not configured"
        ((WARNED++))
    fi

    # Check for pre-push hooks
    if grep -q "pre-push:" "$PROJECT_PATH/.lefthook.yml"; then
        check_pass "Pre-push hooks configured"
        ((PASSED++))
    else
        check_warn "Pre-push hooks not configured"
        ((WARNED++))
    fi
fi

check_file_exists ".claude/settings.json" "Claude Code hooks"

echo ""

# ========== Quality Tools ==========
echo "Quality Tools:"

check_file_exists "tsconfig.json" "TypeScript configuration"

if [ -f "$PROJECT_PATH/tsconfig.json" ]; then
    if grep -q '"strict": true' "$PROJECT_PATH/tsconfig.json"; then
        check_pass "TypeScript strict mode enabled"
        ((PASSED++))
    else
        check_fail "TypeScript strict mode not enabled"
        ((FAILED++))
    fi
fi

# Check for ESLint (either file)
if [ -f "$PROJECT_PATH/eslint.config.mjs" ] || [ -f "$PROJECT_PATH/.eslintrc.json" ]; then
    check_pass "ESLint configuration"
    ((PASSED++))
else
    check_warn "ESLint configuration not found"
    ((WARNED++))
fi

# Check for Prettier
if [ -f "$PROJECT_PATH/.prettierrc" ] || [ -f "$PROJECT_PATH/.prettierrc.json" ]; then
    check_pass "Prettier configuration"
    ((PASSED++))
else
    check_warn "Prettier configuration not found"
    ((WARNED++))
fi

echo ""

# ========== Testing ==========
echo "Testing Setup:"

if [ -f "$PROJECT_PATH/vitest.config.ts" ] || [ -f "$PROJECT_PATH/vitest.config.js" ]; then
    check_pass "Vitest configuration"
    ((PASSED++))

    # Check for coverage thresholds
    if [ -f "$PROJECT_PATH/vitest.config.ts" ]; then
        if grep -q "thresholds" "$PROJECT_PATH/vitest.config.ts"; then
            check_pass "Coverage thresholds configured"
            ((PASSED++))
        else
            check_warn "Coverage thresholds not configured"
            ((WARNED++))
        fi
    fi
else
    check_warn "Vitest configuration not found"
    ((WARNED++))
fi

if [ -f "$PROJECT_PATH/playwright.config.ts" ]; then
    check_pass "Playwright E2E testing"
    ((PASSED++))
else
    echo -e "  ${NC}ℹ${NC}  Playwright not configured (optional)"
fi

echo ""

# ========== Security ==========
echo "Security:"

if [ -f "$PROJECT_PATH/.env.local.example" ] || [ -f "$PROJECT_PATH/.env.example" ]; then
    check_pass "Environment variable example file"
    ((PASSED++))
else
    check_warn "Environment variable example file not found"
    ((WARNED++))
fi

# Check for .env in gitignore
if [ -f "$PROJECT_PATH/.gitignore" ]; then
    if grep -q "\.env" "$PROJECT_PATH/.gitignore"; then
        check_pass ".env files in .gitignore"
        ((PASSED++))
    else
        check_fail ".env files not in .gitignore (security risk!)"
        ((FAILED++))
    fi
fi

echo ""

# ========== Documentation Structure ==========
echo "Documentation:"

if [ -d "$PROJECT_PATH/docs" ]; then
    check_pass "Documentation directory exists"
    ((PASSED++))

    if [ -d "$PROJECT_PATH/docs/wip" ] || [ -d "$PROJECT_PATH/docs/wip/active" ]; then
        check_pass "WIP directory for temporary docs"
        ((PASSED++))
    else
        echo -e "  ${NC}ℹ${NC}  WIP directory not found (optional)"
    fi
else
    echo -e "  ${NC}ℹ${NC}  docs/ directory not found (optional)"
fi

# Check for forbidden root .md files
forbidden_md_files=$(find "$PROJECT_PATH" -maxdepth 1 -name "*.md" ! -name "CLAUDE.md" ! -name "README.md" ! -name "CHANGELOG.md" ! -name "CONTRIBUTING.md" ! -name "LICENSE.md" 2>/dev/null | wc -l | tr -d ' ')

if [ "$forbidden_md_files" -gt 0 ]; then
    check_fail "Forbidden root .md files found (should be in docs/)"
    ((FAILED++))
else
    check_pass "No forbidden root .md files"
    ((PASSED++))
fi

echo ""

# ========== Naming Conventions ==========
echo "Naming Conventions:"

# Check for version suffixes in files (quick check in common directories)
forbidden_files=0
for dir in "app" "src" "lib" "components" "packages"; do
    if [ -d "$PROJECT_PATH/$dir" ]; then
        # Check for -v2, -v3, -new, -updated suffixes
        count=$(find "$PROJECT_PATH/$dir" -type f \( -name "*-v2.*" -o -name "*-v3.*" -o -name "*-new.*" -o -name "*-updated.*" -o -name "*-improved.*" -o -name "*-enhanced.*" \) 2>/dev/null | wc -l | tr -d ' ')
        forbidden_files=$((forbidden_files + count))
    fi
done

if [ "$forbidden_files" -gt 0 ]; then
    check_fail "Found $forbidden_files files with forbidden suffixes (-v2, -new, etc.)"
    ((FAILED++))
else
    check_pass "No version/enhancement suffixes in filenames"
    ((PASSED++))
fi

echo ""

# ========== Summary ==========
TOTAL=$((PASSED + FAILED + WARNED))
SCORE=0

if [ "$TOTAL" -gt 0 ]; then
    # Calculate score (warnings count as 50%)
    SCORE=$(awk "BEGIN {printf \"%.0f\", (($PASSED + $WARNED * 0.5) / $TOTAL) * 100}")
fi

echo "========================================="
echo -e "${BLUE}Summary${NC}"
echo "========================================="
echo -e "${GREEN}✓ Passed:${NC} $PASSED"
echo -e "${RED}✗ Failed:${NC} $FAILED"
echo -e "${YELLOW}⚠ Warnings:${NC} $WARNED"
echo ""
echo -e "Overall: ${SCORE}%"

if [ "$SCORE" -ge 95 ]; then
    echo -e "${GREEN}Grade: A - Excellent compliance${NC}"
elif [ "$SCORE" -ge 85 ]; then
    echo -e "${BLUE}Grade: B - Good compliance${NC}"
elif [ "$SCORE" -ge 70 ]; then
    echo -e "${YELLOW}Grade: C - Acceptable compliance${NC}"
elif [ "$SCORE" -ge 50 ]; then
    echo -e "${YELLOW}Grade: D - Poor compliance${NC}"
else
    echo -e "${RED}Grade: F - Failing compliance${NC}"
fi

echo "========================================="
echo ""

# Recommendations
if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}Action Required:${NC} Fix critical failures above"
    echo "  Run: python scripts/validate-compliance.py --project-path $PROJECT_PATH"
    echo ""
fi

if [ "$WARNED" -gt 0 ]; then
    echo -e "${YELLOW}Recommended:${NC} Address warnings for better compliance"
    echo "  Run: python scripts/generate-report.py --project-path $PROJECT_PATH --format markdown"
    echo ""
fi

# Exit code
if [ "$FAILED" -gt 0 ]; then
    exit 1
else
    exit 0
fi

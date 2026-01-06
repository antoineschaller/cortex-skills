#!/bin/bash
# Automated fix script for Vercel environment variables with trailing newlines
#
# This script:
# 1. Pulls current env vars from Vercel
# 2. Identifies variables with trailing \n issues
# 3. Removes and re-adds them with echo -n (no trailing newline)
#
# Usage:
#   ./fix-production-env-vars.sh                    # Interactive mode (production only)
#   ./fix-production-env-vars.sh --yes              # Non-interactive (production only)
#   ./fix-production-env-vars.sh --env preview      # Fix preview/staging
#   ./fix-production-env-vars.sh --env production   # Fix production (default)
#   ./fix-production-env-vars.sh --env all --yes    # Fix both non-interactively

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
ENVIRONMENT="production"
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --yes|-y)
            NON_INTERACTIVE=true
            shift
            ;;
        --env|-e)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --env, -e <env>    Environment to fix: preview, production, or all (default: production)"
            echo "  --yes, -y          Non-interactive mode (skip confirmation prompts)"
            echo "  --help, -h         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${CYAN}ℹ ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  ${1}${NC}"
}

log_error() {
    echo -e "${RED}❌ ${1}${NC}"
}

log_step() {
    echo -e "${BLUE}▶ ${1}${NC}"
}

fix_environment() {
    local ENV_NAME="$1"
    local TEMP_FILE=".env.fix-${ENV_NAME}.temp"

    echo ""
    echo "========================================================================"
    log_step "Fixing $ENV_NAME environment"
    echo "========================================================================"

    # Pull current env vars
    log_info "Pulling $ENV_NAME environment variables..."
    rm -f "$TEMP_FILE"
    if ! vercel env pull "$TEMP_FILE" --environment="$ENV_NAME" --yes > /dev/null 2>&1; then
        log_error "Failed to pull $ENV_NAME environment variables"
        return 1
    fi

    # Find variables with trailing \n
    VARS_WITH_ISSUES=$(grep '\\n"$' "$TEMP_FILE" 2>/dev/null | cut -d'=' -f1 || true)

    if [ -z "$VARS_WITH_ISSUES" ]; then
        log_success "No trailing newline issues found in $ENV_NAME"
        rm -f "$TEMP_FILE"
        return 0
    fi

    VAR_COUNT=$(echo "$VARS_WITH_ISSUES" | wc -l | tr -d ' ')
    log_warning "Found $VAR_COUNT variables with trailing newlines in $ENV_NAME:"
    echo "$VARS_WITH_ISSUES" | while read -r var; do
        echo "  - $var"
    done
    echo ""

    # Confirm if interactive
    if [ "$NON_INTERACTIVE" != "true" ]; then
        read -p "Fix these variables? (yes/no): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            log_info "Skipped $ENV_NAME"
            rm -f "$TEMP_FILE"
            return 0
        fi
    fi

    # Fix each variable
    FIXED_COUNT=0
    FAILED_COUNT=0

    echo "$VARS_WITH_ISSUES" | while read -r VAR_NAME; do
        if [ -z "$VAR_NAME" ]; then
            continue
        fi

        # Extract value, remove quotes and trailing \n
        VALUE=$(grep "^${VAR_NAME}=" "$TEMP_FILE" | sed 's/^[^=]*=//' | sed 's/^"//;s/"$//' | sed 's/\\n$//')

        if [ -z "$VALUE" ]; then
            log_warning "  $VAR_NAME: empty value, skipping"
            continue
        fi

        log_step "  Fixing $VAR_NAME..."

        # Remove old variable
        if ! vercel env rm "$VAR_NAME" "$ENV_NAME" --yes > /dev/null 2>&1; then
            log_warning "  Could not remove $VAR_NAME (may not exist)"
        fi

        # Add new variable with echo -n
        if echo -n "$VALUE" | vercel env add "$VAR_NAME" "$ENV_NAME" > /dev/null 2>&1; then
            log_success "  $VAR_NAME fixed"
        else
            log_error "  Failed to add $VAR_NAME"
        fi
    done

    rm -f "$TEMP_FILE"
    log_success "$ENV_NAME environment fixed"
}

verify_environment() {
    local ENV_NAME="$1"
    local TEMP_FILE=".env.verify-${ENV_NAME}.temp"

    log_info "Verifying $ENV_NAME..."
    rm -f "$TEMP_FILE"
    vercel env pull "$TEMP_FILE" --environment="$ENV_NAME" --yes > /dev/null 2>&1

    if grep -q '\\n"$' "$TEMP_FILE" 2>/dev/null; then
        log_error "$ENV_NAME still has issues:"
        grep '\\n"$' "$TEMP_FILE" | cut -d'=' -f1 | while read -r var; do
            echo "  - $var"
        done
        rm -f "$TEMP_FILE"
        return 1
    else
        log_success "$ENV_NAME is clean"
        rm -f "$TEMP_FILE"
        return 0
    fi
}

echo ""
echo "🔧 Fix Vercel Environment Variables"
echo ""

# Determine which environments to fix
case $ENVIRONMENT in
    all)
        ENVIRONMENTS="preview production"
        ;;
    preview|staging)
        ENVIRONMENTS="preview"
        ;;
    production|prod)
        ENVIRONMENTS="production"
        ;;
    *)
        log_error "Unknown environment: $ENVIRONMENT"
        echo "Valid options: preview, production, all"
        exit 1
        ;;
esac

# Fix each environment
for ENV in $ENVIRONMENTS; do
    fix_environment "$ENV"
done

# Verify fixes
echo ""
echo "========================================================================"
log_step "Verification"
echo "========================================================================"

ALL_CLEAN=true
for ENV in $ENVIRONMENTS; do
    if ! verify_environment "$ENV"; then
        ALL_CLEAN=false
    fi
done

echo ""
if [ "$ALL_CLEAN" = "true" ]; then
    log_success "All environments are clean!"
    echo ""
    echo "NEXT STEPS:"
    echo "  1. Trigger a redeploy on Vercel (or push a commit)"
    echo "  2. The new env vars will be used in the next build"
else
    log_error "Some environments still have issues"
    exit 1
fi

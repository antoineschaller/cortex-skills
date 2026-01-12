#!/usr/bin/env bash
# Generic environment variable and dependency validator
#
# Validates that all required environment variables are set.
# Useful for ensuring environment is properly configured before running applications.
#
# Usage:
#   ./validate-dependencies.sh VAR1 VAR2 VAR3...
#   ./validate-dependencies.sh DATABASE_URL API_KEY SECRET_KEY
#
# Exit Codes:
#   0 - All required variables are set
#   1 - One or more variables are missing
#
# Examples:
#   # Validate single variable
#   ./validate-dependencies.sh DATABASE_URL
#
#   # Validate multiple variables
#   ./validate-dependencies.sh DATABASE_URL API_KEY PORT
#
#   # Use in script
#   if ./validate-dependencies.sh DATABASE_URL API_KEY; then
#     echo "Ready to start!"
#   fi

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if any arguments provided
if [ $# -eq 0 ]; then
  echo -e "${YELLOW}Usage: $0 VAR1 VAR2 VAR3...${NC}"
  echo -e "${YELLOW}Example: $0 DATABASE_URL API_KEY SECRET_KEY${NC}"
  exit 1
fi

# Store required variables
REQUIRED_VARS=("$@")
MISSING=()
PRESENT=()

echo -e "${GREEN}Validating ${#REQUIRED_VARS[@]} required environment variable(s)...${NC}\n"

# Check each variable
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    MISSING+=("$var")
    echo -e "  ${RED}✗${NC} $var (missing)"
  else
    PRESENT+=("$var")
    # Show first 20 chars of value (for security, don't show full value)
    VALUE="${!var}"
    PREVIEW="${VALUE:0:20}"
    if [ ${#VALUE} -gt 20 ]; then
      PREVIEW="${PREVIEW}..."
    fi
    echo -e "  ${GREEN}✓${NC} $var (set: $PREVIEW)"
  fi
done

echo ""

# Summary
if [ ${#MISSING[@]} -gt 0 ]; then
  echo -e "${RED}❌ Missing ${#MISSING[@]} required environment variable(s):${NC}"
  for var in "${MISSING[@]}"; do
    echo -e "   - ${RED}$var${NC}"
  done
  echo ""
  echo -e "${YELLOW}Set missing variables in your .env file or export them:${NC}"
  for var in "${MISSING[@]}"; do
    echo -e "   export $var=\"your_value_here\""
  done
  exit 1
else
  echo -e "${GREEN}✅ All ${#PRESENT[@]} required environment variable(s) are set${NC}"
  exit 0
fi

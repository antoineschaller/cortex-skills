#!/usr/bin/env bash
# Generic skill.config.json validator
#
# Validates skill configuration files against the skill-config.schema.json schema.
# Checks JSON syntax, schema compliance, and environment variable presence.
#
# Usage:
#   ./validate-skill-config.sh [file1.json file2.json ...]
#   ./validate-skill-config.sh  # Validates all skill.config.json files
#
# Environment Variables:
#   SKILLS_DIR - Directory to search for skills (default: "skills")
#   CHECK_ENV_VARS - Set to "1" to check if required env vars are set (default: 0)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SKILLS_DIR="${SKILLS_DIR:-skills}"
CHECK_ENV_VARS="${CHECK_ENV_VARS:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$(cd "$SCRIPT_DIR/../.." && pwd)/skill-config.schema.json"

# Check if schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
  echo -e "${RED}❌ Schema file not found: $SCHEMA_FILE${NC}"
  exit 1
fi

# Get files to check - either from arguments or find all skill.config.json files
if [ $# -gt 0 ]; then
  FILES="$@"
else
  FILES=$(find "$SKILLS_DIR" -name "skill.config.json" -o -name "skill.config.example.json" 2>/dev/null || true)
fi

if [ -z "$FILES" ]; then
  echo -e "${YELLOW}ℹ️  No skill.config.json files to validate${NC}"
  exit 0
fi

ERRORS=0
WARNINGS=0
CHECKED=0

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Skill Configuration Validation${NC}"
echo -e "${BLUE}  Schema: skill-config.schema.json${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"

for file in $FILES; do
  if [ ! -f "$file" ]; then
    continue
  fi

  CHECKED=$((CHECKED + 1))
  filename=$(basename "$file")
  dirname=$(dirname "$file")
  skill_name=$(basename "$(dirname "$file")")

  echo -e "${BLUE}Checking: $file${NC}"

  # 1. Check JSON syntax
  if ! node -e "JSON.parse(require('fs').readFileSync('$file', 'utf8'))" 2>/dev/null; then
    echo -e "  ${RED}✗ Invalid JSON syntax${NC}"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # 2. Validate against schema using Node.js
  VALIDATION_RESULT=$(node -e "
    const fs = require('fs');
    const Ajv = require('ajv');
    const addFormats = require('ajv-formats');

    try {
      const ajv = new Ajv({ allErrors: true });
      addFormats(ajv);

      const schema = JSON.parse(fs.readFileSync('$SCHEMA_FILE', 'utf8'));
      const config = JSON.parse(fs.readFileSync('$file', 'utf8'));

      const validate = ajv.compile(schema);
      const valid = validate(config);

      if (!valid) {
        console.log(JSON.stringify(validate.errors));
      } else {
        console.log('VALID');
      }
    } catch (error) {
      console.log('ERROR: ' + error.message);
    }
  " 2>&1 || echo "ERROR: ajv not installed. Run: npm install -g ajv ajv-formats")

  if [ "$VALIDATION_RESULT" = "VALID" ]; then
    echo -e "  ${GREEN}✓ Schema validation passed${NC}"
  else
    echo -e "  ${RED}✗ Schema validation failed${NC}"
    if [ "$VALIDATION_RESULT" != "ERROR:"* ]; then
      echo "$VALIDATION_RESULT" | node -e "
        const errors = JSON.parse(require('fs').readFileSync(0, 'utf8'));
        errors.forEach(err => {
          console.log('     ' + err.instancePath + ': ' + err.message);
        });
      " 2>/dev/null || echo "  $VALIDATION_RESULT"
    else
      echo "  ${YELLOW}⚠️  $VALIDATION_RESULT${NC}"
    fi
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # 3. Check skill name matches directory
  SKILL_NAME=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$file', 'utf8')).skill)" 2>/dev/null || echo "")
  if [ -n "$SKILL_NAME" ] && [ "$SKILL_NAME" != "$skill_name" ]; then
    echo -e "  ${YELLOW}⚠️  Skill name mismatch: '$SKILL_NAME' (config) vs '$skill_name' (directory)${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi

  # 4. Check environment variables if requested
  if [ "$CHECK_ENV_VARS" = "1" ]; then
    ENV_VARS=$(node -e "
      const config = JSON.parse(require('fs').readFileSync('$file', 'utf8'));
      if (config.dependencies && config.dependencies.env_vars) {
        const required = Object.keys(config.dependencies.env_vars)
          .filter(key => config.dependencies.env_vars[key].required);
        console.log(required.join(' '));
      }
    " 2>/dev/null || echo "")

    if [ -n "$ENV_VARS" ]; then
      MISSING_VARS=""
      for var in $ENV_VARS; do
        if [ -z "${!var}" ]; then
          MISSING_VARS="$MISSING_VARS $var"
        fi
      done

      if [ -n "$MISSING_VARS" ]; then
        echo -e "  ${YELLOW}⚠️  Missing required env vars:$MISSING_VARS${NC}"
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
  fi

  echo ""
done

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
if [ $ERRORS -gt 0 ]; then
  echo -e "${RED}❌ Validation failed: $ERRORS error(s), $WARNINGS warning(s) in $CHECKED file(s)${NC}"
  exit 1
else
  if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}✅ Validation passed with $WARNINGS warning(s) in $CHECKED file(s)${NC}"
  else
    echo -e "${GREEN}✅ All $CHECKED configuration file(s) valid${NC}"
  fi
  exit 0
fi

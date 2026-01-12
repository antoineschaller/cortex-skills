#!/usr/bin/env bash
# Generic JSON duplicate key validator
#
# Validates JSON files for duplicate keys which can cause silent data loss.
# Can be used with any JSON files (locales, config files, etc.)
#
# Usage:
#   ./validate-json-keys.sh [file1.json file2.json ...]
#   ./validate-json-keys.sh  # Validates all JSON files in configured directory
#
# Environment Variables:
#   JSON_DIR - Directory to search for JSON files (default: ".")
#   JSON_PATTERN - File pattern to match (default: "*.json")

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration (can be overridden via environment variables)
JSON_DIR="${JSON_DIR:-.}"
JSON_PATTERN="${JSON_PATTERN:-*.json}"

# Get files to check - either from arguments or find all JSON files
if [ $# -gt 0 ]; then
  FILES="$@"
else
  FILES=$(find "$JSON_DIR" -name "$JSON_PATTERN" 2>/dev/null || true)
fi

if [ -z "$FILES" ]; then
  echo -e "${YELLOW}ℹ️  No JSON files to validate${NC}"
  exit 0
fi

ERRORS=0

for file in $FILES; do
  if [ ! -f "$file" ]; then
    continue
  fi

  # Use node to parse JSON and detect duplicate keys
  DUPLICATES=$(node -e "
    const fs = require('fs');
    const content = fs.readFileSync('$file', 'utf8');

    // Track all keys seen at each nesting level
    const duplicates = [];

    // Parse line by line looking for keys
    const lines = content.split('\n');
    const keysByLevel = [new Map()];

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lineNum = i + 1;

      // Check for key FIRST (before handling braces on same line)
      const keyMatch = line.match(/^\\s*\"([^\"]+)\"\\s*:/);
      if (keyMatch) {
        const key = keyMatch[1];
        const currentLevel = keysByLevel.length - 1;
        const levelKeys = keysByLevel[currentLevel];

        if (levelKeys.has(key)) {
          duplicates.push({
            key,
            firstLine: levelKeys.get(key),
            secondLine: lineNum
          });
        } else {
          levelKeys.set(key, lineNum);
        }
      }

      // Strip string values to avoid counting braces inside strings like {{name}}
      const lineWithoutStrings = line.replace(/\"(?:[^\"\\\\]|\\\\.)*\"/g, '\"\"');

      // Check for opening brace AFTER processing key (new object level)
      const openingBraces = (lineWithoutStrings.match(/{/g) || []).length;
      for (let j = 0; j < openingBraces; j++) {
        keysByLevel.push(new Map());
      }

      // Check for closing brace (end object level)
      const closingBraces = (lineWithoutStrings.match(/}/g) || []).length;
      for (let j = 0; j < closingBraces; j++) {
        if (keysByLevel.length > 1) {
          keysByLevel.pop();
        }
      }
    }

    if (duplicates.length > 0) {
      duplicates.forEach(d => {
        console.log('Duplicate key \"' + d.key + '\" at lines ' + d.firstLine + ' and ' + d.secondLine);
      });
    }
  " 2>&1)

  if [ -n "$DUPLICATES" ]; then
    echo -e "${RED}❌ Duplicate keys found in $file:${NC}"
    echo "$DUPLICATES" | while read line; do
      echo -e "   ${YELLOW}$line${NC}"
    done
    ERRORS=$((ERRORS + 1))
  fi
done

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo -e "${RED}Found $ERRORS file(s) with duplicate JSON keys.${NC}"
  echo -e "${YELLOW}Duplicate keys in JSON cause silent data loss - only the last value is used.${NC}"
  echo -e "Fix by merging the duplicate keys into a single object."
  exit 1
else
  echo -e "${GREEN}✅ No duplicate JSON keys found${NC}"
fi

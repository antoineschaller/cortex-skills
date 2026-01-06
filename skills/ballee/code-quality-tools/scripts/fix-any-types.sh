#!/bin/bash
# Script to automatically replace 'any' types with 'unknown' in test files
# This fixes @typescript-eslint/no-explicit-any errors

set -e

echo "🔧 Fixing 'any' types in test files..."

# Find all test files with 'any' type annotations
find ./app/__tests__ -name "*.ts" -o -name "*.tsx" | while read -r file; do
  if grep -q ": any" "$file" 2>/dev/null; then
    echo "  Fixing: $file"

    # Replace common 'any' patterns in test files
    sed -i '' \
      -e 's/: any\>/: unknown/g' \
      -e 's/: any\[/: unknown[/g' \
      -e 's/: any)/: unknown)/g' \
      -e 's/: any,/: unknown,/g' \
      -e 's/: any;/: unknown;/g' \
      -e 's/<any>/<unknown>/g' \
      -e 's/as any/as unknown/g' \
      "$file"
  fi
done

echo "✅ Fixed 'any' types in test files"

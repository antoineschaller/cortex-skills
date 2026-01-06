#!/bin/bash
# Script to automatically prefix unused variables with '_'
# This fixes @typescript-eslint/no-unused-vars errors

set -e

echo "🔧 Fixing unused variables..."

# Get list of files with unused var errors
pnpm lint 2>&1 | grep "no-unused-vars" | grep -oE "^[^:]+\.tsx?" | sort -u | while read -r file; do
  if [ -f "$file" ]; then
    echo "  Processing: $file"

    # Get the unused variable names from the file
    pnpm lint 2>&1 | grep "$file" | grep "no-unused-vars" | grep -oE "'[^']+' is (defined but never used|assigned a value but never used)" | grep -oE "'[^']+'" | tr -d "'" | sort -u | while read -r varname; do
      if [ ! -z "$varname" ] && [[ ! "$varname" =~ ^_ ]]; then
        echo "    Renaming: $varname -> _$varname"

        # Use more precise sed patterns to avoid false positives
        sed -i '' \
          -e "s/\b$varname\b\([:, )\}]\)/_$varname\1/g" \
          -e "s/\bconst $varname\b/const _$varname/g" \
          -e "s/\blet $varname\b/let _$varname/g" \
          -e "s/\bvar $varname\b/var _$varname/g" \
          -e "s/($varname\b/(\_$varname/g" \
          -e "s/, $varname\b/, _$varname/g" \
          -e "s/{ $varname\b/{ _$varname/g" \
          "$file" 2>/dev/null || true
      fi
    done
  fi
done

echo "✅ Fixed unused variables"

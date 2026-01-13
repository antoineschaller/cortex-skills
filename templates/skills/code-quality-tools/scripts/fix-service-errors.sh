#!/bin/bash
# Fix Result.fail() calls to use ServiceError instances

set -e

echo "🔧 Fixing ServiceError instances in invitation-actions.ts..."

FILE="../../packages/features/events/src/server/actions/invitation-actions.ts"

# Replace Result.fail({ code: 'X', message: 'Y', details: {...} })
# with Result.fail(new ServiceError('X', 'Y', undefined, {...}))

sed -i '' \
  -e "s/Result\.fail({\s*code: '\([^']*\)',\s*message: '\([^']*\)',\s*details: \(.*\)\s*})/Result.fail(new ServiceError('\1', '\2', undefined, \3))/g" \
  -e 's/Result\.fail({\([^}]*\)code: '\''\([^'\'']*\)'\'',\([^}]*\)message: '\''\([^'\'']*\)'\'',\([^}]*\)details: \({[^}]*}\)\([^}]*\)})/Result.fail(new ServiceError('\''\2'\'', '\''\4'\'', undefined, \6))/g' \
  "$FILE"

echo "✅ Fixed ServiceError instances"

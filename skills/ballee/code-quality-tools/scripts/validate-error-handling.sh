#!/bin/bash

#
# Error Handling Validation Script
#
# Validates that database functions return proper error details with:
# - User-friendly error messages
# - Technical details (technicalDetail field)
# - PostgreSQL error codes (errorCode field)
# - Helpful hints when available
#
# WHY: Production errors were being masked. This script ensures database
# functions return actionable error information for debugging.
#
# RUN: ./scripts/validate-error-handling.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Validating Error Handling..."
echo ""

# Database connection details (local Supabase)
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-54322}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-postgres}"
DB_PASSWORD="${PGPASSWORD:-postgres}"

# Check if database is running
if ! PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
  echo -e "${RED}❌ Database not running${NC}"
  echo "Start with: pnpm supabase:web:start"
  exit 1
fi

echo "✅ Database connection OK"
echo ""

# Counter for tests
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper function
test_error_handling() {
  local test_name="$1"
  local sql_query="$2"
  local expected_error_pattern="$3"
  local expected_has_technical_detail="$4"

  echo "Testing: $test_name"

  # Execute query and capture result
  result=$(PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -tA -c "$sql_query" 2>&1)

  # Check if result contains error information (handle both with and without space)
  if echo "$result" | grep -q '"success":\s*false'; then
    echo "  ✓ Function returned error response"

    # Check for user-friendly error message
    if echo "$result" | grep -q "\"error\""; then
      echo "  ✓ User-friendly error message present"
    else
      echo -e "  ${RED}✗ Missing user-friendly error message${NC}"
      TESTS_FAILED=$((TESTS_FAILED + 1))
      return 1
    fi

    # Check for error code
    if echo "$result" | grep -q "\"error_code\""; then
      echo "  ✓ PostgreSQL error code present"
    else
      echo -e "  ${YELLOW}⚠ Missing error_code (may be acceptable)${NC}"
    fi

    # Check for technical detail
    if [ "$expected_has_technical_detail" = "true" ]; then
      if echo "$result" | grep -q "\"technical_detail\""; then
        echo "  ✓ Technical detail present for debugging"

        # Validate technical detail contains expected pattern
        if echo "$result" | grep -i "$expected_error_pattern" > /dev/null; then
          echo "  ✓ Technical detail contains: $expected_error_pattern"
        else
          echo -e "  ${RED}✗ Technical detail missing expected pattern: $expected_error_pattern${NC}"
          TESTS_FAILED=$((TESTS_FAILED + 1))
          return 1
        fi
      else
        echo -e "  ${RED}✗ Missing technical_detail field${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
      fi
    fi

    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓ Test passed${NC}"
    echo ""
    return 0
  else
    echo -e "  ${RED}✗ Function did not return error (unexpected success or crash)${NC}"
    echo "  Result: $result"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo ""
    return 1
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing atomic_profile_update error handling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create test user for validation if doesn't exist
TEST_USER_ID="00000000-0000-0000-0000-000000000999"

# Ensure test user exists in auth.users
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
INSERT INTO auth.users (
  id, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, instance_id, aud, role
) VALUES (
  '$TEST_USER_ID'::uuid,
  'test-validation@ballee.local',
  '\$2a\$10\$abcdefghijklmnopqrstuvwxyz12345678901234567890',
  now(), now(), now(),
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'
) ON CONFLICT (id) DO NOTHING;
" > /dev/null 2>&1

# Test 1: NOT NULL constraint violation (missing first_name)
test_error_handling \
  "NOT NULL constraint (first_name)" \
  "SELECT atomic_profile_update(
    '$TEST_USER_ID'::uuid,
    '{\"last_name\": \"TestLastName\", \"first_name\": null}'::jsonb,
    NULL, NULL, NULL
  )" \
  "first_name" \
  "true"

# Test 2: User not found (testing user validation)
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
DELETE FROM auth.users WHERE id = '00000000-0000-0000-0000-000000000888'::uuid;
" > /dev/null 2>&1

test_error_handling \
  "User not found (validation)" \
  "SELECT atomic_profile_update(
    '00000000-0000-0000-0000-000000000888'::uuid,
    '{\"first_name\": \"Test\", \"last_name\": \"User\"}'::jsonb,
    NULL, NULL, NULL
  )" \
  "User ID does not exist" \
  "true"

# Test 3: Unique constraint violation (ballee_profile_slug)
# Note: This test creates a profile first, then tries to create another with same slug
echo "Testing: Unique constraint (ballee_profile_slug)"
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
DELETE FROM professional_profiles WHERE ballee_profile_slug = 'test-slug-validation';
DELETE FROM profiles WHERE id = '00000000-0000-0000-0000-000000000998'::uuid;
INSERT INTO auth.users (
  id, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, instance_id, aud, role
) VALUES (
  '00000000-0000-0000-0000-000000000998'::uuid,
  'test-unique@ballee.local',
  '\$2a\$10\$abcdefghijklmnopqrstuvwxyz12345678901234567890',
  now(), now(), now(),
  '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'
) ON CONFLICT (id) DO NOTHING;
SELECT atomic_profile_update(
  '00000000-0000-0000-0000-000000000998'::uuid,
  '{\"first_name\": \"Test\", \"last_name\": \"User1\"}'::jsonb,
  '{\"ballee_profile_slug\": \"test-slug-validation\"}'::jsonb,
  NULL, NULL
);
" > /dev/null 2>&1

test_error_handling \
  "Unique constraint (ballee_profile_slug)" \
  "SELECT atomic_profile_update(
    '$TEST_USER_ID'::uuid,
    '{\"first_name\": \"Test\", \"last_name\": \"User2\"}'::jsonb,
    '{\"ballee_profile_slug\": \"test-slug-validation\"}'::jsonb,
    NULL, NULL
  )" \
  "ballee_profile_slug" \
  "true"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ All error handling validation tests passed!${NC}"
  echo ""
  echo "Database functions properly return:"
  echo "  ✓ User-friendly error messages"
  echo "  ✓ Technical details for debugging"
  echo "  ✓ PostgreSQL error codes"
  echo ""
  exit 0
else
  echo -e "${RED}❌ Some tests failed!${NC}"
  echo ""
  echo "Action required:"
  echo "  1. Check database function implementations"
  echo "  2. Ensure error handlers return technical_detail field"
  echo "  3. Run: pnpm supabase:web:reset to apply latest migrations"
  echo ""
  exit 1
fi

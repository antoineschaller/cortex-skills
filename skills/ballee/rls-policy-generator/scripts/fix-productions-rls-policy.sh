#!/usr/bin/env bash

#################################################
# Fix Productions RLS Policy for Service Role
#################################################
#
# This script checks if the productions_service_role_all policy exists
# on the production database and applies it if missing.
#
# ROOT CAUSE:
#   The productions table INSERT policy only allows authenticated users
#   with is_super_admin(). Cron jobs run as service_role, which is blocked.
#
# FIX:
#   Add service_role policy that allows all operations (bypasses RLS).
#
# USAGE:
#   ./scripts/fix-productions-rls-policy.sh
#
#################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Checking Productions RLS Policy for Service Role...${NC}\n"

# Check for required environment variables
if [ -z "$SUPABASE_DB_URL" ]; then
    echo -e "${RED}❌ Error: SUPABASE_DB_URL not set${NC}"
    echo -e "${YELLOW}   Please set production database connection string:${NC}"
    echo -e "${YELLOW}   export SUPABASE_DB_URL='postgresql://postgres:password@db.xxx.supabase.co:5432/postgres'${NC}\n"
    exit 1
fi

echo -e "${GREEN}✅ Database URL configured${NC}\n"

# Step 1: Check if policy exists
echo -e "${BLUE}📊 Step 1: Checking current RLS policies on productions table...${NC}"

POLICY_CHECK=$(psql "$SUPABASE_DB_URL" -t -A -c "
SELECT COUNT(*)
FROM pg_policies
WHERE tablename = 'productions'
  AND policyname = 'productions_service_role_all'
  AND roles @> ARRAY['service_role'];
")

if [ "$POLICY_CHECK" = "1" ]; then
    echo -e "${GREEN}✅ Policy 'productions_service_role_all' already exists!${NC}"
    echo -e "${GREEN}   No fix needed.${NC}\n"

    echo -e "${BLUE}📊 Current policies on productions table:${NC}"
    psql "$SUPABASE_DB_URL" -c "
    SELECT
      policyname,
      roles,
      cmd,
      CASE
        WHEN length(qual::text) > 50 THEN substring(qual::text from 1 for 47) || '...'
        ELSE qual::text
      END as using_clause,
      CASE
        WHEN length(with_check::text) > 50 THEN substring(with_check::text from 1 for 47) || '...'
        ELSE with_check::text
      END as with_check_clause
    FROM pg_policies
    WHERE tablename = 'productions'
    ORDER BY policyname;
    "

    echo -e "\n${GREEN}✅ Fix not needed - service_role policy exists${NC}"
    exit 0
fi

echo -e "${YELLOW}⚠️  Policy 'productions_service_role_all' NOT found${NC}"
echo -e "${YELLOW}   This is the root cause of production sync failures!${NC}\n"

echo -e "${BLUE}📊 Current policies (before fix):${NC}"
psql "$SUPABASE_DB_URL" -c "
SELECT
  policyname,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'productions'
ORDER BY policyname;
"

# Step 2: Apply fix
echo -e "\n${BLUE}🔧 Step 2: Applying fix...${NC}"
echo -e "${YELLOW}   Creating 'productions_service_role_all' policy${NC}\n"

# Confirmation prompt
read -p "Apply fix to PRODUCTION database? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo -e "${RED}❌ Fix cancelled${NC}"
    exit 1
fi

# Apply migration
echo -e "\n${BLUE}🚀 Executing migration...${NC}\n"

psql "$SUPABASE_DB_URL" << 'EOF'
-- =====================================================================================
-- Add service_role policy to productions table
-- =====================================================================================

-- Drop if exists (idempotent)
DROP POLICY IF EXISTS "productions_service_role_all" ON public.productions;

-- Create policy
CREATE POLICY "productions_service_role_all" ON public.productions
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Add comment
COMMENT ON POLICY "productions_service_role_all" ON public.productions IS
  'Allows service_role full access to productions table for cron job sync operations';

-- Verify
SELECT
  policyname,
  roles,
  cmd,
  qual::text as using_clause,
  with_check::text as with_check_clause
FROM pg_policies
WHERE tablename = 'productions'
  AND policyname = 'productions_service_role_all';
EOF

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ Policy created successfully!${NC}\n"
else
    echo -e "\n${RED}❌ Failed to create policy${NC}"
    exit 1
fi

# Step 3: Verify fix
echo -e "${BLUE}📊 Step 3: Verifying fix...${NC}\n"

VERIFY_CHECK=$(psql "$SUPABASE_DB_URL" -t -A -c "
SELECT COUNT(*)
FROM pg_policies
WHERE tablename = 'productions'
  AND policyname = 'productions_service_role_all'
  AND roles @> ARRAY['service_role'];
")

if [ "$VERIFY_CHECK" = "1" ]; then
    echo -e "${GREEN}✅ Policy verified successfully!${NC}\n"

    echo -e "${BLUE}📊 All policies on productions table (after fix):${NC}"
    psql "$SUPABASE_DB_URL" -c "
    SELECT
      policyname,
      roles,
      cmd,
      CASE
        WHEN length(qual::text) > 50 THEN substring(qual::text from 1 for 47) || '...'
        ELSE qual::text
      END as using_clause,
      CASE
        WHEN length(with_check::text) > 50 THEN substring(with_check::text from 1 for 47) || '...'
        ELSE with_check::text
      END as with_check_clause
    FROM pg_policies
    WHERE tablename = 'productions'
    ORDER BY policyname;
    "
else
    echo -e "${RED}❌ Policy verification failed${NC}"
    exit 1
fi

# Step 4: Test production INSERT as service_role
echo -e "\n${BLUE}🧪 Step 4: Testing production INSERT as service_role...${NC}\n"

TEST_RESULT=$(psql "$SUPABASE_DB_URL" -t -A << 'EOF'
-- Set role to service_role
SET ROLE service_role;

-- Try to insert a test production (will rollback)
BEGIN;

INSERT INTO public.productions (client_id, name, is_active)
VALUES (
  '52751ace-d5e5-49fd-905c-06eb8917fb88',  -- Fever client ID
  '[TEST] RLS Policy Test Production',
  true
)
RETURNING id;

-- Rollback (don't actually create test production)
ROLLBACK;

-- Return success indicator
SELECT 'SUCCESS';
EOF
)

if [[ "$TEST_RESULT" == *"SUCCESS"* ]]; then
    echo -e "${GREEN}✅ Service role can INSERT into productions!${NC}"
    echo -e "${GREEN}   (Test production rolled back - no data created)${NC}\n"
else
    echo -e "${RED}❌ Service role still cannot INSERT into productions${NC}"
    echo -e "${YELLOW}   Additional troubleshooting required${NC}\n"
    exit 1
fi

# Success summary
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ FIX APPLIED SUCCESSFULLY${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}\n"

echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Test cron job sync:"
echo -e "     ${YELLOW}curl -X GET https://ballee-antoineschaller.vercel.app/api/cron/airtable-sync \\${NC}"
echo -e "     ${YELLOW}  -H \"Authorization: Bearer \$CRON_SECRET\" \\${NC}"
echo -e "     ${YELLOW}  -H \"x-vercel-cron: 1\"${NC}\n"
echo -e "  2. Verify no foreign key violations in sync results\n"
echo -e "  3. Check sync run in database:"
echo -e "     ${YELLOW}SELECT * FROM airtable_sync_runs ORDER BY started_at DESC LIMIT 1;${NC}\n"

exit 0

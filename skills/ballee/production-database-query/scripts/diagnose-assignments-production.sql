-- Diagnostic Script: Investigate why dancers can't see assignments
-- Run this on production Supabase SQL Editor
-- Dashboard URL: https://supabase.com/dashboard/project/rkxtcmxczrfwccttcewt/sql

-- =============================================================================
-- 1. Verify SELECT policy exists on cast_assignments
-- =============================================================================
SELECT
  '1. RLS Policies on cast_assignments' as check_name,
  policyname,
  cmd,
  CASE
    WHEN cmd = 'SELECT' THEN '✅ SELECT policy exists'
    ELSE '⚠️  Non-SELECT policy'
  END as status
FROM pg_policies
WHERE tablename = 'cast_assignments'
ORDER BY cmd, policyname;

-- =============================================================================
-- 2. Count total cast_assignments in database
-- =============================================================================
SELECT
  '2. Total Cast Assignments' as check_name,
  COUNT(*) as total_assignments,
  COUNT(DISTINCT user_id) as unique_dancers,
  COUNT(DISTINCT event_id) as unique_events,
  CASE
    WHEN COUNT(*) = 0 THEN '❌ No assignments in database'
    WHEN COUNT(*) > 0 THEN '✅ Assignments exist'
  END as status
FROM cast_assignments;

-- =============================================================================
-- 3. Check assignment statuses
-- =============================================================================
SELECT
  '3. Assignment Status Breakdown' as check_name,
  assignment_status,
  COUNT(*) as count,
  CASE
    WHEN assignment_status IN ('pending', 'offered', 'accepted', 'declined')
    THEN '✅ Valid status (query will include)'
    ELSE '⚠️  Status not in query filter'
  END as included_in_query
FROM cast_assignments
GROUP BY assignment_status
ORDER BY count DESC;

-- =============================================================================
-- 4. Check related tables (cast_roles, productions, events)
-- =============================================================================

-- Check cast_roles
SELECT
  '4a. Cast Roles' as check_name,
  COUNT(*) as total_cast_roles,
  COUNT(DISTINCT production_id) as unique_productions,
  CASE
    WHEN COUNT(*) = 0 THEN '❌ No cast roles'
    ELSE '✅ Cast roles exist'
  END as status
FROM cast_roles;

-- Check productions
SELECT
  '4b. Productions' as check_name,
  COUNT(*) as total_productions,
  CASE
    WHEN COUNT(*) = 0 THEN '❌ No productions'
    ELSE '✅ Productions exist'
  END as status
FROM productions;

-- Check events
SELECT
  '4c. Events' as check_name,
  status,
  COUNT(*) as count,
  CASE
    WHEN status = 'open' THEN '✅ Open events (visible to all)'
    ELSE '⚠️  Non-open events'
  END as visibility
FROM events
GROUP BY status
ORDER BY count DESC;

-- =============================================================================
-- 5. Test the actual query from getDancerAssignments
-- =============================================================================

-- This query mimics what the app does
-- Replace <test_user_id> with an actual user_id who should have assignments
SELECT
  '5. Simulated getDancerAssignments Query' as check_name,
  ca.id as assignment_id,
  ca.assignment_status,
  ca.user_id as dancer_id,
  cr.role_name,
  p.name as production_name,
  e.title as event_title,
  e.status as event_status,
  e.start_date_time
FROM cast_assignments ca
INNER JOIN cast_roles cr ON cr.id = ca.cast_role_id
INNER JOIN productions p ON p.id = cr.production_id
INNER JOIN events e ON e.id = ca.event_id
WHERE ca.assignment_status IN ('pending', 'offered', 'accepted', 'declined')
ORDER BY ca.assigned_at DESC
LIMIT 10;

-- =============================================================================
-- 6. Check for orphaned assignments (missing related records)
-- =============================================================================
SELECT
  '6. Orphaned Assignments Check' as check_name,
  COUNT(*) as orphaned_count,
  CASE
    WHEN COUNT(*) = 0 THEN '✅ All assignments have valid relations'
    ELSE '❌ Orphaned assignments found'
  END as status
FROM cast_assignments ca
LEFT JOIN cast_roles cr ON cr.id = ca.cast_role_id
LEFT JOIN events e ON e.id = ca.event_id
WHERE cr.id IS NULL OR e.id IS NULL;

-- =============================================================================
-- 7. Check RLS policies on joined tables
-- =============================================================================
SELECT
  '7. RLS Policies on Joined Tables' as check_name,
  tablename,
  policyname,
  cmd,
  CASE
    WHEN cmd = 'SELECT' THEN '✅ SELECT allowed'
    ELSE '⚠️  Non-SELECT'
  END as status
FROM pg_policies
WHERE tablename IN ('cast_roles', 'productions', 'events')
  AND cmd = 'SELECT'
ORDER BY tablename, policyname;

-- =============================================================================
-- 8. Sample user check (find a user with assignments)
-- =============================================================================
SELECT
  '8. Sample User with Assignments' as check_name,
  ca.user_id,
  p.email,
  COUNT(ca.id) as assignment_count
FROM cast_assignments ca
LEFT JOIN profiles p ON p.id = ca.user_id
GROUP BY ca.user_id, p.email
ORDER BY COUNT(ca.id) DESC
LIMIT 5;

-- =============================================================================
-- 9. Check auth context (run as authenticated user if possible)
-- =============================================================================
SELECT
  '9. Current Auth Context' as check_name,
  auth.uid() as current_user_id,
  auth.role() as current_role,
  CASE
    WHEN auth.uid() IS NULL THEN '⚠️  Running as service_role (bypasses RLS)'
    ELSE '✅ Running as authenticated user (RLS applies)'
  END as rls_status;

-- =============================================================================
-- RECOMMENDATIONS
-- =============================================================================
--
-- If no assignments exist (check #2):
--   → Need to create cast assignments through admin interface
--   → Navigate to: https://flow.ballee.app/admin/events/[event-id]
--
-- If orphaned assignments exist (check #6):
--   → Data integrity issue - fix foreign key relationships
--
-- If all events are not 'open' (check #4c):
--   → Dancers can only see assignments for open events (unless it's their own)
--   → Update event status: UPDATE events SET status = 'open' WHERE ...
--
-- If SELECT policy missing (check #1):
--   → Migration 20251110154725_restore_cast_assignments_select_policy.sql not applied
--   → Apply migration immediately
--
-- If RLS policies missing on joined tables (check #7):
--   → cast_roles, productions, or events don't allow SELECT
--   → Queries will fail even if cast_assignments policy is correct
--

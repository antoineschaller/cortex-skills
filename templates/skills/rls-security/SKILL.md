# Row-Level Security Patterns

Database security patterns for multi-tenant and user-scoped data.

> **Template Usage:** Customize for your database (PostgreSQL, Supabase, etc.) and auth system.

## RLS Fundamentals

### Enable RLS on Tables

```sql
-- Enable RLS (required before policies take effect)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

-- Force RLS for table owners too (recommended)
ALTER TABLE users FORCE ROW LEVEL SECURITY;
```

### Policy Types

```sql
-- SELECT: Who can read rows
CREATE POLICY "Users can view own profile"
ON users FOR SELECT
USING (id = auth.uid());

-- INSERT: Who can create rows
CREATE POLICY "Users can create own posts"
ON posts FOR INSERT
WITH CHECK (user_id = auth.uid());

-- UPDATE: Who can modify rows
CREATE POLICY "Users can update own posts"
ON posts FOR UPDATE
USING (user_id = auth.uid())      -- Which rows can be selected for update
WITH CHECK (user_id = auth.uid()); -- What the row must look like after update

-- DELETE: Who can delete rows
CREATE POLICY "Users can delete own posts"
ON posts FOR DELETE
USING (user_id = auth.uid());

-- ALL: Combines all operations
CREATE POLICY "Users manage own data"
ON user_data FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

## Required Bypass Policies

> **CRITICAL**: Every table needs admin and service role bypasses. Add these FIRST.

### Super Admin Bypass

```sql
-- Function to check super admin status (SECURITY DEFINER bypasses RLS)
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role = 'super_admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Apply to tables (add FIRST before other policies)
DROP POLICY IF EXISTS "super_admin_bypass" ON table_name;
CREATE POLICY "super_admin_bypass" ON table_name
  FOR ALL
  TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());
```

### Service Role Bypass

```sql
-- CRITICAL: Server-side operations need service role access
-- This allows admin SDK, server actions, and background jobs to work
DROP POLICY IF EXISTS "service_role_bypass" ON table_name;
CREATE POLICY "service_role_bypass" ON table_name
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
```

### Why Both Are Needed

| Bypass Type | Used By | Use Case |
|-------------|---------|----------|
| `is_super_admin()` | Authenticated admin users | Admin dashboard, manual operations |
| `service_role` | Backend SDK, server actions | Automated jobs, API routes, migrations |

## Common Patterns

### User Owns Data

```sql
-- Simple ownership
CREATE POLICY "user_owns_row"
ON items FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

### Team/Organization Access

```sql
-- User belongs to team that owns resource
CREATE POLICY "team_member_access"
ON projects FOR ALL
TO authenticated
USING (
  team_id IN (
    SELECT team_id FROM team_members
    WHERE user_id = auth.uid()
  )
)
WITH CHECK (
  team_id IN (
    SELECT team_id FROM team_members
    WHERE user_id = auth.uid()
  )
);
```

### Role-Based Access

```sql
-- Check user role for access
CREATE POLICY "admin_full_access"
ON sensitive_data FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role = 'admin'
  )
);

-- Or with a helper function (preferred)
CREATE OR REPLACE FUNCTION has_role(required_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role = required_role
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE POLICY "admin_access"
ON sensitive_data FOR ALL
TO authenticated
USING (has_role('admin'));
```

### Public Read, Authenticated Write

```sql
-- Anyone can read published content
CREATE POLICY "public_read_published"
ON posts FOR SELECT
TO anon, authenticated
USING (status = 'published');

-- Only authenticated users can create
CREATE POLICY "authenticated_create"
ON posts FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- Only owner can update/delete
CREATE POLICY "owner_update"
ON posts FOR UPDATE
TO authenticated
USING (user_id = auth.uid());
```

## Multi-Tenant Patterns

### Tenant Isolation

```sql
-- Every table has tenant_id
CREATE TABLE items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Get current user's tenant
CREATE OR REPLACE FUNCTION get_user_tenant_id()
RETURNS UUID AS $$
BEGIN
  RETURN (
    SELECT tenant_id FROM users
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Policy enforces tenant isolation
CREATE POLICY "tenant_isolation"
ON items FOR ALL
TO authenticated
USING (tenant_id = get_user_tenant_id())
WITH CHECK (tenant_id = get_user_tenant_id());
```

### Cross-Tenant Admin

```sql
-- Platform admins can access all tenants
CREATE POLICY "platform_admin_access"
ON items FOR ALL
TO authenticated
USING (
  is_platform_admin()
  OR tenant_id = get_user_tenant_id()
)
WITH CHECK (
  is_platform_admin()
  OR tenant_id = get_user_tenant_id()
);
```

## Avoiding Infinite Recursion

> **CRITICAL**: Recursive policies are a common source of production outages.

### Problem: Policy Queries Same Table

```sql
-- BAD: Causes infinite recursion
CREATE POLICY "check_membership"
ON team_members FOR SELECT
USING (
  user_id IN (
    SELECT user_id FROM team_members  -- References same table = INFINITE LOOP
    WHERE team_id = team_members.team_id
  )
);
```

### Solution 1: Use auth.uid() Directly

```sql
-- GOOD: Direct comparison, no subquery
CREATE POLICY "check_membership"
ON team_members FOR SELECT
USING (user_id = auth.uid());
```

### Solution 2: SECURITY DEFINER Function

```sql
-- GOOD: Function bypasses RLS when checking team membership
CREATE OR REPLACE FUNCTION user_team_ids()
RETURNS UUID[] AS $$
BEGIN
  RETURN ARRAY(
    SELECT team_id FROM team_members
    WHERE user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE POLICY "team_access"
ON team_data FOR SELECT
USING (team_id = ANY(user_team_ids()));
```

### Solution 3: Denormalized Arrays (Best Performance)

```sql
-- Store team IDs directly in the user's profile
-- Eliminates subqueries entirely
ALTER TABLE profiles ADD COLUMN team_ids UUID[] DEFAULT '{}';

-- Update on team membership changes
CREATE OR REPLACE FUNCTION sync_user_team_ids()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles
  SET team_ids = ARRAY(
    SELECT team_id FROM team_members WHERE user_id = NEW.user_id
  )
  WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER sync_team_ids_on_membership
AFTER INSERT OR UPDATE OR DELETE ON team_members
FOR EACH ROW EXECUTE FUNCTION sync_user_team_ids();

-- Policy uses denormalized array - no subquery needed
CREATE POLICY "team_access"
ON team_data FOR SELECT
TO authenticated
USING (
  team_id = ANY(
    (SELECT team_ids FROM profiles WHERE id = auth.uid())
  )
);
```

## Common Bugs & Solutions

### Bug 1: Personal vs Team Accounts (MakerKit/SaaS Kits)

**Symptom**: User can create data but can't see it, or sees wrong team's data.

**Root Cause**: User has both personal account AND team account. Query checks `account_id` but user's current session is for wrong account.

```sql
-- BAD: Only checks account_id, doesn't consider which account is active
CREATE POLICY "account_access"
ON items FOR SELECT
USING (
  account_id IN (SELECT id FROM accounts WHERE owner_id = auth.uid())
);

-- GOOD: Check the active account from JWT claims or session
CREATE OR REPLACE FUNCTION get_active_account_id()
RETURNS UUID AS $$
DECLARE
  account_id UUID;
BEGIN
  -- Get from JWT claim (set at login)
  account_id := (current_setting('request.jwt.claims', true)::json->>'account_id')::uuid;

  -- Fallback to primary account
  IF account_id IS NULL THEN
    SELECT id INTO account_id FROM accounts
    WHERE owner_id = auth.uid()
    ORDER BY is_primary DESC, created_at ASC
    LIMIT 1;
  END IF;

  RETURN account_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE POLICY "active_account_access"
ON items FOR SELECT
USING (account_id = get_active_account_id());
```

### Bug 2: Missing WITH CHECK on INSERT

**Symptom**: User can't insert data that they should be able to.

```sql
-- BAD: Only USING clause - affects SELECT/UPDATE/DELETE but not INSERT
CREATE POLICY "user_items"
ON items FOR ALL
USING (user_id = auth.uid());

-- GOOD: WITH CHECK clause required for INSERT/UPDATE
CREATE POLICY "user_items"
ON items FOR ALL
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

### Bug 3: RLS Bypassed by Foreign Key Cascades

**Symptom**: Deleting a parent row deletes child rows even if user doesn't have delete permission on children.

```sql
-- Foreign key cascades bypass RLS!
ALTER TABLE comments
  ADD CONSTRAINT fk_post
  FOREIGN KEY (post_id)
  REFERENCES posts(id)
  ON DELETE CASCADE;  -- This bypasses RLS on comments table

-- Solution: Use soft delete or application-level cascade
-- Or accept that cascades bypass RLS (document this decision)
```

### Bug 4: Service Actions Failing Silently

**Symptom**: Server-side code returns empty results or silent failures.

```sql
-- Check if service_role policy exists
SELECT * FROM pg_policies WHERE tablename = 'items';

-- Missing this policy = server code can't access data
CREATE POLICY "service_role_bypass" ON items
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);
```

## Storage Bucket Security

```sql
-- Supabase storage RLS
CREATE POLICY "Users can upload to own folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can view own files"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'avatars'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Public can view public bucket"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'public');

-- Service role for server operations
CREATE POLICY "Service role full access"
ON storage.objects FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
```

## Debugging RLS Policies

### Check All Policies on a Table

```sql
SELECT
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual AS using_expression,
  with_check
FROM pg_policies
WHERE tablename = 'your_table_name'
ORDER BY policyname;
```

### Test as Specific User

```sql
-- Impersonate a user (Supabase)
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "user-uuid-here", "role": "authenticated"}';

-- Try to access data
SELECT * FROM posts;
SELECT * FROM posts WHERE user_id = 'other-user-uuid';  -- Should return empty

-- Reset
RESET ROLE;
RESET request.jwt.claims;
```

### Explain Query with RLS

```sql
-- See what RLS adds to your query
EXPLAIN (ANALYZE, VERBOSE)
SELECT * FROM posts WHERE status = 'published';
```

### Count Accessible vs Total Rows

```sql
-- As service_role (bypasses RLS)
SELECT COUNT(*) as total_rows FROM posts;

-- As authenticated user
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "user-uuid"}';
SELECT COUNT(*) as accessible_rows FROM posts;
RESET ROLE;
```

### Find Tables Missing RLS

```sql
SELECT
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND rowsecurity = false
ORDER BY tablename;
```

### Find Tables Without Policies

```sql
SELECT t.tablename
FROM pg_tables t
LEFT JOIN pg_policies p ON t.tablename = p.tablename
WHERE t.schemaname = 'public'
AND t.rowsecurity = true
AND p.policyname IS NULL;
```

## Troubleshooting

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `new row violates RLS policy` | INSERT missing WITH CHECK | Add WITH CHECK clause |
| `permission denied for table` | RLS enabled, no matching policy | Add policy or check user role |
| `infinite recursion detected` | Policy queries same table | Use SECURITY DEFINER function |
| `could not serialize access` | Concurrent updates to same row | Use row-level locking |
| Empty results (no error) | Policy filters out all rows | Check USING clause logic |

### Debug Checklist

1. **Check RLS is enabled**: `SELECT rowsecurity FROM pg_tables WHERE tablename = 'x'`
2. **Check policies exist**: `SELECT * FROM pg_policies WHERE tablename = 'x'`
3. **Check user's role**: Is `authenticated` in policy roles?
4. **Check JWT claims**: Does `auth.uid()` return expected value?
5. **Check helper functions**: Do SECURITY DEFINER functions work correctly?
6. **Test as service_role**: Does data exist when RLS is bypassed?

## Testing RLS Policies

### E2E Test Pattern

```typescript
// E2E test for RLS
describe('Posts RLS', () => {
  it('user can only see own posts', async () => {
    // Create post as user A
    const { data: postA } = await supabaseUserA
      .from('posts')
      .insert({ title: 'User A post' })
      .select()
      .single();

    // User B should not see it
    const { data: posts } = await supabaseUserB
      .from('posts')
      .select()
      .eq('id', postA.id);

    expect(posts).toHaveLength(0);
  });

  it('admin can see all posts', async () => {
    const { data: posts } = await supabaseAdmin
      .from('posts')
      .select();

    expect(posts.length).toBeGreaterThan(0);
  });

  it('service role bypasses RLS', async () => {
    // Service role should see everything
    const { data: allPosts } = await supabaseServiceRole
      .from('posts')
      .select();

    expect(allPosts.length).toBeGreaterThan(0);
  });
});
```

### Dual-Client Test Pattern

```typescript
// Test that RLS properly isolates data between users
describe('RLS Isolation', () => {
  const userAClient = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${userAToken}` } }
  });

  const userBClient = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${userBToken}` } }
  });

  it('prevents cross-user data access', async () => {
    // User A creates private data
    const { data: item } = await userAClient
      .from('private_items')
      .insert({ name: 'secret' })
      .select()
      .single();

    // User B tries to read it
    const { data } = await userBClient
      .from('private_items')
      .select()
      .eq('id', item.id);

    expect(data).toHaveLength(0); // User B sees nothing

    // User B tries to update it
    const { error } = await userBClient
      .from('private_items')
      .update({ name: 'hacked' })
      .eq('id', item.id);

    // Should fail or affect 0 rows
    expect(error || data).toBeFalsy();
  });
});
```

## Migration Pattern

```sql
-- Always use idempotent policy creation
DROP POLICY IF EXISTS "user_owns_items" ON items;
CREATE POLICY "user_owns_items"
ON items FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Template for new table with full RLS setup
-- ==================================================
-- Migration: YYYYMMDDHHMMSS_add_items_rls.sql
-- Description: Add RLS policies to items table
-- ==================================================

-- Enable RLS
ALTER TABLE items ENABLE ROW LEVEL SECURITY;

-- 1. Super admin bypass (ALWAYS FIRST)
DROP POLICY IF EXISTS "super_admin_bypass" ON items;
CREATE POLICY "super_admin_bypass" ON items
  FOR ALL TO authenticated
  USING (is_super_admin())
  WITH CHECK (is_super_admin());

-- 2. Service role bypass (for server operations)
DROP POLICY IF EXISTS "service_role_bypass" ON items;
CREATE POLICY "service_role_bypass" ON items
  FOR ALL TO service_role
  USING (true)
  WITH CHECK (true);

-- 3. User-specific policies
DROP POLICY IF EXISTS "user_owns_items" ON items;
CREATE POLICY "user_owns_items" ON items
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 4. Index for policy performance
CREATE INDEX IF NOT EXISTS idx_items_user_id ON items(user_id);
```

## Performance Considerations

```sql
-- Index columns used in RLS policies
CREATE INDEX idx_items_user_id ON items(user_id);
CREATE INDEX idx_team_members_user_id ON team_members(user_id);
CREATE INDEX idx_items_tenant_id ON items(tenant_id);

-- Use STABLE/IMMUTABLE for helper functions
CREATE OR REPLACE FUNCTION get_user_tenant_id()
RETURNS UUID AS $$
  -- Function body
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;  -- STABLE = can be cached per statement

-- Avoid complex subqueries in policies
-- Instead, use helper functions or denormalized arrays

-- Consider materialized roles for complex permission systems
CREATE MATERIALIZED VIEW user_permissions AS
SELECT
  user_id,
  array_agg(DISTINCT permission) as permissions,
  array_agg(DISTINCT team_id) as team_ids
FROM user_roles
GROUP BY user_id;

-- Refresh periodically or on role changes
REFRESH MATERIALIZED VIEW CONCURRENTLY user_permissions;
```

## Related Templates

- See `database-specialist` for migration deployment
- See `auth-patterns` for authentication integration
- See `test-patterns` for comprehensive RLS testing
- See `db-anti-patterns` for query optimization

## Checklist

### Setup
- [ ] RLS enabled on all user-data tables
- [ ] FORCE ROW LEVEL SECURITY on sensitive tables
- [ ] Default deny (no policies = no access)

### Required Policies (Every Table)
- [ ] `super_admin_bypass` policy for admin users
- [ ] `service_role_bypass` policy for server operations
- [ ] User-specific policies for authenticated users

### Policy Coverage
- [ ] SELECT policy for read access
- [ ] INSERT policy with WITH CHECK
- [ ] UPDATE policy with both USING and WITH CHECK
- [ ] DELETE policy where needed

### Security
- [ ] No recursive policy references
- [ ] Helper functions use SECURITY DEFINER
- [ ] Storage buckets have RLS
- [ ] Foreign key cascade implications documented

### Testing
- [ ] Test as different user roles
- [ ] Test cross-tenant access blocked
- [ ] Test admin bypass works
- [ ] Test service role bypass works
- [ ] Test public vs authenticated access

### Performance
- [ ] Indexes on policy columns
- [ ] Helper functions marked STABLE
- [ ] No N+1 in policy subqueries
- [ ] Consider denormalized arrays for complex membership checks

## Rules

1. **Admin First**: Always add `super_admin_bypass` and `service_role_bypass` FIRST
2. **WITH CHECK Required**: INSERT/UPDATE policies need WITH CHECK clause
3. **No Recursion**: Never query the same table in a policy - use SECURITY DEFINER functions
4. **Test Isolation**: Always test that users can't access each other's data
5. **Index Policies**: Create indexes on columns used in USING/WITH CHECK clauses
6. **Document Decisions**: Document why certain data is public or has broader access

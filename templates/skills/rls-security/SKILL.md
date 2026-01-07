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

-- Or with a helper function
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_roles
    WHERE user_id = auth.uid()
    AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE POLICY "admin_access"
ON sensitive_data FOR ALL
TO authenticated
USING (is_admin());
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

### Admin Bypass

```sql
-- Super admin can access everything
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

-- Apply to all tables
CREATE POLICY "super_admin_bypass"
ON users FOR ALL
TO authenticated
USING (is_super_admin())
WITH CHECK (is_super_admin());
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

## Avoiding Recursion

```sql
-- BAD: Recursive policy
CREATE POLICY "check_membership"
ON team_members FOR SELECT
USING (
  user_id IN (
    SELECT user_id FROM team_members  -- References same table!
    WHERE team_id = team_members.team_id
  )
);

-- GOOD: Use auth.uid() directly
CREATE POLICY "check_membership"
ON team_members FOR SELECT
USING (user_id = auth.uid());

-- GOOD: Use SECURITY DEFINER function
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
```

## Testing RLS Policies

```sql
-- Test as specific user
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "user-uuid-here"}';

-- Try to access data
SELECT * FROM posts;

-- Reset
RESET ROLE;
RESET request.jwt.claims;
```

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
});
```

## Migration Pattern

```sql
-- Always use idempotent policy creation
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'items'
    AND policyname = 'user_owns_items'
  ) THEN
    CREATE POLICY "user_owns_items"
    ON items FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

-- Or drop and recreate
DROP POLICY IF EXISTS "user_owns_items" ON items;
CREATE POLICY "user_owns_items"
ON items FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
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
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;  -- STABLE = can be cached

-- Avoid complex subqueries in policies
-- Instead, use helper functions with caching
```

## Checklist

### Setup
- [ ] RLS enabled on all user-data tables
- [ ] FORCE ROW LEVEL SECURITY on sensitive tables
- [ ] Default deny (no policies = no access)

### Policies
- [ ] SELECT policy for read access
- [ ] INSERT policy with WITH CHECK
- [ ] UPDATE policy with both USING and WITH CHECK
- [ ] DELETE policy where needed
- [ ] Admin bypass policy

### Security
- [ ] No recursive policy references
- [ ] Helper functions use SECURITY DEFINER
- [ ] Service role bypasses RLS (for admin operations)
- [ ] Storage buckets have RLS

### Testing
- [ ] Test as different user roles
- [ ] Test cross-tenant access blocked
- [ ] Test admin bypass works
- [ ] Test public vs authenticated access

### Performance
- [ ] Indexes on policy columns
- [ ] Helper functions marked STABLE
- [ ] No N+1 in policy subqueries

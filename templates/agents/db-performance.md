---
name: db-performance
description: Database performance optimization agent. Scans for anti-patterns (N+1 queries, sequential queries, unbounded fetches), analyzes query performance, and auto-fixes safe issues.
tools: Read, Grep, Glob, Bash, Edit
model: haiku
---

# Database Performance Agent

Autonomous agent for detecting and fixing database performance issues.

> **Template Usage:** Customize grep patterns and fix strategies for your ORM (Prisma, Drizzle, TypeORM, etc.).

## Workflow

### Phase 1: Scan for Anti-Patterns

```bash
# N+1 Query Detection
echo "=== N+1 Query Detection ==="

# Query inside forEach/map
grep -rn --include="*.ts" --include="*.tsx" \
  -E "(forEach|\.map)\s*\([^)]*\)\s*=>\s*\{[^}]*await[^}]*(find|select|query)" \
  src/

# Query inside for...of loop
grep -rn --include="*.ts" --include="*.tsx" \
  -E "for\s*\([^)]*of[^)]*\)[^{]*\{[^}]*await[^}]*(find|select|query)" \
  src/

# Prisma-specific patterns
grep -rn --include="*.ts" \
  -E "for.*await.*prisma\." \
  src/
```

```bash
# Sequential Query Detection
echo "=== Sequential Queries ==="

# Multiple independent awaits in sequence
grep -rn --include="*.ts" --include="*.tsx" \
  -B2 -A2 "const.*=.*await" src/ | \
  grep -A2 "const.*=.*await"
```

```bash
# Unbounded Fetch Detection
echo "=== Unbounded Fetches ==="

# findMany without take/limit
grep -rn --include="*.ts" \
  "findMany\s*(\s*)" src/

# findMany with only where (no take)
grep -rn --include="*.ts" \
  "findMany\s*(\s*{[^}]*where[^}]*}\s*)" src/ | \
  grep -v "take:"
```

### Phase 2: Analyze Query Performance

```sql
-- PostgreSQL: Slow queries
SELECT
  query,
  calls,
  mean_time,
  total_time
FROM pg_stat_statements
WHERE mean_time > 100  -- > 100ms
ORDER BY mean_time DESC
LIMIT 20;

-- Missing indexes
SELECT
  schemaname,
  relname AS table,
  seq_scan,
  idx_scan,
  n_live_tup AS rows
FROM pg_stat_user_tables
WHERE seq_scan > idx_scan
  AND n_live_tup > 10000
ORDER BY seq_scan - idx_scan DESC;
```

### Phase 3: Identify Specific Issues

For each detected pattern, analyze:

1. **File and line number**
2. **Query context** (what data is being fetched)
3. **Loop context** (what's iterating)
4. **Relationship** (what joins/includes could help)

### Phase 4: Generate Fixes

#### N+1 Query Fix Template

```typescript
// BEFORE (N+1)
const users = await db.user.findMany();
for (const user of users) {
  user.posts = await db.post.findMany({
    where: { userId: user.id }
  });
}

// AFTER (Batch query)
const users = await db.user.findMany();
const userIds = users.map(u => u.id);

const posts = await db.post.findMany({
  where: { userId: { in: userIds } }
});

const postsByUser = Map.groupBy(posts, p => p.userId);

const usersWithPosts = users.map(user => ({
  ...user,
  posts: postsByUser.get(user.id) || [],
}));

// OR use includes
const usersWithPosts = await db.user.findMany({
  include: { posts: true }
});
```

#### Sequential Query Fix Template

```typescript
// BEFORE (Sequential)
const user = await db.user.findUnique({ where: { id } });
const posts = await db.post.findMany({ where: { userId: id } });
const comments = await db.comment.findMany({ where: { userId: id } });

// AFTER (Parallel)
const [user, posts, comments] = await Promise.all([
  db.user.findUnique({ where: { id } }),
  db.post.findMany({ where: { userId: id } }),
  db.comment.findMany({ where: { userId: id } }),
]);
```

#### Unbounded Fetch Fix Template

```typescript
// BEFORE (Unbounded)
const allUsers = await db.user.findMany();

// AFTER (Paginated)
const users = await db.user.findMany({
  take: 50,
  skip: page * 50,
  orderBy: { createdAt: 'desc' },
});
```

### Phase 5: Auto-Fix Safe Patterns

**Safe to auto-fix:**
- Add `Promise.all` for independent sequential queries
- Add `take: 100` to unbounded findMany calls
- Add missing `orderBy` to paginated queries

**Requires human review:**
- N+1 fixes (may need schema knowledge)
- Complex query restructuring
- Index recommendations

### Phase 6: Generate Report

## Report Format

```markdown
# Database Performance Report

## Summary

| Issue Type | Count | Auto-Fixed | Manual Review |
|------------|-------|------------|---------------|
| N+1 Queries | 5 | 0 | 5 |
| Sequential Queries | 3 | 2 | 1 |
| Unbounded Fetches | 8 | 8 | 0 |
| Missing Indexes | 2 | 0 | 2 |

## Critical Issues

### 1. N+1 Query in UserService

**File:** `src/services/user.service.ts:45`

**Current Code:**
```typescript
const users = await db.user.findMany();
for (const user of users) {
  user.profile = await db.profile.findUnique({
    where: { userId: user.id }
  });
}
```

**Impact:** ~100ms per user, 50 users = 5 seconds

**Recommended Fix:**
```typescript
const users = await db.user.findMany({
  include: { profile: true }
});
```

**Estimated Improvement:** 5000ms → 50ms (100x faster)

---

### 2. Sequential Queries in Dashboard

**File:** `src/pages/dashboard.ts:23`

**Current Code:**
```typescript
const stats = await getStats();
const notifications = await getNotifications();
const recent = await getRecentActivity();
```

**Auto-Fixed To:**
```typescript
const [stats, notifications, recent] = await Promise.all([
  getStats(),
  getNotifications(),
  getRecentActivity(),
]);
```

**Improvement:** 300ms → 100ms (3x faster)

---

## Auto-Fixed Issues

| File | Line | Issue | Fix Applied |
|------|------|-------|-------------|
| `services/post.ts` | 78 | Sequential queries | Promise.all |
| `api/users.ts` | 34 | Unbounded fetch | Added take: 100 |
| `api/posts.ts` | 56 | Unbounded fetch | Added take: 100 |

## Index Recommendations

```sql
-- For slow query in user lookup
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);

-- For dashboard stats query
CREATE INDEX CONCURRENTLY idx_posts_user_created
ON posts(user_id, created_at DESC);
```

## Next Steps

1. [ ] Review N+1 fixes and apply
2. [ ] Test auto-fixed files
3. [ ] Apply index recommendations in migration
4. [ ] Re-run performance scan after changes
```

## Execution Modes

### Full Scan
Scan entire codebase:
```
db-performance --full
```

### Targeted Scan
Scan specific directory:
```
db-performance --path src/services
```

### Audit Only
Report without fixes:
```
db-performance --audit
```

## Rules

1. **Safe Fixes Only**: Only auto-fix patterns that won't change behavior
2. **Document Everything**: Every fix must be documented with before/after
3. **Estimate Impact**: Include performance estimates where possible
4. **Test Required**: All changes require testing before commit
5. **Index Carefully**: Index recommendations need DBA/team review

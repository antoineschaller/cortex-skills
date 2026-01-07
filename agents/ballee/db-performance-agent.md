---
name: db-performance-agent
description: Scans codebase for database performance anti-patterns (N+1 queries, sequential queries, unbounded fetches), analyzes DB stats, and auto-fixes issues. Use when optimizing database performance or before deploying batch operations.
tools: Read, Glob, Grep, Edit, Bash
model: haiku
permissionMode: default
---

# Database Performance Agent

Detect and fix database performance anti-patterns in the codebase.

## Modes

The agent operates in different modes based on the user's request:

| Mode | Description | Actions |
|------|-------------|---------|
| **scan** | Detect anti-patterns | Read-only analysis, report issues |
| **fix** | Auto-fix issues | Apply transformations, verify with typecheck |
| **stats** | Analyze DB | Query production/staging for performance metrics |
| **full** | Complete analysis | Stats + Scan + prioritized recommendations |

## Workflow

### Scan Mode

1. **Identify target files**
   ```bash
   # Priority 1: Cron jobs (highest risk)
   glob "apps/web/app/api/cron/**/route.ts"

   # Priority 2: Services
   glob "apps/web/app/admin/_lib/services/*.ts"
   glob "apps/web/app/admin/**/services/*.ts"

   # Priority 3: Server actions
   glob "apps/web/app/admin/**/actions.ts"
   glob "apps/web/app/home/**/actions.ts"
   ```

2. **Detect anti-patterns** (see db-anti-patterns skill)

   For each file, search for:
   - N+1: `for/forEach/map` with `await.*\.from\(`
   - Sequential: Multiple consecutive `await supabase.from()`
   - Unbounded: `.from('large_table')` without `.limit()` or filter
   - Loop inserts: `for` with `.insert(` or `.update(`

3. **Classify by severity**
   - CRITICAL: N+1 in crons, loop inserts/updates
   - HIGH: N+1 in services, sequential queries
   - MEDIUM: Unbounded fetches, missing Promise.all

4. **Generate report** with file:line references

### Fix Mode

1. Run scan mode first
2. For each fixable issue:

   **N+1 Fix Pattern:**
   ```typescript
   // Before
   for (const item of items) {
     const { data } = await supabase.from('table').select().eq('id', item.id);
   }

   // After
   const ids = items.map(i => i.id);
   const { data: allData } = await supabase.from('table').select().in('id', ids);
   const dataMap = new Map(allData?.map(d => [d.id, d]) ?? []);
   for (const item of items) {
     const data = dataMap.get(item.id);
   }
   ```

   **Sequential → Parallel Fix Pattern:**
   ```typescript
   // Before
   const a = await supabase.from('table_a').select()...;
   const b = await supabase.from('table_b').select()...;

   // After
   const [aResult, bResult] = await Promise.all([
     supabase.from('table_a').select()...,
     supabase.from('table_b').select()...,
   ]);
   const a = aResult;
   const b = bResult;
   ```

   **Loop Insert → Batch Fix Pattern:**
   ```typescript
   // Before
   for (const item of items) {
     await supabase.from('table').insert(item);
   }

   // After
   await supabase.from('table').insert(items);
   ```

3. After each fix, run typecheck to verify

4. Report changes made

### Stats Mode

Query database for performance metrics:

```sql
-- Connection pool status
SELECT state, count(*) FROM pg_stat_activity
WHERE datname = 'postgres' GROUP BY state;

-- Tables with high sequential scans (missing indexes)
SELECT relname, seq_scan, idx_scan,
  ROUND(100.0 * seq_scan / NULLIF(seq_scan + idx_scan, 0), 1) as seq_pct
FROM pg_stat_user_tables
WHERE seq_scan > 100
ORDER BY seq_scan DESC
LIMIT 20;

-- Slow queries (if pg_stat_statements enabled)
SELECT query, calls, mean_exec_time, max_exec_time
FROM pg_stat_statements
WHERE mean_exec_time > 50
ORDER BY total_exec_time DESC
LIMIT 10;
```

Use the `production-database-query` skill for DB access.

### Full Mode

1. Run stats mode
2. Run scan mode
3. Correlate findings:
   - High seq_scan tables → check for queries without proper indexes
   - Slow queries → find corresponding code
4. Prioritize by actual impact

## Report Format

```markdown
# DB Performance Report

**Scanned**: 45 files
**Issues Found**: 12
**Auto-Fixable**: 8

## Critical (3)

### 1. N+1 Query in Cron Job
**File**: `apps/web/app/api/cron/feedback-requests/route.ts:89`
**Pattern**: Query inside `assignments.forEach()` loop
**Impact**: ~200 queries per cron run
**Fix**: Batch fetch with `.in('event_id', eventIds)`
**Auto-fix**: Yes

### 2. ...

## High (5)

...

## Summary

| Severity | Count | Auto-fixable |
|----------|-------|--------------|
| Critical | 3 | 3 |
| High | 5 | 3 |
| Medium | 4 | 2 |

## Recommended Actions

1. Run `/db-perf fix` to auto-fix 8 issues
2. Manual review needed for 4 issues (see details above)
3. Consider adding indexes for tables: venues, productions
```

## Anti-Pattern Detection Reference

See `db-anti-patterns` skill for complete detection rules.

### Quick Detection Commands

```bash
# N+1: for loops with await from()
grep -rn "for\s*(" apps/web --include="*.ts" -A 10 | grep -B5 "await.*\.from\("

# Sequential: consecutive await from() calls
grep -rn "await.*\.from\(" apps/web --include="*.ts" | head -50

# Loop inserts
grep -rn "for\s*(" apps/web --include="*.ts" -A 5 | grep "\.insert\("

# Unbounded on large tables
grep -rn "\.from(['\"]events['\"])" apps/web --include="*.ts" | grep -v "limit\|single\|\.eq\|\.in"
```

## Integration

- Uses `db-anti-patterns` skill for detection rules
- Uses `db-performance-patterns` skill for fix patterns
- Uses `production-database-query` skill for stats mode
- Works alongside `quality-agent` for pre-commit checks

## Execution Notes

1. **Start with high-risk files**: crons > services > actions
2. **Verify fixes**: Always run typecheck after edits
3. **Preserve logic**: Fixes should not change behavior, only performance
4. **Report clearly**: Every issue needs file:line and specific recommendation

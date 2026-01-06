---
name: "sentry-error-manager"
description: "Fetch, analyze, and resolve Sentry errors with CLI integration; use when reviewing production errors, resolving issues, analyzing error patterns, or managing Sentry configuration"
version: "4.0.0"
---

# Sentry Error Manager

## ⚠️ MANDATORY: Document Every Fix on Sentry

**Every Sentry issue that is addressed or fixed MUST be documented with a comment on Sentry itself.** This is non-negotiable.

### Required Checklist (ALL items MUST be completed)

For EVERY Sentry issue you fix, you MUST complete ALL of these steps:

- [ ] **1. Fix the code** and commit with Sentry issue reference
- [ ] **2. Add a comment to the Sentry issue** documenting:
  - Commit hash
  - Files changed
  - Description of the fix
  - Date
- [ ] **3. Update issue status** (resolve if fix is deployed and verified)
- [ ] **4. Verify comment was added** (look for success message with comment ID)

### Command to Add Comment (REQUIRED)

```bash
# REQUIRED after every fix - DO NOT SKIP
./.claude/skills/sentry-error-manager/scripts/sentry.sh comment <issue_id> "🔧 FIX DEPLOYED - $(date +%Y-%m-%d)

Commit: <hash>
File: <path>
Change: <description>

Monitoring for recurrence."
```

### Failure to Comment = Incomplete Work

**A fix is NOT complete until:**
1. The code fix is committed and pushed
2. **A comment exists on the Sentry issue** (verified by success message)
3. The issue status is updated

**If you fix code but forget to comment on Sentry, the task is NOT done. Go back and add the comment before proceeding.**

## When to Use This Skill

Use this skill when:
- Fetching and reviewing Sentry errors
- Resolving, ignoring, or assigning issues
- Adding comments to track investigation progress
- Weekly error reviews and post-deployment verification

## Primary Tool: Shell Script

**Location**: `.claude/skills/sentry-error-manager/scripts/sentry.sh`

This is the **only tool you need** for all Sentry operations. It auto-loads `.env.local` for authentication.

### Quick Start

```bash
# View all unresolved issues
./.claude/skills/sentry-error-manager/scripts/sentry.sh list

# Get details for specific issue
./.claude/skills/sentry-error-manager/scripts/sentry.sh get 7034568465 --events

# Add comment to track progress
./.claude/skills/sentry-error-manager/scripts/sentry.sh comment 7034568465 "🔍 INVESTIGATING"

# Resolve after 3+ days zero recurrence
./.claude/skills/sentry-error-manager/scripts/sentry.sh resolve 7034568465
```

### All Commands

| Category | Command | Description |
|----------|---------|-------------|
| **View** | `list` | List unresolved issues |
| | `list --since 7` | Issues from last 7 days |
| | `get <id> --events` | Issue details with events |
| | `search <query>` | Search by keyword |
| | `stats` | Statistics overview |
| **Manage** | `resolve <id...>` | Mark as resolved |
| | `unresolve <id...>` | Reopen issues |
| | `ignore <id...>` | Ignore/mute issues |
| | `assign <id>` | Assign to Claude Code (3990106) |
| | `unassign <id>` | Remove assignment |
| **Comments** | `comment <id> <text>` | Add comment |
| | `comments <id>` | List all comments |
| | `edit-comment <id> <cmt-id> <text>` | Edit comment |
| | `delete-comment <id> <cmt-id>` | Delete comment |

## Prerequisites

**Environment**: Token is loaded automatically from `.env.local`:
```bash
SENTRY_AUTH_TOKEN=sntryu_...
```

**Get Token**: https://sentry.io/settings/account/api/auth-tokens/

**Required Scopes**: `event:read`, `event:write`, `event:admin`, `project:read`, `project:write`

## Resolution Workflow

### Critical Rules

1. **Wait 3+ days** after fix deployment before resolving
2. **Verify zero recurrence** during that period
3. **Add comments** at each stage (investigating → fix deployed → resolved)
4. **Monitor 7 days** post-resolution for regression

### Decision Tree

```
Is fix deployed to production?
├─ NO → Wait for deployment
└─ YES → Has it been 3+ days since last event?
    ├─ NO → Wait longer
    └─ YES → ✅ Safe to resolve
```

### Comment Templates

```bash
# Start investigation
./.claude/skills/sentry-error-manager/scripts/sentry.sh comment <id> "🔍 INVESTIGATING - $(date +%Y-%m-%d)

Assigned to: Claude Code
Status: Analyzing root cause"

# Fix deployed
./.claude/skills/sentry-error-manager/scripts/sentry.sh comment <id> "🔧 FIX DEPLOYED - $(date +%Y-%m-%d)

Commit: <hash>
File: <path>
Change: <description>

Monitoring for recurrence."

# Resolve
./.claude/skills/sentry-error-manager/scripts/sentry.sh comment <id> "✅ RESOLVED - $(date +%Y-%m-%d)

Reason: 3+ days zero recurrence
Resolved by: Claude Code"
```

## Common Workflows

### Weekly Review

```bash
# 1. List current issues
./.claude/skills/sentry-error-manager/scripts/sentry.sh list

# 2. Check each issue's last seen date
./.claude/skills/sentry-error-manager/scripts/sentry.sh get <id>

# 3. Resolve stale issues (7+ days no recurrence)
./.claude/skills/sentry-error-manager/scripts/sentry.sh resolve <id1> <id2>
```

### Fix and Track

```bash
# 1. Assign and comment
./.claude/skills/sentry-error-manager/scripts/sentry.sh assign 7034568465
./.claude/skills/sentry-error-manager/scripts/sentry.sh comment 7034568465 "🔍 INVESTIGATING - analyzing root cause"

# 2. Fix code, commit with Sentry link
git commit -m "fix: resolve error description

Fixes: https://ballee.sentry.io/issues/7034568465/"

# 3. Comment with fix details
./.claude/skills/sentry-error-manager/scripts/sentry.sh comment 7034568465 "🔧 FIX DEPLOYED - commit abc123"

# 4. Wait 3+ days, then resolve
./.claude/skills/sentry-error-manager/scripts/sentry.sh resolve 7034568465
```

## Error Categories

| Category | Criteria | Action |
|----------|----------|--------|
| **Stale** | Last seen > 7 days | Resolve with comment |
| **Code Bug** | TypeError, ReferenceError | Fix, test, commit |
| **Schema Error** | PostgREST errors | Fix query or migration |
| **External** | Network, third-party | Ignore with comment |
| **Expected** | Rate limiting, validation | Comment as expected |

## Common Error Patterns

| Pattern | Fix |
|---------|-----|
| `auth.users` join error | Use admin client |
| `infinite recursion in policy` | Add `is_super_admin()` bypass |
| `Classes cannot be passed to Client` | Use JSON.parse(JSON.stringify()) |
| `Column not found` | Add migration |
| `ZodError` | Check input matches schema |

## Related Files

- **Treatment Log**: `docs/investigations/sentry-treatment-log.md`
- **Slash Command**: `/sentry` - Quick access
- **Agent**: `sentry-fixer-agent` - Full fix workflow

## Sentry Dashboard

- **URL**: https://ballee.sentry.io/
- **Organization**: ballee
- **Project**: ballee

---

## Implementation Patterns

This section documents how Sentry is configured and integrated in the Ballee codebase.

### Sentry Configuration Files

| File | Purpose |
|------|---------|
| `sentry.client.config.ts` | Browser-side error tracking |
| `sentry.server.config.ts` | Server-side error tracking |
| `sentry.edge.config.ts` | Edge runtime error tracking |
| `instrumentation.ts` | Initializes Sentry based on runtime |

### Error Boundary Hierarchy

Next.js uses `error.tsx` files to catch and handle errors at different route levels:

```
app/
├── error.tsx                    # Root fallback (catches all unhandled)
├── (auth)/error.tsx            # Auth routes
├── (marketing)/error.tsx       # Public marketing pages
├── admin/error.tsx             # Admin section root
│   ├── clients/error.tsx       # Client management
│   ├── events/error.tsx        # Event management
│   └── settings/error.tsx      # Settings
└── home/
    ├── (user)/error.tsx        # Personal account
    │   ├── inbox/error.tsx     # Inbox/chat
    │   └── events/error.tsx    # User events
    └── [account]/error.tsx     # Team account
        ├── events/error.tsx    # Team events
        └── settings/error.tsx  # Team settings
```

### Error Boundary Coverage

**Current coverage**: ~17 error.tsx files across ~118 pages

| Section | Coverage | Error Boundaries |
|---------|----------|------------------|
| Root | Full | `app/error.tsx` |
| Auth | Full | `app/(auth)/error.tsx` |
| Marketing | Full | `app/(marketing)/error.tsx` |
| Admin | Partial | Root + key subsections |
| Home (User) | Partial | Root + inbox/events |
| Home (Team) | Partial | Root + events/settings |

**Gaps**: Some admin subsections rely on parent boundaries. Error propagates up until caught.

### Adding New Error Boundaries

When adding an `error.tsx` to a route:

```tsx
'use client';

import * as Sentry from '@sentry/nextjs';
import { useEffect } from 'react';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Report to Sentry (if not already captured)
    Sentry.captureException(error);
  }, [error]);

  return (
    <div className="flex flex-col items-center justify-center min-h-[400px] gap-4">
      <h2 className="text-xl font-semibold">Something went wrong</h2>
      <p className="text-muted-foreground">{error.message}</p>
      <button
        onClick={reset}
        className="px-4 py-2 bg-primary text-primary-foreground rounded"
      >
        Try again
      </button>
    </div>
  );
}
```

### Server Action Error Handling

Server actions should NOT throw errors directly. Use the Result pattern:

```typescript
// ✅ CORRECT - Returns error in result
export const myAction = withAuth(async (params, data) => {
  try {
    const result = await service.doSomething(data);
    if (!result.success) {
      return { success: false, error: result.error.message };
    }
    return { success: true, data: result.data };
  } catch (error) {
    // Sentry captures via instrumentation
    Sentry.captureException(error);
    return { success: false, error: 'An unexpected error occurred' };
  }
});

// ❌ WRONG - Throws error (causes client-side "Load failed")
export const badAction = withAuth(async (params, data) => {
  const result = await service.doSomething(data);
  if (!result.success) {
    throw new Error(result.error.message); // Don't do this!
  }
  return result.data;
});
```

### Client-Side vs Server-Side Errors

| Error Type | Captured By | Shows In |
|------------|-------------|----------|
| Client JS errors | `sentry.client.config.ts` | Browser errors |
| Server errors | `sentry.server.config.ts` | Server errors |
| Database errors | Server instrumentation | Server errors |
| Network failures | Client (if in browser) | Varies |

### Intermittent Errors

Some errors are environmental and not code bugs:

| Error | Cause | Action |
|-------|-------|--------|
| `TypeError: Load failed` | Network interruption during server action | Monitor, no fix needed |
| `Could not load "util"` | Browser extension conflict | Ignore with comment |
| `Access denied by security policy` | RLS policy correctly blocking | Verify policy is correct |

### Best Practices

1. **Don't over-report**: Error boundaries auto-report to Sentry. Avoid double-reporting.
2. **Use Result pattern**: Server actions return `{ success, data/error }`, not throw.
3. **Add boundaries for critical routes**: User-facing pages that handle payments, data entry.
4. **Log context**: Include relevant IDs in error metadata for debugging.
5. **Test RLS errors**: Some "errors" are RLS working correctly.

### Quick Reference

```bash
# Check if route has error boundary
ls apps/web/app/path/to/route/error.tsx

# Find all error boundaries
find apps/web/app -name "error.tsx" | head -20

# View Sentry config
cat apps/web/sentry.client.config.ts
```

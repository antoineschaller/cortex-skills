---
name: sentry-fixer-agent
description: Autonomous agent for fixing Sentry production errors. Fetches issues, assigns to self, investigates root causes, implements fixes, comments with commit links, and tracks status. Use when handling production errors systematically.
tools: Task, Read, Write, Edit, Glob, Grep, Bash
model: sonnet
permissionMode: default
skills: sentry-error-manager
---

# Sentry Fixer Agent

Systematically analyze production errors, assign ownership, investigate root causes, implement fixes, and document all actions with commit links.

## ⚠️ MANDATORY: Document Every Fix on Sentry

**Every Sentry issue that is addressed or fixed MUST be documented with a comment on Sentry itself.** This is non-negotiable.

### Required Checklist (ALL items MUST be completed)

Before marking ANY Sentry fix as complete, you MUST:

- [ ] **1. Add a comment to the Sentry issue** with:
  - Commit hash
  - Files changed
  - Description of the fix
  - Date
- [ ] **2. Resolve or update issue status** (if fix is deployed)
- [ ] **3. Confirm comment was added** (check for success message)

**Command to add comment:**
```bash
./.claude/skills/sentry-error-manager/scripts/sentry.sh comment <id> "🔧 FIX DEPLOYED - $(date +%Y-%m-%d)

Commit: <hash>
File: <path>
Change: <description>

Monitoring for recurrence."
```

### Failure to Comment = Incomplete Work

**A fix is NOT complete until:**
1. The code fix is committed and pushed
2. A comment exists on the Sentry issue documenting the fix
3. The issue status is updated (resolved/monitoring)

**If you forget to comment, you MUST go back and add it before moving to the next task.**

## When to Use This Agent

Use the sentry-fixer-agent when:
- Fixing specific Sentry errors that require code changes
- Performing comprehensive error investigation and remediation
- Following the full lifecycle: assign → investigate → fix → commit → comment → monitor

**For simpler tasks, use:**
- `/sentry` slash command - Quick issue listing and analysis
- `./apps/web/scripts/sentry.sh` - CLI operations (list, resolve, stats)
- `pnpm sentry:automate` - Automated lifecycle for stale issues
- `sentry-error-manager` skill - Reference documentation

## Environment Setup

```bash
# Load token from environment
source apps/web/.env.local 2>/dev/null
SENTRY_TOKEN="${SENTRY_AUTH_TOKEN}"
```

**Claude Code User ID**: `3990106` - Used for issue assignment

## Complete Workflow

### Phase 1: Fetch & Assign

```bash
# 1. List unresolved issues (choose one method)
./apps/web/scripts/sentry.sh list                                    # Shell script
sentry-cli issues list --org ballee --project ballee                 # CLI

# 2. Assign issue to Claude Code (user ID: 3990106)
ISSUE_ID="<issue_id>"
curl -s -X PUT \
  "https://sentry.io/api/0/organizations/ballee/issues/$ISSUE_ID/" \
  -H "Authorization: Bearer $SENTRY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"assignedTo": "user:3990106"}'

# 3. Add investigation comment
curl -s -X POST \
  "https://sentry.io/api/0/issues/$ISSUE_ID/comments/" \
  -H "Authorization: Bearer $SENTRY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"text": "🔍 INVESTIGATING - '"$(date +%Y-%m-%d)"'\n\nAssigned to: Claude Code\nStatus: Analyzing root cause"}'
```

### Phase 2: Investigate & Fix

1. **Analyze Error**: Read stack trace, identify affected files
2. **Search Codebase**: Find root cause using Grep/Glob
3. **Implement Fix**: Apply appropriate fix pattern
4. **Test**: Run `pnpm typecheck` and relevant tests
5. **Log**: Update treatment log

### Phase 3: Commit & Link

After fixing, commit with a message that references the Sentry issue:

```bash
# Commit format - include Sentry ID in commit message
git add <files>
git commit -m "fix: resolve Sentry error BALLEE-XX - <description>

Fixes: https://ballee.sentry.io/issues/<issue_id>/

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Get the commit hash
COMMIT_HASH=$(git rev-parse --short HEAD)
```

### Phase 4: Comment with Commit Link

```bash
ISSUE_ID="<issue_id>"
COMMIT_HASH="<hash>"
FILES_CHANGED="<file1>, <file2>"
FIX_DESCRIPTION="<what was fixed>"

curl -s -X POST \
  "https://sentry.io/api/0/issues/$ISSUE_ID/comments/" \
  -H "Authorization: Bearer $SENTRY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "🔧 FIX COMMITTED - '"$(date +%Y-%m-%d)"'\n\n**Commit**: '"$COMMIT_HASH"'\n**Files**: '"$FILES_CHANGED"'\n**Change**: '"$FIX_DESCRIPTION"'\n**Branch**: '"$(git branch --show-current)"'\n**Link**: https://github.com/antoineschaller/ballee/commit/'"$COMMIT_HASH"'\n\n⏳ Monitoring for 3+ days before resolving."
  }'
```

### Phase 5: Resolve (After 3+ Days)

After confirming zero recurrence for 3+ days:

```bash
# Add resolution comment
curl -s -X POST \
  "https://sentry.io/api/0/issues/$ISSUE_ID/comments/" \
  -H "Authorization: Bearer $SENTRY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"text": "✅ RESOLVED - '"$(date +%Y-%m-%d)"'\n\nReason: 3+ days zero recurrence after fix\nCommit: '"$COMMIT_HASH"'\nResolved by: Claude Code"}'

# Resolve the issue
sentry-cli issues resolve --org ballee --project ballee --id $ISSUE_ID
```

## Treatment Log

**Location**: `docs/investigations/sentry-treatment-log.md`

Every action MUST be logged:

```markdown
## [YYYY-MM-DD HH:MM] Issue #<ID> (BALLEE-XX)

**Error**: <title>
**Route**: <route>
**Events**: <count>, <users> affected
**Assigned**: Claude Code

### Analysis
<root cause description>

### Action Taken
- **Status**: Fixed | Resolved (stale) | Ignored | Deferred
- **Fix**: <description>
- **Commit**: <hash> - <message>
- **Files Modified**:
  - path/to/file.ts
- **PR**: #<number> (if applicable)

### Sentry Comments Added
- 🔍 Investigation started
- 🔧 Fix committed: <hash>
- ✅ Resolved (after 3+ days)

---
```

## Issue Categorization

| Category | Criteria | Action |
|----------|----------|--------|
| **Stale** | Last seen > 7 days, low events | Resolve, log as "stale" |
| **Code Bug** | TypeError, ReferenceError, etc. | Investigate, fix, test, commit |
| **Schema/Query** | PostgREST errors, column not found | Fix query or add migration |
| **RLS/Database** | Infinite recursion, missing policies | Fix via migration |
| **External** | Network, third-party issues | Log as "ignored" |
| **Expected** | Rate limiting, validation | Comment as expected behavior |

## Comment Templates

### Investigation Started
```
🔍 INVESTIGATING - YYYY-MM-DD

Assigned to: Claude Code
Status: Analyzing root cause
Files under review: <list>
```

### Fix Committed
```
🔧 FIX COMMITTED - YYYY-MM-DD

**Commit**: <hash>
**Files**: <file1>, <file2>
**Change**: <description>
**Branch**: <branch>
**Link**: https://github.com/antoineschaller/ballee/commit/<hash>

⏳ Monitoring for 3+ days before resolving.
```

### Resolved
```
✅ RESOLVED - YYYY-MM-DD

Reason: 3+ days zero recurrence after fix
Commit: <hash>
Resolved by: Claude Code
```

### Expected Behavior
```
ℹ️ EXPECTED BEHAVIOR - YYYY-MM-DD

This error is expected and does not require a code fix.
Reason: <explanation>
```

### Won't Fix
```
❌ WON'T FIX - YYYY-MM-DD

Reason: <explanation>
```

## Common Error Patterns

| Pattern | Fix |
|---------|-----|
| `auth.users` join error | Use admin client or separate query |
| `infinite recursion in policy` | Add `is_super_admin()` bypass |
| `Classes cannot be passed to Client` | Serialize with JSON.parse(JSON.stringify()) |
| `invalid input syntax for integer` | `Math.round(parseFloat(input))` |
| `ZodError` | Check input matches schema |
| `Multiple relationships found` | Use explicit FK hint or separate query |
| `Column not found` | Check schema, add migration if needed |
| `hasOwnProperty undefined` | Sanitize objects for @react-pdf/renderer |

## Output Summary

At the end of a session, provide this summary:

```markdown
## Sentry Fix Summary - YYYY-MM-DD

**Processed**: X | **Fixed**: X | **Stale**: X | **Ignored**: X | **Deferred**: X

### Fixes Applied
| Issue ID | Short ID | Error | Commit | Status |
|----------|----------|-------|--------|--------|
| 7092088756 | BALLEE-3E | hire_orders relationship | abc123 | ⏳ Monitoring |

### Files Modified
- apps/web/app/admin/hire-orders/_lib/server/actions.ts
- ...

### Sentry Comments Added
- 5 investigation comments (🔍)
- 3 fix committed comments (🔧)
- 2 resolved comments (✅)

### Follow-up Required
- #ID - Needs deployment before monitoring
- #ID - Recurring issue, needs deeper investigation
```

## Rules

1. **Assign first** - Always assign to Claude Code (user:3990106) before investigating
2. **Comment everything** - Every action gets a Sentry comment (🔍, 🔧, ✅)
3. **Link commits** - Always include commit hash and GitHub link in fix comment
4. **Log locally** - Update `docs/investigations/sentry-treatment-log.md` for every issue
5. **Wait to resolve** - 3+ days monitoring before marking resolved
6. **Test fixes** - Run `pnpm typecheck` and relevant tests
7. **Complete all issues** - No partial implementations
8. **Use correct org/project** - Always `--org ballee --project ballee`

## Related Tools

| Tool | Purpose | Location |
|------|---------|----------|
| Shell Script | CLI operations | `apps/web/scripts/sentry.sh` |
| Slash Command | Quick analysis | `/sentry` |
| Automation | Lifecycle management | `pnpm sentry:automate` |
| Skill | Reference docs | `sentry-error-manager` |
| Treatment Log | Issue history | `docs/investigations/sentry-treatment-log.md` |
| State Database | Automation state | `docs/investigations/sentry-state.json` |

## Sentry Dashboard

- **Organization**: ballee
- **Project**: ballee
- **URL**: https://ballee.sentry.io/
- **Auth Tokens**: https://sentry.io/settings/account/api/auth-tokens/

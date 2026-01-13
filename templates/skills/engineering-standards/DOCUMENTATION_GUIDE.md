# Documentation Guide

Comprehensive guide for organizing and managing project documentation, including WIP files, guides, architecture documents, and investigations.

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [WIP File Management](#wip-file-management)
- [Permanent Documentation](#permanent-documentation)
- [Naming Conventions](#naming-conventions)
- [Validation & Enforcement](#validation--enforcement)
- [Best Practices](#best-practices)

## Overview

### Documentation Philosophy

**Location-Based Classification**: Where a document lives determines its purpose and retention policy.

```
docs/
├── wip/
│   ├── active/          # Temporary work-in-progress (max 7 days)
│   └── completed/       # Archived WIPs (historical reference)
├── guides/              # Permanent how-to documentation
├── architecture/        # Design decisions and ADRs
├── investigations/      # Completed research and analysis
└── features/            # Feature-specific documentation
    └── {feature-name}/
```

**Key Principles**:
1. **Temporary vs Permanent** - WIP files are ephemeral, guides are permanent
2. **Structured Naming** - Conventions enforce discoverability
3. **Staleness Detection** - Automated validation prevents outdated docs
4. **Forbidden Patterns** - Root MD files blocked (except CLAUDE.md, README.md)
5. **No Deferred Work** - Complete all items before archiving WIPs

## Directory Structure

### Complete Structure

```
project/
├── CLAUDE.md                   # Project instructions (root only)
├── README.md                   # Project overview (root only)
├── docs/
│   ├── wip/
│   │   ├── active/             # Active WIPs (< 7 days old)
│   │   │   ├── WIP_fixing_email_bug_2026_01_13.md
│   │   │   ├── WIP_implementing_dark_mode_2026_01_12.md
│   │   │   └── BUG_INVESTIGATION_slow_queries_2026_01_10.md
│   │   └── completed/          # Archived WIPs (historical)
│   │       └── WIP_user_auth_refactor_2025_12_20.md
│   ├── guides/                 # How-to guides
│   │   ├── getting-started.md
│   │   ├── deployment.md
│   │   └── seo-best-practices.md
│   ├── architecture/           # Architecture Decision Records (ADRs)
│   │   ├── adr-001-database-choice.md
│   │   ├── adr-002-auth-strategy.md
│   │   └── monorepo-structure.md
│   ├── investigations/         # Completed research
│   │   ├── performance-analysis-2025-12.md
│   │   └── api-alternatives-comparison.md
│   └── features/               # Feature-specific docs
│       ├── authentication/
│       │   ├── flows.md
│       │   └── rls-policies.md
│       └── payments/
│           ├── stripe-integration.md
│           └── webhook-handling.md
└── apps/
    └── web/
        └── CLAUDE.md           # Package-specific instructions
```

### Decision Tree

**Where should this document go?**

```
Is this temporary work (in progress)?
├─ Yes → Is it a bug investigation?
│  ├─ Yes → docs/wip/active/BUG_INVESTIGATION_{description}_{YYYY_MM_DD}.md
│  └─ No → docs/wip/active/WIP_{gerund}_{YYYY_MM_DD}.md
└─ No → Continue...

Is this a how-to guide?
├─ Yes → docs/guides/{kebab-case}.md
└─ No → Continue...

Is this an architecture decision?
├─ Yes → docs/architecture/{kebab-case}.md or adr-{number}-{title}.md
└─ No → Continue...

Is this completed research?
├─ Yes → docs/investigations/{description}-{YYYY-MM}.md
└─ No → Continue...

Is this feature-specific?
├─ Yes → docs/features/{feature-name}/{kebab-case}.md
└─ No → Root README.md or CLAUDE.md
```

## WIP File Management

### Naming Convention

**Format**: `WIP_{gerund}_{YYYY_MM_DD}.md` or `BUG_INVESTIGATION_{description}_{YYYY_MM_DD}.md`

**Gerund Form** (action in progress):
- ✅ `WIP_fixing_email_bug_2026_01_13.md`
- ✅ `WIP_implementing_dark_mode_2026_01_12.md`
- ✅ `WIP_refactoring_auth_service_2026_01_10.md`
- ❌ `WIP_email_bug_2026_01_13.md` (not a gerund)
- ❌ `fixing_email_bug.md` (missing WIP prefix and date)
- ❌ `WIP_dark_mode.md` (missing date)

**Bug Investigation Format**:
- ✅ `BUG_INVESTIGATION_slow_queries_2026_01_13.md`
- ✅ `BUG_INVESTIGATION_memory_leak_2026_01_12.md`
- ❌ `BUG_slow_queries.md` (use full BUG_INVESTIGATION prefix)

### Required Sections

**Every WIP file MUST include**:

```markdown
# WIP: Fixing Email Bug

**Last Updated**: 2026-01-13
**Target Completion**: 2026-01-15
**Assignee**: @username
**Related Issue**: #123

## Objective

[Clear, 1-2 sentence description of what this WIP aims to accomplish]

## Progress Tracker

- [x] Identify root cause
- [x] Write failing test
- [ ] Implement fix
- [ ] Update documentation
- [ ] Deploy to staging

## Context

[Background information, why this work is needed]

## Approach

[Technical approach, decisions made]

## Open Questions

- [ ] Should we notify users about the fix?
- [ ] Do we need a migration?

## Testing

[How to test the changes]

## Notes

[Any additional notes, gotchas, or learnings]
```

### Staleness Validation

**7-Day Maximum Age**:

```bash
# Pre-commit hook validation
if [ $(find "$file" -mtime +7 | wc -l) -gt 0 ]; then
  echo "⚠️  WIP file is stale (>7 days): $file"
  echo "   Update the file or move to docs/wip/completed/"
  exit 1
fi
```

**Actions When Stale**:
1. **Update and continue** - Refresh "Last Updated" timestamp
2. **Complete and archive** - Move to `docs/wip/completed/`
3. **Abandon** - Delete if no longer relevant

### Forbidden Patterns

**NEVER include these in WIPs**:

❌ "Deferred" - Complete all work or don't claim completion
❌ "TODO" - Convert TODOs to Progress Tracker items
❌ "Out of scope" - If scoped correctly, nothing should be out of scope
❌ "Will do later" - Either do it now or create a separate WIP

**Enforcement**:
```bash
# Pre-commit hook
if grep -qiE 'deferred|TODO|out of scope|will do later' "$file"; then
  echo "❌ Forbidden patterns detected in WIP: $file"
  exit 1
fi
```

### Archiving Completed WIPs

**When to Archive**:
- All Progress Tracker items completed
- Changes merged to main
- No pending follow-up work

**Process**:
```bash
# Move to completed
mv docs/wip/active/WIP_fixing_email_bug_2026_01_13.md \
   docs/wip/completed/

# Update "Last Updated" and add completion note
echo "\n**Completed**: 2026-01-15\n**PR**: #456" >> \
   docs/wip/completed/WIP_fixing_email_bug_2026_01_13.md
```

### WIP Lifecycle

```
1. Create WIP
   ↓
2. Work in Progress (update Last Updated daily)
   ↓
3. Complete Work (all Progress Tracker items checked)
   ↓
4. Archive to docs/wip/completed/
   ↓
5. Delete after 90 days (optional, for historical reference)
```

## Permanent Documentation

### Guides (docs/guides/)

**Purpose**: How-to documentation for common tasks.

**Naming**: `{kebab-case}.md`

**Examples**:
- `getting-started.md` - Onboarding new developers
- `deployment.md` - How to deploy to production
- `seo-best-practices.md` - SEO implementation guide
- `troubleshooting-common-issues.md` - FAQ and solutions

**Structure**:
```markdown
# Guide Title

## Overview

[Brief description of what this guide covers]

## Prerequisites

- Requirement 1
- Requirement 2

## Steps

### Step 1: [Action]

[Detailed instructions]

\`\`\`bash
# Commands
\`\`\`

### Step 2: [Action]

[More instructions]

## Troubleshooting

| Issue | Solution |
|-------|----------|

## Related

- [Related Guide](./related-guide.md)
```

### Architecture (docs/architecture/)

**Purpose**: Document design decisions and system architecture.

**Naming**: `adr-{number}-{title}.md` or `{kebab-case}.md`

**ADR Template**:
```markdown
# ADR-001: Database Choice

**Status**: Accepted
**Date**: 2026-01-13
**Deciders**: Engineering Team

## Context

[What is the issue we're trying to solve?]

## Decision

[What is the change we're proposing/making?]

## Consequences

**Positive**:
- Benefit 1
- Benefit 2

**Negative**:
- Trade-off 1
- Trade-off 2

## Alternatives Considered

### Option 1: [Name]
**Pros**: ...
**Cons**: ...
**Why not**: ...

### Option 2: [Name]
**Pros**: ...
**Cons**: ...
**Why not**: ...
```

### Investigations (docs/investigations/)

**Purpose**: Document completed research and analysis.

**Naming**: `{description}-{YYYY-MM}.md`

**Examples**:
- `performance-analysis-2025-12.md`
- `api-alternatives-comparison-2026-01.md`
- `database-query-optimization-2025-11.md`

**Structure**:
```markdown
# Investigation: Performance Analysis

**Date**: 2025-12-15
**Investigator**: @username
**Duration**: 2 weeks

## Summary

[TL;DR of findings]

## Objective

[What were we trying to find out?]

## Methodology

[How did we investigate?]

## Findings

### Finding 1
[Details]

### Finding 2
[Details]

## Recommendations

1. Action 1
2. Action 2

## Data

[Links to metrics, logs, or supporting data]

## Follow-up Actions

- [ ] Action item 1 (created issue #123)
- [ ] Action item 2 (created issue #124)
```

### Feature Documentation (docs/features/)

**Purpose**: Document feature-specific implementation details.

**Structure**:
```
docs/features/
├── authentication/
│   ├── README.md           # Feature overview
│   ├── flows.md            # Auth flows diagram and explanation
│   ├── rls-policies.md     # RLS policy documentation
│   └── api.md              # API endpoints
└── payments/
    ├── README.md
    ├── stripe-integration.md
    └── webhook-handling.md
```

## Naming Conventions

### File Names

| Type | Pattern | Example |
|------|---------|---------|
| WIP (active) | `WIP_{gerund}_{YYYY_MM_DD}.md` | `WIP_fixing_bug_2026_01_13.md` |
| Bug Investigation | `BUG_INVESTIGATION_{desc}_{YYYY_MM_DD}.md` | `BUG_INVESTIGATION_memory_leak_2026_01_13.md` |
| Guide | `{kebab-case}.md` | `getting-started.md` |
| Architecture | `adr-{number}-{title}.md` | `adr-001-database-choice.md` |
| Investigation | `{description}-{YYYY-MM}.md` | `performance-analysis-2025-12.md` |
| Feature | `{feature}/{kebab-case}.md` | `authentication/flows.md` |

### Forbidden Patterns

❌ Root MD files (except CLAUDE.md, README.md):
- `EMAIL_BUG.md` → Move to `docs/wip/active/WIP_fixing_email_bug_2026_01_13.md`
- `DEPLOYMENT_NOTES.md` → Move to `docs/guides/deployment.md`
- `QA_CHECKLIST.md` → Move to `docs/guides/qa-checklist.md`

**Pre-commit hook blocks these**:
```bash
root_md=$(git diff --cached --name-only --diff-filter=A | \
  grep -E '^[^/]+\.md$' | \
  grep -v -E '^(CLAUDE|README)\.md$' || true)

if [ -n "$root_md" ]; then
  echo "❌ Markdown files in repo root (forbidden)"
  exit 1
fi
```

**Claude Code PreToolUse hook blocks these**:
```json
{
  "matcher": "Write",
  "hooks": [
    {
      "command": "if [[ \"$ext\" == \"md\" ]] && [[ \"$parent\" == \"$repo_root\" ]] && [[ \"$base\" != \"CLAUDE.md\" ]] && [[ \"$base\" != \"README.md\" ]]; then echo 'BLOCKED: Cannot create .md files in repo root' && exit 1; fi"
    }
  ]
}
```

## Validation & Enforcement

### Pre-Commit Hook

**Script** (`scripts/validate-wip.sh`):
```bash
#!/bin/bash
# Validate WIP files

for file in "$@"; do
  # Check naming convention
  if ! echo "$file" | grep -qE 'WIP_[a-z_]+_[0-9]{4}_[0-9]{2}_[0-9]{2}\.md|BUG_INVESTIGATION_[a-z_]+_[0-9]{4}_[0-9]{2}_[0-9]{2}\.md'; then
    echo "❌ Invalid WIP filename: $file"
    echo "   Expected: WIP_{gerund}_{YYYY_MM_DD}.md"
    exit 1
  fi

  # Check required sections
  for section in "Last Updated" "Target Completion" "Objective" "Progress Tracker"; do
    if ! grep -q "## $section" "$file"; then
      echo "❌ Missing required section '$section' in: $file"
      exit 1
    fi
  done

  # Check staleness (modified within last 7 days)
  if [ $(find "$file" -mtime +7 | wc -l) -gt 0 ]; then
    echo "⚠️  WIP file is stale (>7 days): $file"
    echo "   Update the file or move to docs/wip/completed/"
    exit 1
  fi

  # Check for forbidden patterns
  if grep -qiE 'deferred|will do later|out of scope' "$file"; then
    echo "❌ Forbidden patterns in WIP: $file"
    echo "   Remove: 'deferred', 'will do later', 'out of scope'"
    exit 1
  fi
done

echo "✅ WIP validation passed"
```

**Lefthook Configuration**:
```yaml
pre-commit:
  commands:
    validate-wip:
      glob: 'docs/wip/active/WIP_*.md'
      run: bash scripts/validate-wip.sh {staged_files}
      fail_text: 'WIP validation failed'

    block-root-md-files:
      glob: '*.md'
      run: bash scripts/block-root-md-files.sh
      fail_text: 'Documentation files in repo root - move to docs/'
```

### Claude Code Hooks

**PreToolUse Hook** (blocks root MD files):
```json
{
  "matcher": "Write",
  "hooks": [
    {
      "type": "command",
      "command": "file=\"$CLAUDE_TOOL_INPUT_file_path\"; ext=\"${file##*.}\"; parent=$(dirname \"$file\"); repo_root=\"/path/to/repo\"; if [[ \"$ext\" == \"md\" ]] && [[ \"$parent\" == \"$repo_root\" ]] && [[ \"$base\" != \"CLAUDE.md\" ]] && [[ \"$base\" != \"README.md\" ]]; then echo '❌ BLOCKED: Cannot create .md files in repo root. Use docs/wip/active/ or docs/guides/' && exit 1; fi"
    }
  ]
}
```

## Best Practices

### 1. One WIP Per Task

❌ **Bad** (multiple unrelated tasks):
```markdown
# WIP: Various Fixes

- Fix email bug
- Update deployment docs
- Refactor auth service
```

✅ **Good** (focused WIP):
```markdown
# WIP: Fixing Email Bug

[Focused on single task]
```

### 2. Update Frequently

**Daily Updates** for active WIPs:
```markdown
**Last Updated**: 2026-01-13 (updated daily)

## Progress Tracker

- [x] Identify root cause (2026-01-11)
- [x] Write failing test (2026-01-12)
- [ ] Implement fix (in progress)
```

### 3. Use Progress Tracker

**Convert TODOs to trackable items**:

❌ **Bad**:
```markdown
TODO: Write tests
TODO: Update docs
TODO: Deploy to staging
```

✅ **Good**:
```markdown
## Progress Tracker

- [x] Implement feature
- [ ] Write tests
- [ ] Update documentation
- [ ] Deploy to staging
- [ ] Monitor for 24h
```

### 4. Cross-Reference Issues

**Link to GitHub issues**:
```markdown
**Related Issue**: #123
**PR**: #456

## Context

This WIP addresses the email delivery bug reported in #123.
See discussion in #120 for background.
```

### 5. Document Open Questions

**Track blockers and decisions**:
```markdown
## Open Questions

- [ ] Should we notify users about the migration? (blocked on PM)
- [x] Do we need a feature flag? (YES - decided 2026-01-12)
- [ ] What's the rollback plan? (needs discussion)
```

### 6. Include Testing Instructions

**Make it easy to verify changes**:
```markdown
## Testing

### Local Testing
\`\`\`bash
pnpm test:email
\`\`\`

### Manual Testing
1. Navigate to /profile
2. Click "Send Test Email"
3. Verify email arrives within 30s

### Staging
Deployed to staging: https://staging.example.com
Test account: test@example.com / password123
```

### 7. Archive Promptly

**Don't let completed WIPs linger**:

```bash
# Immediately after PR merge
git pull origin main
mv docs/wip/active/WIP_fixing_email_bug_2026_01_13.md \
   docs/wip/completed/

# Add completion metadata
cat >> docs/wip/completed/WIP_fixing_email_bug_2026_01_13.md << EOF

---

**Completed**: 2026-01-15
**PR**: #456
**Deployed**: 2026-01-15 14:30 UTC
EOF

git add docs/wip/
git commit -m "docs: archive completed WIP for email bug fix"
```

### 8. Clean Up Periodically

**Quarterly cleanup**:
```bash
# Delete WIPs older than 90 days from completed/
find docs/wip/completed/ -name "WIP_*.md" -mtime +90 -delete

# Or archive to separate repo/storage
tar -czf wip-archive-$(date +%Y-%m).tar.gz docs/wip/completed/
rm -rf docs/wip/completed/*.md
```

---

**Last Updated**: 2026-01-13
**Related**: [CLAUDE_MD_GUIDE.md](CLAUDE_MD_GUIDE.md), [HOOKS_GUIDE.md](HOOKS_GUIDE.md)

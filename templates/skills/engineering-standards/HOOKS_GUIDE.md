# Hooks Guide

Comprehensive guide for Git hooks (Lefthook) and Claude Code hooks, ensuring code quality, consistency, and production safety through automated validation at commit and push time.

## Table of Contents

- [Overview](#overview)
- [Pre-Commit Hooks](#pre-commit-hooks)
- [Pre-Push Hooks](#pre-push-hooks)
- [Claude Code Hooks](#claude-code-hooks)
- [Lefthook Configuration](#lefthook-configuration)
- [Project-Specific Examples](#project-specific-examples)
- [Troubleshooting](#troubleshooting)

## Overview

### Hook Philosophy

**Fail Fast, Fail Clear**: Hooks provide immediate feedback on code issues before they reach CI/CD or production.

**Performance Targets**:
- Pre-commit: **< 2 seconds** (run on every commit)
- Pre-push: **< 60 seconds** (run before push to remote)
- THOROUGH mode: **~5 minutes** (comprehensive checks, opt-in)

**Key Principles**:
1. **Parallel execution** - Run independent checks simultaneously
2. **Auto-fix where safe** - Format issues automatically (Prettier)
3. **Clear error messages** - Include fix instructions in failure output
4. **Selective validation** - Only check staged/modified files when possible
5. **Escape hatches** - `--no-verify` for emergencies (document usage)

### Tool Stack

| Tool | Purpose | Speed |
|------|---------|-------|
| **Lefthook** | Git hook manager | Fast, parallel execution |
| **Prettier** | Code formatting | Auto-fix in <500ms |
| **Oxlint** | Fast linting | 10-100x faster than ESLint |
| **ESLint** | Full linting | Comprehensive but slower (THOROUGH mode) |
| **TypeScript** | Type checking | Affected packages only (~30-60s) |
| **Custom scripts** | Domain-specific validation | Project-specific |

## Pre-Commit Hooks

**Goal**: Prevent obvious issues from being committed (<2s execution time).

### 1. Format Staged Files

**Purpose**: Auto-format code with Prettier before commit.

```yaml
format:
  glob: '*.{js,jsx,ts,tsx,mjs,cjs,json,md,mdx,css,yml,yaml}'
  run: |
    export PATH="/Users/{{USER}}/.nvm/versions/node/v{{NODE_VERSION}}/bin:$PATH"
    pnpm prettier --write {staged_files} && git add {staged_files}
  stage_fixed: true
```

**Patterns**:
- Auto-fixes formatting issues
- Re-stages fixed files automatically
- Covers code, markdown, config files

**Customization**:
```yaml
# Add more file types
glob: '*.{js,jsx,ts,tsx,json,md,graphql,sql}'

# Use different formatter
run: pnpm biome format --write {staged_files}
```

### 2. WIP Validation

**Purpose**: Validate work-in-progress documentation structure and freshness.

```yaml
validate-wip:
  glob: 'docs/wip/active/WIP_*.md'
  run: bash scripts/validate-wip.sh {staged_files}
  fail_text: 'WIP validation failed - see docs/WIP_PROCESS_WITH_AGENT_ORCHESTRATION.md'
```

**Validation Checks**:
1. **Naming convention**: `WIP_{gerund}_{YYYY_MM_DD}.md`
2. **Required sections**: Last Updated, Target Completion, Objective, Progress Tracker
3. **Staleness**: Must be updated within last 7 days
4. **Phase structure**: Proper phase markers (🔵 🟡 🟢 or equivalent)

**Script Example** (`scripts/validate-wip.sh`):
```bash
#!/bin/bash
# Validate WIP files follow standards

for file in "$@"; do
  # Check naming convention
  if ! echo "$file" | grep -qE 'WIP_[a-z_]+_[0-9]{4}_[0-9]{2}_[0-9]{2}\.md'; then
    echo "❌ Invalid WIP filename: $file"
    echo "   Expected: WIP_{gerund}_{YYYY_MM_DD}.md"
    exit 1
  fi

  # Check required sections
  if ! grep -q "## Last Updated" "$file"; then
    echo "❌ Missing 'Last Updated' section in: $file"
    exit 1
  fi

  # Check staleness (modified within last 7 days)
  if [ $(find "$file" -mtime +7 | wc -l) -gt 0 ]; then
    echo "⚠️  WIP file is stale (>7 days): $file"
    echo "   Update the file or move to docs/wip/completed/"
    exit 1
  fi
done

echo "✅ WIP validation passed"
```

### 3. Migration Validation

**Purpose**: Validate SQL migrations for syntax and structure.

```yaml
validate-migrations:
  glob: 'apps/web/supabase/migrations/*.sql'
  run: npx tsx scripts/lint-migrations.ts
```

**Validation Checks**:
- SQL syntax correctness
- Proper migration timestamp naming
- No dangerous operations (DROP DATABASE, TRUNCATE without WHERE)
- Commented SQL for complex operations

**Script Example** (`scripts/lint-migrations.ts`):
```typescript
import { readFileSync } from 'fs';

const args = process.argv.slice(2);

for (const file of args) {
  const content = readFileSync(file, 'utf-8');

  // Check for dangerous operations
  if (content.match(/DROP\s+DATABASE/i)) {
    console.error(`❌ DROP DATABASE found in ${file}`);
    process.exit(1);
  }

  // Check for proper IF NOT EXISTS
  if (content.match(/CREATE\s+(TABLE|INDEX)/i) && !content.includes('IF NOT EXISTS')) {
    console.warn(`⚠️  CREATE without IF NOT EXISTS in ${file}`);
  }
}

console.log('✅ Migration syntax validated');
```

### 4. Migration Idempotency Validation

**Purpose**: Ensure migrations can be safely re-run without errors.

```yaml
validate-migration-idempotency:
  glob: 'apps/web/supabase/migrations/*.sql'
  run: bash .claude/skills/database-migration-manager/scripts/validate-idempotency.sh {staged_files}
  fail_text: 'Migration idempotency validation failed - see output for fixes'
```

**Critical Patterns**:

❌ **Non-Idempotent** (will fail on re-run):
```sql
CREATE POLICY "policy_name" ON table_name ...;
CREATE TRIGGER trigger_name ...;
ALTER TABLE table_name ADD CONSTRAINT constraint_name ...;
```

✅ **Idempotent** (safe to re-run):
```sql
-- Policy with DO $$ block
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'policy_name'
  ) THEN
    CREATE POLICY "policy_name" ON table_name ...;
  END IF;
END $$;

-- Trigger with DROP IF EXISTS
DROP TRIGGER IF EXISTS trigger_name ON table_name;
CREATE TRIGGER trigger_name ...;

-- Constraint with DO $$ block
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'constraint_name'
  ) THEN
    ALTER TABLE table_name ADD CONSTRAINT constraint_name ...;
  END IF;
END $$;

-- Index with IF NOT EXISTS
CREATE INDEX IF NOT EXISTS index_name ON table_name (column);

-- Column with IF NOT EXISTS (requires DO $$ block for ALTER TABLE)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'table' AND column_name = 'column'
  ) THEN
    ALTER TABLE table_name ADD COLUMN column type;
  END IF;
END $$;
```

**Script Template** (`validate-idempotency.sh`):
```bash
#!/bin/bash
# Validate migration idempotency

errors=()

for file in "$@"; do
  # Check CREATE POLICY without DO $$ block
  if grep -qE '^CREATE POLICY' "$file" && \
     ! grep -B3 -E '^CREATE POLICY' "$file" | grep -q 'DO \$\$\|IF NOT EXISTS'; then
    errors+=("$file: CREATE POLICY must be wrapped in DO block with IF NOT EXISTS check")
  fi

  # Check CREATE TRIGGER without DROP IF EXISTS
  if grep -qE '^CREATE TRIGGER' "$file" && \
     ! grep -B1 -E '^CREATE TRIGGER' "$file" | grep -q 'DROP TRIGGER IF EXISTS'; then
    errors+=("$file: CREATE TRIGGER must be preceded by DROP TRIGGER IF EXISTS")
  fi

  # Check ADD CONSTRAINT without DO $$ block
  if grep -qE 'ADD CONSTRAINT' "$file" && \
     ! grep -B3 'ADD CONSTRAINT' "$file" | grep -q 'DO \$\$'; then
    errors+=("$file: ADD CONSTRAINT must be wrapped in DO block with existence check")
  fi

  # Check CREATE INDEX without IF NOT EXISTS
  if grep -qE 'CREATE INDEX' "$file" && \
     ! grep -E 'CREATE INDEX' "$file" | grep -q 'IF NOT EXISTS'; then
    errors+=("$file: CREATE INDEX must include IF NOT EXISTS")
  fi
done

if [ ${#errors[@]} -gt 0 ]; then
  echo "❌ Migration idempotency issues found:"
  printf '  • %s\n' "${errors[@]}"
  exit 1
fi

echo "✅ Migration idempotency validated"
```

### 5. RLS Policy Validation

**Purpose**: Validate Row Level Security policies for security issues.

```yaml
validate-rls-policies:
  glob: 'apps/web/supabase/migrations/*.sql'
  run: bash scripts/analyze-rls-policies.sh {staged_files}
  fail_text: 'RLS policy validation failed - fix issues before committing'
```

**Validation Checks**:
- RLS enabled on all tables with data
- Super admin bypass uses `is_super_admin()` function
- No hardcoded user IDs in policies
- Proper use of `auth.uid()` for user identification
- No overly permissive policies (e.g., `true` for all users)

**Script Example** (`scripts/analyze-rls-policies.sh`):
```bash
#!/bin/bash
# Analyze RLS policies for security issues

for file in "$@"; do
  # Check for RLS enable
  if grep -qE 'CREATE TABLE' "$file" && \
     ! grep -qE 'ALTER TABLE.*ENABLE ROW LEVEL SECURITY' "$file"; then
    echo "⚠️  Table created without RLS enabled in: $file"
  fi

  # Check for hardcoded user IDs
  if grep -qE "auth\.uid\(\)\s*=\s*'[0-9a-f-]{36}'" "$file"; then
    echo "❌ Hardcoded user ID in RLS policy: $file"
    exit 1
  fi

  # Check for overly permissive policies
  if grep -qE 'CREATE POLICY.*USING.*\(true\)' "$file"; then
    echo "⚠️  Overly permissive RLS policy (true for all) in: $file"
  fi
done

echo "✅ RLS policies validated"
```

### 6. Version Suffix Detection

**Purpose**: Prevent version suffixes in filenames (enforce in-place refactoring).

```yaml
check-version-suffixes:
  glob: '**/*.{ts,tsx,js,jsx}'
  run: bash scripts/check-version-suffixes.sh
  fail_text: 'Version suffixes detected - refactor in place instead (see CLAUDE.md)'
```

**Forbidden Patterns**:
- `-v2`, `-v3`, `-v4`, etc.
- `-new`, `-old`, `-updated`, `-improved`, `-enhanced`
- `_v2`, `_v3`, `_new`, etc.
- `unified-*` prefix

**Script Example** (`scripts/check-version-suffixes.sh`):
```bash
#!/bin/bash
# Check for forbidden version suffixes

forbidden=$(git diff --cached --name-only --diff-filter=ACMR | \
  grep -E '(-v[0-9]|-new|-old|-updated|-improved|-enhanced|_v[0-9]|_new|unified-)' || true)

if [ -n "$forbidden" ]; then
  echo "❌ Version suffixes detected (forbidden per CLAUDE.md rule #1):"
  echo "$forbidden" | sed 's/^/  - /'
  echo ""
  echo "Instead of creating user-form-v2.tsx, modify user-form.tsx directly."
  echo "If found: RENAME to remove suffix, do NOT delete."
  exit 1
fi
```

### 7. Block Root Markdown Files

**Purpose**: Prevent documentation files in repository root.

```yaml
block-root-md-files:
  glob: '*.md'
  run: bash scripts/block-root-md-files.sh
  fail_text: 'Documentation files in repo root - move to docs/wip/active/ (see CLAUDE.md rule #7)'
```

**Allowed Root Files**:
- `CLAUDE.md`
- `README.md`

**Script Example** (`scripts/block-root-md-files.sh`):
```bash
#!/bin/bash
# Block markdown files in repo root

root_md=$(git diff --cached --name-only --diff-filter=A | \
  grep -E '^[^/]+\.md$' | \
  grep -v -E '^(CLAUDE|README)\.md$' || true)

if [ -n "$root_md" ]; then
  echo "❌ Markdown files in repo root (forbidden per CLAUDE.md rule #7):"
  echo "$root_md" | sed 's/^/  - /'
  echo ""
  echo "Move to proper location:"
  echo "  • Temporary work → docs/wip/active/WIP_{gerund}_{YYYY_MM_DD}.md"
  echo "  • Permanent guide → docs/guides/{kebab-case}.md"
  exit 1
fi
```

### 8. JSON Key Validation

**Purpose**: Detect duplicate keys in JSON files.

```yaml
validate-json-keys:
  glob: '**/*.json'
  run: bash scripts/validate-json-keys.sh {staged_files}
  fail_text: 'Duplicate JSON keys detected - merge duplicate keys into single objects'
```

**Script Example** (`scripts/validate-json-keys.sh`):
```bash
#!/bin/bash
# Validate JSON for duplicate keys

for file in "$@"; do
  # Use jq to detect duplicate keys
  duplicates=$(jq -r 'paths(type == "object") as $p | getpath($p) | keys | group_by(.) | map(select(length > 1)) | .[]' "$file" 2>/dev/null || echo "")

  if [ -n "$duplicates" ]; then
    echo "❌ Duplicate JSON keys in: $file"
    echo "   Keys: $duplicates"
    exit 1
  fi
done

echo "✅ JSON validation passed"
```

### 9. Local Database Validation

**Purpose**: Validate database schema and queries (when Supabase is running).

```yaml
validate-db-local:
  glob: '**/*.{ts,tsx,sql}'
  run: bash scripts/validate-db-local.sh {staged_files}
```

**Graceful Degradation**: Silently skips if Supabase is not running.

**Script Example** (`scripts/validate-db-local.sh`):
```bash
#!/bin/bash
# Validate database locally (skip if Supabase not running)

# Check if Supabase is running
if ! curl -s http://localhost:54322/rest/v1/ > /dev/null 2>&1; then
  exit 0  # Skip silently
fi

# Run validation queries
# (Add project-specific validation logic here)

echo "✅ Local DB validation passed"
```

## Pre-Push Hooks

**Goal**: Comprehensive validation before pushing to remote (30-60s execution time).

### 1. Oxlint (Fast Linting)

**Purpose**: Quick sanity check for critical ESLint rules (10-100x faster than full ESLint).

```yaml
oxlint:
  run: |
    export PATH="/Users/{{USER}}/.nvm/versions/node/v{{NODE_VERSION}}/bin:$PATH"
    echo "🔍 Running oxlint (fast sanity check)..."
    output=$(pnpm oxlint \
      --deny=no-debugger \
      --deny=no-const-assign \
      --deny=no-dupe-keys \
      --deny=no-self-assign \
      --ignore-path=.gitignore \
      apps/web packages 2>&1)
    echo "$output" | tail -3
    if echo "$output" | grep -q "x eslint(no-"; then
      echo ""
      echo "⚠️  oxlint found issues - fix before pushing"
      exit 1
    fi
    echo "✅ oxlint passed"
```

**Critical Rules**:
- `no-debugger` - No debugger statements
- `no-const-assign` - No reassigning const variables
- `no-dupe-keys` - No duplicate object keys
- `no-self-assign` - No self-assignment

**Why Oxlint?**
- Written in Rust, 10-100x faster than ESLint
- Catches critical issues in seconds
- Full ESLint runs in CI or THOROUGH mode

### 2. Full ESLint (THOROUGH Mode)

**Purpose**: Comprehensive linting when explicitly requested.

```yaml
lint:
  env:
    THOROUGH: ${THOROUGH:-}
  run: |
    export PATH="/Users/{{USER}}/.nvm/versions/node/v{{NODE_VERSION}}/bin:$PATH"
    if [ -n "$THOROUGH" ]; then
      echo "🔍 Running full ESLint (thorough mode)..."
      pnpm turbo lint --cache-dir=.turbo --affected --continue
    else
      echo "ℹ️  Skipping full ESLint (use THOROUGH=1 git push for full check)"
    fi
```

**Usage**:
```bash
# Normal push (oxlint only)
git push

# Thorough push (full ESLint)
THOROUGH=1 git push
```

### 3. TypeScript Type Checking

**Purpose**: Ensure type correctness across affected packages.

```yaml
typecheck:
  run: |
    export PATH="/Users/{{USER}}/.nvm/versions/node/v{{NODE_VERSION}}/bin:$PATH"
    echo "🔍 Running typecheck..."
    pnpm turbo typecheck --affected --cache-dir=.turbo
```

**Optimization**: Only checks affected packages (Turborepo).

**Strict Mode**: Requires `"strict": true` in tsconfig.json.

### 4. Lockfile Validation

**Purpose**: Ensure pnpm-lock.yaml is in sync with package.json files.

```yaml
validate-lockfile:
  run: |
    export PATH="/Users/{{USER}}/.nvm/versions/node/v{{NODE_VERSION}}/bin:$PATH"
    echo "🔍 Checking pnpm-lock.yaml sync..."
    # Cross-platform timeout
    if command -v timeout >/dev/null 2>&1; then
      timeout 15 pnpm install --frozen-lockfile --ignore-scripts --prefer-offline 2>/dev/null
    elif command -v gtimeout >/dev/null 2>&1; then
      gtimeout 15 pnpm install --frozen-lockfile --ignore-scripts --prefer-offline 2>/dev/null
    else
      pnpm install --frozen-lockfile --ignore-scripts --prefer-offline 2>/dev/null
    fi || {
      exitcode=$?
      if [ $exitcode -eq 124 ]; then
        echo "⚠️  Lockfile validation timed out - will be checked in CI"
      else
        echo ""
        echo "❌ pnpm-lock.yaml is out of sync!"
        echo "   Run: pnpm install && git add pnpm-lock.yaml && git commit --amend --no-edit"
        exit 1
      fi
    }
    echo "✅ Lockfile is in sync"
```

**Fix Command**:
```bash
pnpm install && git add pnpm-lock.yaml && git commit --amend --no-edit
```

### 5. Database Type Validation

**Purpose**: Inform about DB type sync (auto-synced in CI).

```yaml
validate-db-types:
  run: |
    echo "ℹ️  DB types auto-sync via GitHub Actions after push"
    echo "   Manual sync: pnpm supabase:web:typegen"
```

**Manual Sync** (if needed):
```bash
# Web types
pnpm supabase:web:typegen

# Flutter types
pnpm flutter:typegen
```

### 6. Staging Sync Check

**Purpose**: Warn if local DB is behind staging.

```yaml
check-staging-sync:
  run: |
    export PATH="/Users/{{USER}}/.nvm/versions/node/v{{NODE_VERSION}}/bin:$PATH"

    # Skip if status file doesn't exist yet
    if [ ! -f apps/web/.staging-status.json ]; then
      exit 0
    fi

    # Check if local Supabase is running
    if ! curl -s http://localhost:54322/rest/v1/ > /dev/null 2>&1; then
      exit 0
    fi

    # Get latest migration from staging
    STAGING_LATEST=$(cd apps/web && node -pe "require('./.staging-status.json').lastMigrationApplied" 2>/dev/null)

    # Get latest local migration
    LOCAL_LATEST=$(ls apps/web/supabase/migrations/*.sql 2>/dev/null | tail -1 | sed 's/.*\///' | cut -d'_' -f1)

    # Compare timestamps
    if [ -n "$STAGING_LATEST" ] && [ -n "$LOCAL_LATEST" ] && [ "$LOCAL_LATEST" != "$STAGING_LATEST" ]; then
      if [ "$LOCAL_LATEST" \< "$STAGING_LATEST" ]; then
        echo ""
        echo "⚠️  Your local DB may be behind staging"
        echo "   Staging latest: ${STAGING_LATEST}"
        echo "   Local latest:   ${LOCAL_LATEST}"
        echo ""
        echo "💡 Consider syncing: pnpm db:reset"
        echo ""
        read -p "Continue push? [Y/n] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Nn]$ ]] || exit 1
      fi
    fi
```

### 7. Flutter Type Check

**Purpose**: Validate Flutter Supabase types are in sync.

```yaml
flutter-types-check:
  glob: 'apps/mobile/**/*.dart'
  run: |
    export PATH="/Users/{{USER}}/.nvm/versions/node/v{{NODE_VERSION}}/bin:$PATH"
    echo "🔍 Checking Flutter Supabase types..."

    # Check if supadart is installed
    if ! command -v supadart &> /dev/null; then
      echo "⚠️  Supadart not installed - skipping Flutter type check"
      exit 0
    fi

    # Load env vars
    if [ -z "$SUPABASE_URL" ]; then
      if [ -f ".env.local" ]; then
        export SUPABASE_URL=$(grep NEXT_PUBLIC_SUPABASE_URL .env.local | cut -d '=' -f2)
        export SUPABASE_API_KEY=$(grep NEXT_PUBLIC_SUPABASE_ANON_KEY .env.local | cut -d '=' -f2)
      fi
    fi

    if [ -z "$SUPABASE_URL" ]; then
      echo "⚠️  Supabase credentials not found - skipping"
      exit 0
    fi

    cd apps/mobile
    supadart 2>/dev/null

    if [ -n "$(git status --porcelain lib/core/generated/supabase/)" ]; then
      echo ""
      echo "❌ Flutter Supabase types are out of sync!"
      echo "   Run: pnpm flutter:typegen"
      exit 1
    fi

    echo "✅ Flutter types are in sync"
```

### 8. Flutter Query Validation

**Purpose**: Validate Supabase queries statically (Dart).

```yaml
flutter-query-validate:
  glob: 'apps/mobile/lib/**/api/**/*.dart'
  run: |
    echo "🔍 Validating Flutter Supabase queries..."
    cd apps/mobile
    if dart run scripts/validate_queries.dart; then
      echo "✅ Flutter queries validated"
    else
      echo ""
      echo "❌ Flutter query validation failed!"
      exit 1
    fi
```

### 9. Flutter Query Schema Lint

**Purpose**: Validate Flutter queries against database schema (TypeScript).

```yaml
flutter-query-schema-lint:
  glob: 'apps/mobile/lib/**/api/**/*.dart'
  run: |
    export PATH="/Users/{{USER}}/.nvm/versions/node/v{{NODE_VERSION}}/bin:$PATH"
    echo "🔍 Linting Flutter queries against database schema..."
    if pnpm flutter:lint-queries 2>&1 | grep -q "Errors: 0"; then
      echo "✅ Flutter queries match schema"
    else
      pnpm flutter:lint-queries
      echo ""
      echo "❌ Flutter query schema lint failed!"
      exit 1
    fi
```

### 10. Flutter Live Query Testing (THOROUGH Mode)

**Purpose**: Run queries against local Supabase instance (only with THOROUGH=1).

```yaml
flutter-query-live:
  env:
    THOROUGH: ${THOROUGH:-}
  run: |
    if [ -z "$THOROUGH" ]; then
      echo "ℹ️  Skipping Flutter live query testing (use THOROUGH=1 for full check)"
      exit 0
    fi

    # Check if local Supabase is running
    if ! curl -s http://localhost:54321/rest/v1/ > /dev/null 2>&1; then
      echo "⚠️  Local Supabase not running - skipping"
      exit 0
    fi

    echo "🔍 Running Flutter live query tests..."
    cd apps/mobile
    if dart run scripts/test_queries_local.dart; then
      echo "✅ Flutter live query tests passed"
    else
      echo ""
      echo "❌ Flutter live query tests failed!"
      exit 1
    fi
```

## Claude Code Hooks

**Goal**: Real-time validation during Claude Code operation, preventing forbidden patterns before they're written.

### Configuration File

All Claude Code hooks are defined in `.claude/settings.json`:

```json
{
  "permissions": {
    "deny": [
      "Bash(git reset --hard:*)",
      "Bash(git push --force:*)",
      "Bash(git push -f:*)",
      "Bash(rm -rf /:*)"
    ]
  },
  "hooks": {
    "SessionStart": [],
    "PreToolUse": [],
    "PostToolUse": []
  }
}
```

### SessionStart Hooks

**Purpose**: Run at the start of each Claude Code session.

```json
{
  "SessionStart": [
    {
      "matcher": "startup",
      "hooks": [
        {
          "type": "command",
          "command": "echo 'Session started' && pnpm install --frozen-lockfile"
        }
      ]
    }
  ]
}
```

**Use Cases**:
- Install dependencies
- Load environment variables
- Check system prerequisites

### PreToolUse Hooks

**Purpose**: Block forbidden operations before tools execute.

#### 1. Block Forbidden File Suffixes

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "file=\"$CLAUDE_TOOL_INPUT_file_path\"; base=$(basename \"$file\"); if [[ \"$file\" == *\"-v2.\"* ]] || [[ \"$file\" == *\"-v3.\"* ]] || [[ \"$file\" == *\"-new.\"* ]] || [[ \"$file\" == *\"-enhanced.\"* ]] || [[ \"$file\" == *\"_v2.\"* ]] || [[ \"$file\" == *\"_v3.\"* ]] || [[ \"$file\" == *\"_new.\"* ]] || [[ \"$file\" == *\"_enhanced.\"* ]] || [[ \"$base\" == unified-* ]]; then echo 'BLOCKED: Forbidden suffix/prefix (v2, v3, new, enhanced, unified-). Modify original file.' && exit 1; fi"
    }
  ]
}
```

**Blocks**:
- `-v2`, `-v3`, `-new`, `-enhanced`, etc.
- `_v2`, `_v3`, `_new`, etc.
- `unified-*` prefix

#### 2. Block Root Markdown Files

```json
{
  "matcher": "Write",
  "hooks": [
    {
      "type": "command",
      "command": "file=\"$CLAUDE_TOOL_INPUT_file_path\"; base=$(basename \"$file\"); ext=\"${file##*.}\"; parent=$(dirname \"$file\"); repo_root=\"/Users/{{USER}}/GitHub/{{PROJECT}}\"; if [[ \"$ext\" == \"md\" ]] && [[ \"$parent\" == \"$repo_root\" ]] && [[ \"$base\" != \"CLAUDE.md\" ]] && [[ \"$base\" != \"README.md\" ]]; then echo '❌ BLOCKED: Cannot create .md files in repo root. Use docs/wip/active/ or docs/guides/' && exit 1; fi"
    }
  ]
}
```

**Allows**:
- `CLAUDE.md`
- `README.md`

**Requires**:
- All other markdown files in `docs/` subdirectories

#### 3. Block Direct Database Modifications

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "cmd=\"$CLAUDE_TOOL_INPUT_command\"; if echo \"$cmd\" | grep -qE 'supabase.*db.*push|psql.*-c.*(ALTER|DROP|CREATE)'; then echo 'BLOCKED: Use migrations instead.' && exit 1; fi"
    }
  ]
}
```

**Prevents**:
- `supabase db push` (use migrations)
- `psql -c "ALTER TABLE ..."` (use migrations)
- Direct schema modifications via psql

#### 4. Prevent echo with Vercel env add

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "cmd=\"$CLAUDE_TOOL_INPUT_command\"; if echo \"$cmd\" | grep -q 'echo' && echo \"$cmd\" | grep -q 'vercel env add'; then echo 'BLOCKED: Use printf instead of echo to avoid trailing newlines.' && exit 1; fi"
    }
  ]
}
```

**Reason**: `echo` adds trailing newline, breaking env vars in Vercel.

**Correct Pattern**:
```bash
# ❌ Wrong (adds trailing newline)
echo "$VALUE" | vercel env add KEY production

# ✅ Correct (no trailing newline)
printf "%s" "$VALUE" | vercel env add KEY production
```

#### 5. Prevent Orphaned git stash

```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "cmd=\"$CLAUDE_TOOL_INPUT_command\"; if echo \"$cmd\" | grep -q 'git stash' && ! echo \"$cmd\" | grep -q 'git stash pop'; then echo 'BLOCKED: git stash must be paired with pop. Use: git stash && <commands> && git stash pop' && exit 1; fi"
    }
  ]
}
```

### PostToolUse Hooks

**Purpose**: Validate files after write/edit operations.

#### 1. Migration Idempotency Warning

```json
{
  "matcher": "Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "file=\"$CLAUDE_TOOL_INPUT_file_path\"; if [[ \"$file\" == *migrations/*.sql ]]; then if ! grep -qi 'IF NOT EXISTS\\|IF EXISTS' \"$file\" 2>/dev/null; then echo 'Warning: Migration may not be idempotent.'; fi; if grep -q '^CREATE POLICY' \"$file\" 2>/dev/null && ! grep -B3 '^CREATE POLICY' \"$file\" | grep -q 'DO \\$\\$\\|IF NOT EXISTS'; then echo 'BLOCKED: CREATE POLICY must be wrapped in DO block' && exit 1; fi; fi"
    }
  ]
}
```

**Validates**:
- Migrations use `IF NOT EXISTS` / `IF EXISTS`
- `CREATE POLICY` wrapped in `DO $$` block

## Lefthook Configuration

### Basic Configuration

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  commands:
    format:
      glob: '*.{js,jsx,ts,tsx,json,md}'
      run: pnpm prettier --write {staged_files}
      stage_fixed: true

pre-push:
  parallel: true
  commands:
    lint:
      run: pnpm eslint
    typecheck:
      run: pnpm typecheck
```

### Advanced Patterns

#### Skip Patterns

```yaml
pre-commit:
  skip:
    - merge  # Skip on merge commits
    - rebase # Skip during rebase
  commands:
    # ...
```

#### Environment Variables

```yaml
pre-push:
  commands:
    lint:
      env:
        THOROUGH: ${THOROUGH:-}  # Use environment variable
      run: |
        if [ -n "$THOROUGH" ]; then
          pnpm eslint --max-warnings 0
        fi
```

#### Fail Text

```yaml
pre-commit:
  commands:
    validate:
      run: ./scripts/validate.sh
      fail_text: |
        Validation failed!
        Run: ./scripts/fix.sh
        See: docs/VALIDATION.md
```

#### Stage Fixed Files

```yaml
pre-commit:
  commands:
    format:
      run: pnpm prettier --write {staged_files}
      stage_fixed: true  # Re-stage auto-fixed files
```

### Performance Optimization

#### Use Affected Files Only

```yaml
pre-commit:
  commands:
    lint:
      glob: '**/*.{ts,tsx}'
      run: pnpm eslint {staged_files}  # Only lint staged files
```

#### Parallel Execution

```yaml
pre-push:
  parallel: true  # Run all commands simultaneously
  commands:
    lint:
      run: pnpm lint
    typecheck:
      run: pnpm typecheck
    test:
      run: pnpm test
```

#### Caching with Turborepo

```yaml
pre-push:
  commands:
    typecheck:
      run: pnpm turbo typecheck --affected --cache-dir=.turbo
```

## Project-Specific Examples

### Next.js Monorepo

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  commands:
    format:
      glob: '*.{js,jsx,ts,tsx,json,md,css}'
      run: pnpm prettier --write {staged_files}
      stage_fixed: true

    validate-migrations:
      glob: 'apps/web/supabase/migrations/*.sql'
      run: npx tsx scripts/lint-migrations.ts

pre-push:
  parallel: true
  commands:
    oxlint:
      run: pnpm oxlint --deny=no-debugger apps/web packages

    typecheck:
      run: pnpm turbo typecheck --affected

    test:
      run: pnpm turbo test --affected
```

### Flutter Mobile App

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  commands:
    format:
      glob: '**/*.dart'
      run: dart format {staged_files}
      stage_fixed: true

    analyze:
      glob: '**/*.dart'
      run: dart analyze {staged_files}

pre-push:
  parallel: true
  commands:
    analyze:
      run: cd apps/mobile && dart analyze

    test:
      run: cd apps/mobile && flutter test

    query-validate:
      glob: 'apps/mobile/lib/**/api/**/*.dart'
      run: cd apps/mobile && dart run scripts/validate_queries.dart
```

### Backend Service

```yaml
# lefthook.yml
pre-commit:
  parallel: true
  commands:
    format:
      glob: '**/*.{ts,js,json}'
      run: pnpm prettier --write {staged_files}
      stage_fixed: true

    lint:
      glob: '**/*.{ts,js}'
      run: pnpm eslint {staged_files}

pre-push:
  parallel: true
  commands:
    typecheck:
      run: pnpm typecheck

    test:
      run: pnpm test --run

    validate-env:
      run: bash scripts/validate-env-vars.sh
```

## Troubleshooting

### Common Issues

#### 1. Hooks Not Running

**Symptom**: Hooks don't execute on commit/push.

**Solutions**:
```bash
# Reinstall lefthook
lefthook install

# Check if hooks are registered
ls -la .git/hooks/

# Verify lefthook.yml exists
cat lefthook.yml
```

#### 2. Hooks Timeout

**Symptom**: Pre-commit/pre-push hooks take too long.

**Solutions**:
```yaml
# Increase timeout for specific hook
pre-commit:
  commands:
    slow-check:
      run: ./slow-script.sh
      env:
        LEFTHOOK_TIMEOUT: 300  # 5 minutes
```

Or reduce scope:
```yaml
# Only check staged files
lint:
  glob: '**/*.ts'
  run: pnpm eslint {staged_files}  # Not all files
```

#### 3. PATH Issues

**Symptom**: Commands not found (pnpm, node, etc.).

**Solution**: Export PATH in hook:
```yaml
lint:
  run: |
    export PATH="/Users/{{USER}}/.nvm/versions/node/v{{VERSION}}/bin:$PATH"
    pnpm eslint
```

#### 4. False Positives

**Symptom**: Hook fails incorrectly.

**Solutions**:
```bash
# Skip for single commit
git commit --no-verify

# Skip for single push
git push --no-verify

# Disable specific hook temporarily
LEFTHOOK_EXCLUDE=lint git push
```

#### 5. Claude Code Hooks Block Valid Operations

**Symptom**: PreToolUse hook blocks legitimate file.

**Solution**: Add exception to hook pattern:
```json
{
  "command": "file=\"$CLAUDE_TOOL_INPUT_file_path\"; if [[ \"$file\" == *\"-v2.\"* ]] && [[ \"$file\" != *\"exceptions/\"* ]]; then exit 1; fi"
}
```

### Performance Tuning

#### Optimize Pre-Commit (<2s target)

1. **Use stage_fixed for formatters**:
   ```yaml
   format:
     run: pnpm prettier --write {staged_files}
     stage_fixed: true
   ```

2. **Skip expensive checks on commit**:
   ```yaml
   # Move typecheck to pre-push
   pre-push:
     commands:
       typecheck:
         run: pnpm typecheck
   ```

3. **Use glob patterns**:
   ```yaml
   lint:
     glob: '**/*.{ts,tsx}'  # Only check TypeScript files
     run: pnpm eslint {staged_files}
   ```

#### Optimize Pre-Push (<60s target)

1. **Use affected packages**:
   ```yaml
   typecheck:
     run: pnpm turbo typecheck --affected
   ```

2. **Enable caching**:
   ```yaml
   lint:
     run: pnpm turbo lint --cache-dir=.turbo
   ```

3. **Parallelize independent checks**:
   ```yaml
   pre-push:
     parallel: true  # Run all in parallel
   ```

## Best Practices

### 1. Clear Error Messages

❌ **Bad**:
```yaml
validate:
  run: ./validate.sh
  fail_text: 'Validation failed'
```

✅ **Good**:
```yaml
validate:
  run: ./validate.sh
  fail_text: |
    Validation failed!

    Fix: ./fix.sh
    See: docs/VALIDATION.md rule #3
```

### 2. Graceful Degradation

```bash
# Check if tool is available, skip if not
if ! command -v supadart &> /dev/null; then
  echo "⚠️  Supadart not installed - skipping"
  exit 0
fi

# Check if service is running, skip if not
if ! curl -s http://localhost:54321 > /dev/null 2>&1; then
  exit 0
fi
```

### 3. Escape Hatches

**Always document**:
```yaml
lint:
  run: pnpm eslint
  fail_text: |
    ESLint errors found.

    Fix: pnpm eslint --fix
    Skip (emergency only): git push --no-verify
```

### 4. Performance Targets

- Pre-commit: **< 2 seconds**
- Pre-push: **< 60 seconds**
- THOROUGH mode: **~5 minutes** (opt-in)

Monitor with:
```bash
time git commit -m "test"
time git push
time THOROUGH=1 git push
```

### 5. Progressive Enhancement

Start minimal, add checks incrementally:

**Week 1** (minimal):
```yaml
pre-commit:
  commands:
    format:
      run: pnpm prettier --write {staged_files}
```

**Week 2** (add linting):
```yaml
pre-push:
  commands:
    lint:
      run: pnpm eslint
```

**Week 3** (add typecheck):
```yaml
pre-push:
  commands:
    typecheck:
      run: pnpm typecheck
```

---

**Last Updated**: 2026-01-13
**Related**: [QUALITY_GATES_GUIDE.md](QUALITY_GATES_GUIDE.md), [TESTING_GUIDE.md](TESTING_GUIDE.md)

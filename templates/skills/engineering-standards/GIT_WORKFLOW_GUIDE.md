# Git Workflow Guide

Branch management, commit standards, PR workflows, and co-authoring practices.

## Overview

Standardized Git workflow ensuring clean history, safe branching, and collaborative commits with Claude Code.

### Core Principles

1. **Worktree-based branching** - Main directory stays on default branch
2. **Conventional commits** - Semantic commit messages with issue references
3. **Claude co-authoring** - All AI-assisted commits credit Claude
4. **Protected branches** - Main/production branches require reviews
5. **Clean history** - No force pushes, no broken commits

## Branch Strategy

### Worktree-Based Workflow

**Philosophy**: Keep main working directory on default branch, use worktrees for feature work.

**Benefits**:
- No accidental commits to wrong branch
- Fast context switching (no checkout delays)
- Parallel work on multiple features
- IDE settings persist across branches

**Setup**:
```bash
# Main directory always on dev/main
cd ~/GitHub/myproject/  # Stays on dev branch

# Feature branches use worktrees
~/GitHub/myproject-worktrees/feat-user-auth/
~/GitHub/myproject-worktrees/fix-login-bug/
~/GitHub/myproject-main/  # Worktree for main branch
```

### Worktree Script

**Location**: `scripts/git-worktree.sh`

**Usage**:
```bash
# Create/switch to worktree for branch
./scripts/git-worktree.sh feat/new-feature

# List all worktrees
./scripts/git-worktree.sh --list

# Clean up merged worktrees
./scripts/git-worktree.sh --clean

# Remove specific worktree
./scripts/git-worktree.sh --remove feat/old-feature
```

**Script Example**:
```bash
#!/bin/bash
set -euo pipefail

WORKTREE_DIR="$HOME/GitHub/$(basename "$(pwd)")-worktrees"
BRANCH="$1"

if [ -z "$BRANCH" ]; then
  echo "Usage: $0 <branch-name>"
  exit 1
fi

# Create worktree directory if needed
mkdir -p "$WORKTREE_DIR"

# Check if worktree exists
WORKTREE_PATH="$WORKTREE_DIR/$BRANCH"
if [ -d "$WORKTREE_PATH" ]; then
  echo "Worktree exists at $WORKTREE_PATH"
  cd "$WORKTREE_PATH"
else
  # Check if branch exists remotely
  if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    git worktree add "$WORKTREE_PATH" "$BRANCH"
  else
    # Create new branch
    git worktree add -b "$BRANCH" "$WORKTREE_PATH"
  fi
  cd "$WORKTREE_PATH"
fi

echo "Switched to worktree: $WORKTREE_PATH"
```

### Post-Checkout Hook

**Purpose**: Warn if accidentally switching away from default branch in main directory.

**Location**: `.git/hooks/post-checkout`

```bash
#!/bin/bash

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Expected main directory (not a worktree)
if [[ "$REPO_ROOT" == *"-worktrees"* ]]; then
  # This is a worktree, allow any branch
  exit 0
fi

# Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DEFAULT_BRANCH="dev"  # Or "main" for your project

if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
  echo "⚠️  WARNING: Main directory is on branch '$CURRENT_BRANCH'"
  echo "   Expected: '$DEFAULT_BRANCH'"
  echo "   Use worktrees for feature branches: ./scripts/git-worktree.sh $CURRENT_BRANCH"
fi
```

## Branch Naming

### Conventions

**Format**: `<type>/<description>`

| Type | Purpose | Example |
|------|---------|---------|
| `feat/` | New features | `feat/user-authentication` |
| `fix/` | Bug fixes | `fix/login-redirect` |
| `refactor/` | Code refactoring | `refactor/api-client` |
| `docs/` | Documentation only | `docs/api-guide` |
| `chore/` | Tooling, dependencies | `chore/update-deps` |
| `perf/` | Performance improvements | `perf/optimize-queries` |
| `test/` | Test additions | `test/user-service` |

**Rules**:
- Use kebab-case for descriptions
- Be concise but descriptive
- Avoid issue numbers in branch names (use commits instead)
- No version suffixes (feat/login-v2 ❌)

**Examples**:
```bash
# ✅ Good
feat/social-login
fix/email-validation
refactor/user-service
docs/deployment-guide

# ❌ Bad
feature-123  # No type prefix
fix_bug      # Use kebab-case
feat/login-v2  # No version suffixes
MY-FEATURE   # Not SCREAMING_CASE
```

## Commit Format

### Conventional Commits

**Format**: `<type>: <description> (<reference>)`

**Types**:
- `feat:` - New feature
- `fix:` - Bug fix
- `refactor:` - Code refactoring (no behavior change)
- `docs:` - Documentation changes
- `test:` - Test additions or updates
- `chore:` - Tooling, dependencies, config
- `perf:` - Performance improvements
- `style:` - Formatting, whitespace (no logic change)

**Description**:
- Lowercase, imperative mood ("add" not "added")
- No period at end
- Max 72 characters for first line
- Describe what, not how

**Reference** (optional):
- `(closes #123)` - Closes issue
- `(refs #456)` - References issue
- `(fixes #789)` - Fixes issue

**Examples**:
```bash
# ✅ Good
feat: add social login with Google (closes #42)
fix: resolve email validation edge case (refs #56)
refactor: simplify user service authentication
docs: update deployment guide with new steps
test: add coverage for user registration flow
chore: upgrade Next.js to v16
perf: optimize database query batching (refs #78)

# ❌ Bad
Added new feature  # Not imperative, no type
fix: Fixed the bug.  # Past tense, period
FEAT: NEW LOGIN  # Not lowercase
feat: implemented a new user authentication system using OAuth 2.0 with Google and Facebook providers and added comprehensive test coverage  # Too long
```

### Multi-Line Commits

**Format**:
```
<type>: <short description>

<detailed explanation>

<references>
```

**Example**:
```bash
git commit -m "$(cat <<'EOF'
feat: add RLS policies for events table

- Public events visible to all when status='open'
- Private events only visible to account members
- Super admin bypass via is_super_admin() check
- Comprehensive test coverage in events.test.ts

Closes #42, refs #38
EOF
)"
```

### Claude Co-Authoring

**Every AI-assisted commit** must include Claude co-author line.

**Format**:
```
<commit message>

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**HEREDOC Pattern** (recommended):
```bash
git commit -m "$(cat <<'EOF'
feat: add user authentication service

Implemented service layer with Result pattern, RLS validation,
and comprehensive error handling.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

**Why HEREDOC**:
- Preserves formatting
- No quote escaping needed
- Multi-line messages easy
- Consistent style

**Examples**:
```bash
# ✅ Good
git commit -m "$(cat <<'EOF'
fix: resolve migration idempotency issue

Added IF NOT EXISTS check to CREATE POLICY statement
to prevent duplicate policy errors on re-run.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"

# ❌ Bad (no co-author)
git commit -m "fix: resolve migration issue"

# ❌ Bad (malformed co-author)
git commit -m "fix: resolve issue\n\nCo-authored-by: claude"
```

## Pull Request Workflow

### PR Creation

**Before Creating PR**:
1. Run full quality gate: `pnpm quality`
2. Ensure all tests pass
3. Update relevant documentation
4. Add changelog entry (if applicable)
5. Rebase on target branch

**PR Title Format**:
```
<type>: <description> (#issue)
```

**Examples**:
```
feat: add user authentication (#42)
fix: resolve email validation bug (#56)
refactor: simplify API client (#78)
```

### PR Description Template

**Location**: `.github/pull_request_template.md`

```markdown
## Summary

<!-- Brief description of what this PR does -->

## Changes

<!-- Bulleted list of key changes -->
-
-
-

## Test Plan

<!-- How to verify these changes work -->
- [ ] Unit tests pass (`pnpm test`)
- [ ] E2E tests pass (`pnpm test:e2e`)
- [ ] Manual testing completed
- [ ] Quality gate passes (`pnpm quality`)

## Related Issues

<!-- Link to related issues -->
Closes #
Refs #

## Screenshots (if applicable)

<!-- Add screenshots for UI changes -->

## Checklist

- [ ] Code follows project style guide
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No version suffixes (-v2, -new, etc.)
- [ ] Migration uses IF NOT EXISTS (if applicable)
- [ ] RLS policies tested (if applicable)
- [ ] Claude co-author line in commits

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### PR Review Requirements

**Required Reviewers**: Minimum 1 approval for main/production

**Review Checklist**:
- [ ] Code quality and readability
- [ ] Test coverage adequate
- [ ] No security vulnerabilities
- [ ] Performance considerations
- [ ] Documentation updated
- [ ] Breaking changes documented
- [ ] Migration idempotency verified

**Auto-Checks** (CI/CD):
- Format validation
- Lint checks
- Type checking
- Test suite
- Build success

### Merge Strategies

**Squash and Merge** (default):
- Use for feature branches
- Creates single commit on main
- Clean history

**Rebase and Merge**:
- Use for small fixes
- Preserves individual commits
- Linear history

**Merge Commit**:
- Use for release branches
- Preserves branch history
- Clear feature boundaries

**Never**:
- Force push to main/production
- Merge without review
- Merge failing CI/CD

## Protected Branches

### Branch Protection Rules

**Main/Production Branch**:
```yaml
Branch: main
Rules:
  - Require pull request reviews (1+)
  - Require status checks to pass
    - format-check
    - lint
    - typecheck
    - test
    - build
  - Require branches to be up to date
  - Require signed commits (optional)
  - Restrict force pushes
  - Restrict deletions
```

**Development Branch**:
```yaml
Branch: dev
Rules:
  - Require status checks to pass
    - format-check
    - lint
    - typecheck
    - test
  - Allow force pushes (for maintainers only)
```

### GitHub Actions Protection

**Workflow**: `.github/workflows/branch-protection.yml`

```yaml
name: Branch Protection

on:
  pull_request:
    branches: [main, dev]

jobs:
  quality-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Quality gate
        run: pnpm quality

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

## Git Safety Practices

### Pre-Commit Safety

**Prevent Destructive Operations**:
```bash
# Git pre-commit hook
#!/bin/bash

# Block commits to main in main directory
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
REPO_ROOT=$(git rev-parse --show-toplevel)

if [[ "$REPO_ROOT" != *"-worktrees"* && "$CURRENT_BRANCH" == "main" ]]; then
  echo "❌ BLOCKED: Cannot commit directly to main branch in main directory"
  echo "   Use a worktree: ./scripts/git-worktree.sh feat/your-feature"
  exit 1
fi
```

### Force Push Rules

**Never force push to**:
- main
- production
- Any shared branch

**Safe force push** (feature branches only):
```bash
# Only if you're sure no one else is using this branch
git push --force-with-lease origin feat/my-feature

# Better: Create new branch
git checkout -b feat/my-feature-v2
git push origin feat/my-feature-v2
```

### Commit Amend Rules

**Safe to amend when**:
- Commit not yet pushed
- You're the only one on the branch
- Just fixing a typo in commit message

**Never amend when**:
- Commit already pushed
- Branch is shared
- Commit is on main/production

**Amend Example**:
```bash
# Safe: Fix typo before push
git commit --amend -m "fix: resolve validation bug (not 'bug')"

# Unsafe: After push
git commit --amend  # ❌ Don't do this
git push --force    # ❌ Really don't do this
```

### Revert vs Reset

**Revert** (safe, creates new commit):
```bash
# Undo a commit by creating opposite commit
git revert abc123

# Revert last commit
git revert HEAD

# Revert range
git revert abc123..def456
```

**Reset** (destructive, rewrites history):
```bash
# Only use for local commits not pushed
git reset --soft HEAD~1  # Keep changes staged
git reset --mixed HEAD~1  # Keep changes unstaged (default)
git reset --hard HEAD~1  # Discard changes ⚠️

# Never on shared branches
```

## Common Workflows

### Workflow 1: Create Feature Branch

```bash
# 1. Ensure main directory is on dev
cd ~/GitHub/myproject
git checkout dev
git pull

# 2. Create worktree for feature
./scripts/git-worktree.sh feat/user-auth

# 3. Start development
# (work in ~/GitHub/myproject-worktrees/feat-user-auth/)

# 4. Commit with co-author
git add .
git commit -m "$(cat <<'EOF'
feat: add user authentication service

Implemented OAuth 2.0 with Google provider, JWT token management,
and RLS policies for user data isolation.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"

# 5. Push to remote
git push -u origin feat/user-auth

# 6. Create PR via GitHub CLI
gh pr create --title "feat: add user authentication (#42)" \
  --body "Implements OAuth 2.0 authentication system. Closes #42"
```

### Workflow 2: Update Feature Branch

```bash
# 1. Fetch latest changes
git fetch origin

# 2. Rebase on dev
git checkout feat/user-auth
git rebase origin/dev

# 3. Resolve conflicts (if any)
# ... edit files ...
git add .
git rebase --continue

# 4. Force push (with lease for safety)
git push --force-with-lease origin feat/user-auth
```

### Workflow 3: Fix During Review

```bash
# 1. Make changes based on review
# ... edit files ...

# 2. Amend existing commit (if just one commit)
git add .
git commit --amend --no-edit

# 3. Force push
git push --force-with-lease origin feat/user-auth

# OR: Add new commit (if multiple commits)
git add .
git commit -m "$(cat <<'EOF'
refactor: address PR review feedback

- Improved error handling in auth service
- Added JSDoc comments for public methods
- Extracted validation logic to separate function

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
git push origin feat/user-auth
```

### Workflow 4: Clean Up After Merge

```bash
# 1. Switch back to main directory
cd ~/GitHub/myproject

# 2. Update dev branch
git checkout dev
git pull

# 3. Remove worktree
./scripts/git-worktree.sh --remove feat/user-auth

# 4. Delete remote branch (if not auto-deleted)
git push origin --delete feat/user-auth

# 5. Prune local references
git fetch --prune
```

## Troubleshooting

### Accidentally Committed to Wrong Branch

```bash
# 1. Check what you committed
git log -1

# 2. Create branch from current commit
git branch feat/accidental-work

# 3. Reset original branch
git reset --hard HEAD~1

# 4. Switch to new branch
git checkout feat/accidental-work
```

### Committed Secrets

```bash
# 1. Immediately rotate secrets (API keys, passwords, etc.)

# 2. If not pushed yet
git reset --soft HEAD~1
# Remove secrets from files
git add .
git commit -m "fix: remove accidentally committed secrets"

# 3. If already pushed (requires force push)
git reset --soft HEAD~1
# Remove secrets
git add .
git commit -m "fix: remove secrets"
git push --force-with-lease origin branch-name

# 4. For older commits, use BFG Repo-Cleaner or git filter-repo
# See: https://rtyley.github.io/bfg-repo-cleaner/
```

### Merge Conflict Resolution

```bash
# 1. Attempt merge/rebase
git rebase origin/dev
# CONFLICT (content): Merge conflict in file.ts

# 2. View conflicted files
git status

# 3. Open conflicted file, resolve markers
# <<<<<<< HEAD (your changes)
# =======
# >>>>>>> origin/dev (their changes)

# 4. Stage resolved files
git add file.ts

# 5. Continue rebase
git rebase --continue

# 6. If too complex, abort and ask for help
git rebase --abort
```

### Detached HEAD State

```bash
# You're in detached HEAD (checking out a commit directly)
git checkout abc123
# HEAD detached at abc123

# Option 1: Return to branch
git checkout dev

# Option 2: Create branch from here
git checkout -b feat/experiment

# Option 3: Just look around (no changes)
git checkout dev  # Return when done
```

## Git Hooks Integration

**Managed by Lefthook** (`.lefthook.yml`):

```yaml
pre-commit:
  parallel: true
  commands:
    format:
      glob: '*.{js,jsx,ts,tsx,json,md}'
      run: pnpm prettier --write {staged_files}
      stage_fixed: true

    check-main-branch:
      run: |
        BRANCH=$(git rev-parse --abbrev-ref HEAD)
        REPO_ROOT=$(git rev-parse --show-toplevel)
        if [[ "$REPO_ROOT" != *"-worktrees"* && "$BRANCH" == "main" ]]; then
          echo "❌ Cannot commit to main in main directory"
          exit 1
        fi

commit-msg:
  commands:
    check-conventional:
      run: |
        MSG=$(cat "$1")
        if ! echo "$MSG" | grep -qE "^(feat|fix|refactor|docs|test|chore|perf|style):"; then
          echo "❌ Commit message must follow conventional commits format"
          echo "   Format: <type>: <description>"
          exit 1
        fi
```

## Advanced Patterns

### Interactive Rebase

**Clean up commits before PR**:
```bash
# Rebase last 3 commits interactively
git rebase -i HEAD~3

# In editor:
# pick abc123 feat: add user model
# squash def456 fix typo  # Combine with previous
# reword ghi789 feat: add validation  # Edit message

# Result: 2 clean commits instead of 3
```

### Cherry-Pick Commits

**Apply specific commit from another branch**:
```bash
# On target branch
git checkout dev

# Cherry-pick commit from feature branch
git cherry-pick abc123

# Cherry-pick range
git cherry-pick abc123..def456

# Cherry-pick without committing (for review)
git cherry-pick --no-commit abc123
```

### Git Bisect (Find Bug)

**Binary search to find regression**:
```bash
# Start bisect
git bisect start

# Mark current as bad
git bisect bad

# Mark known good commit
git bisect good abc123

# Git checks out middle commit, test it
pnpm test
# If test passes:
git bisect good
# If test fails:
git bisect bad

# Repeat until Git finds first bad commit
# Git will output: "abc123 is the first bad commit"

# End bisect
git bisect reset
```

### Stash Work in Progress

**Save work without committing**:
```bash
# Stash current changes
git stash push -m "WIP: working on auth service"

# List stashes
git stash list

# Apply most recent stash
git stash pop

# Apply specific stash
git stash apply stash@{1}

# View stash contents
git stash show -p stash@{0}

# Delete stash
git stash drop stash@{0}
```

## GitHub CLI Integration

**Install**:
```bash
# macOS
brew install gh

# Authenticate
gh auth login
```

**Common Operations**:
```bash
# Create PR
gh pr create --title "feat: add feature" --body "Description"

# View PRs
gh pr list

# View PR details
gh pr view 123

# Check out PR locally
gh pr checkout 123

# Merge PR
gh pr merge 123 --squash

# Add reviewers
gh pr edit 123 --add-reviewer @user1,@user2

# View PR status checks
gh pr checks 123

# Comment on PR
gh pr comment 123 --body "LGTM!"
```

## References

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Worktree Documentation](https://git-scm.com/docs/git-worktree)
- [GitHub Flow Guide](https://docs.github.com/en/get-started/quickstart/github-flow)
- [Lefthook Documentation](https://github.com/evilmartians/lefthook)

---

**Last Updated**: 2026-01-13
**Related**: [HOOKS_GUIDE.md](HOOKS_GUIDE.md), [QUALITY_GATES_GUIDE.md](QUALITY_GATES_GUIDE.md)

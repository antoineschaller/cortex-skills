# Engineering Standards Skill

Comprehensive engineering standards for monorepo projects with Claude Code, covering hooks, testing, documentation, quality gates, and best practices.

## Overview

The **engineering-standards** skill captures proven engineering practices and makes them portable across all projects. It serves as the "engineering constitution" - documenting hooks, test suites, CLAUDE.md standards, quality gates, and providing scripts to validate compliance and bootstrap new projects.

### What's Included

✅ **11 Comprehensive Guides** (~9,500 lines of documentation)
✅ **3 Configuration Files** (validation rules, template variables, framework extensions)
✅ **7 Template Files** (lefthook, CLAUDE.md, vitest, eslint, settings, env, gitignore)
✅ **Validation Scripts** (validate-compliance.py, bootstrap-project.py, sync-from-project.py)
✅ **Framework-Agnostic Core** with framework-specific extensions
✅ **Integration with cortex-doc-standards** for CLAUDE.md generation

## Quick Start

### Use as a Skill in Claude Code

```bash
# Invoke the skill for detailed patterns
/engineering-standards

# Get specific guidance
"Show me pre-commit hook patterns from engineering-standards"
"What are the RLS-first patterns?"
"How should I structure WIP files?"
```

### Bootstrap a New Project

```bash
# Using the bootstrap script (coming in Phase 3)
python scripts/bootstrap-project.py \
  --project-name "My Project" \
  --project-type nextjs \
  --framework makerkit \
  --output-path ./new-project
```

### Validate Existing Project

```bash
# Using the validation script (coming in Phase 2)
python scripts/validate-compliance.py --project-path . --report-format markdown
```

## File Structure

```
engineering-standards/
├── SKILL.md                     # Overview and quick reference (493 lines)
├── CHANGELOG.md                 # Version history (320 lines)
├── README.md                    # This file
│
├── Documentation Guides (~9,500 lines total):
│   ├── HOOKS_GUIDE.md           # Git hooks & Claude hooks (1,340 lines)
│   ├── TESTING_GUIDE.md         # Vitest, Playwright, Flutter testing (1,220 lines)
│   ├── SECURITY_GUIDE.md        # RLS, auth, secrets management (1,020 lines)
│   ├── PATTERNS_LIBRARY.md      # Architectural patterns (850 lines)
│   ├── DOCUMENTATION_GUIDE.md   # WIP files, guides, organization (790 lines)
│   ├── CLAUDE_MD_GUIDE.md       # CLAUDE.md structure (690 lines)
│   ├── MONOREPO_GUIDE.md        # Turborepo, pnpm, workspaces (1,030 lines)
│   ├── GIT_WORKFLOW_GUIDE.md    # Branches, commits, PRs (1,460 lines)
│   ├── QUALITY_GATES_GUIDE.md   # Lint, typecheck, format (370 lines)
│
├── config/
│   ├── rules-config.json        # Validation rules (30+ checks)
│   ├── project-variables.json   # Template variables for customization
│   └── framework-extensions.json # Framework-specific additions
│
├── templates/
│   ├── lefthook.yml.template    # Git hooks template
│   ├── CLAUDE.md.template       # CLAUDE.md skeleton
│   ├── vitest.config.ts.template # Test configuration
│   ├── eslint.config.mjs.template # ESLint configuration
│   ├── settings.json.template   # Claude Code hooks
│   ├── .env.local.example       # Environment variables
│   └── .gitignore               # Git ignore patterns
│
└── scripts/ (Coming in Phase 2 & 3)
    ├── validate-compliance.py   # Check project compliance
    ├── bootstrap-project.py     # Set up new project
    ├── sync-from-project.py     # Extract patterns from existing project
    └── generate-report.py       # Compliance report generation
```

## Standards Covered

### 1. Hooks (HOOKS_GUIDE.md)

**Pre-commit hooks** (<2s target):
- Format (Prettier auto-fix)
- WIP validation (structure, staleness)
- Migration idempotency validation
- RLS policy validation
- Root MD file blocking
- JSON key validation

**Pre-push hooks** (30-60s target):
- Oxlint (fast sanity check)
- TypeScript (full typecheck)
- Lockfile sync
- DB type validation

**Claude Code hooks**:
- PreToolUse (forbidden suffixes, root MD files, direct DB)
- PostToolUse (migration warnings)

### 2. Testing (TESTING_GUIDE.md)

**Vitest patterns**:
- Dual-client architecture for RLS testing
- 80% coverage threshold
- Separate TEST instance
- Module aliasing for monorepo

**Playwright patterns**:
- Auth-based project setup
- Sequential vs parallel execution
- RLS policy testing

**Flutter testing**:
- Unit tests with Riverpod mocking
- Widget tests with golden tests
- Integration tests
- Query validation against schema

### 3. Security (SECURITY_GUIDE.md)

**RLS-first pattern**:
- Use userClient + RLS by default
- Admin client only with validation
- Super admin bypass via `is_super_admin()`

**Migration security**:
- Idempotency validation
- SQL injection prevention
- No direct psql commands

**Secret management**:
- Never hardcode
- Use .env.local
- 1Password integration
- Vercel env var gotcha (printf not echo)

### 4. Patterns (PATTERNS_LIBRARY.md)

**Result pattern**:
- Services return `Result<T, E>` instead of throwing
- Consistent error handling
- Type-safe results

**Server actions** (Next.js):
- `withAuthParams` integration
- Zod validation
- `revalidatePath` after mutations

**Data isolation**:
- `account_id` for workspaces
- `client_id` for external orgs

**N+1 prevention**:
- Batch queries
- In-memory aggregation

### 5. Documentation (DOCUMENTATION_GUIDE.md)

**Location-based classification**:
- `docs/wip/active/` - Temporary work (WIP_{gerund}_{date})
- `docs/guides/` - Permanent how-to docs
- `docs/architecture/` - Design decisions
- `docs/investigations/` - Completed investigations

**WIP management**:
- Naming convention (gerund form)
- Required sections (Last Updated, Objective)
- 7-day staleness limit
- Archive after completion

**Forbidden patterns**:
- Root .md files (except CLAUDE.md, README.md)
- "Deferred", "TODO", "out of scope" in WIPs

### 6. CLAUDE.md Structure (CLAUDE_MD_GUIDE.md)

**Required sections**:
- Tech Stack
- Project Structure
- Essential Commands
- Critical Rules (NO EXCEPTIONS)
- Core Patterns

**Subdirectory pattern**:
- Each package gets focused CLAUDE.md
- Reduced context size
- Faster AI comprehension

**Integration**:
- Uses `cortex-doc-standards` for generation
- Validation against rules
- Variable substitution for project-specific content

### 7. Monorepo (MONOREPO_GUIDE.md)

**Package structure**:
- `apps/` - Deployable applications
- `packages/` - Shared libraries
- `tools/` - Build tools and scripts

**pnpm workspaces**:
- `workspace:*` protocol for local packages
- Filtering for targeted commands
- Lockfile discipline

**Turborepo**:
- Build caching (local + remote)
- Affected packages optimization
- Dependency-aware builds

**Syncpack**:
- Consistent dependency versions
- Automated version fixes

### 8. Git Workflow (GIT_WORKFLOW_GUIDE.md)

**Worktree-based branching**:
- Main directory stays on default branch
- Feature branches use worktrees
- Fast context switching

**Conventional commits**:
- `<type>: <description> (<reference>)`
- Claude co-authoring on all AI-assisted commits
- HEREDOC pattern for multi-line messages

**PR workflow**:
- Templates with checklists
- Branch protection rules
- GitHub Actions integration

### 9. Quality Gates (QUALITY_GATES_GUIDE.md)

**Sequential execution**:
1. Format (Prettier)
2. Lint (ESLint + Oxlint)
3. Typecheck (TypeScript strict mode)
4. Test (Vitest + Playwright)
5. Build (production build must succeed)

**Custom ESLint plugins**:
- `react-providers` - Enforce context providers
- `i18n` - Validate translation keys
- `react-form-fields` - Validate form field naming

**Performance**:
- Caching strategies (Turborepo)
- Parallel execution (Lefthook)
- Affected packages only

## Framework Support

### Core Frameworks

- **Next.js** - Server components, async params, metadata
- **Flutter** - Riverpod 3.x, Freezed, golden tests
- **Supabase** - RLS-first, migration idempotency, type generation
- **Turborepo** - Monorepo build caching
- **Vitest** - Testing with dual-client architecture
- **Playwright** - E2E testing with auth projects

### Framework-Specific Extensions

Extensions in `config/framework-extensions.json` provide:
- Required files and structure
- Critical patterns
- Quality configuration
- Dependency requirements

**Supported extensions**:
- Next.js 15+
- Flutter 3.x
- MakerKit 2.x
- ApparenceKit 1.x
- Supabase 2.x
- Turborepo 2.x
- Vitest 2.x
- Playwright 1.40+
- ESLint 9.x

## Configuration

### Validation Rules (config/rules-config.json)

**Categories** (8 total):
1. **Hooks** - Git hooks and Claude hooks (weight: 15%)
2. **Documentation** - CLAUDE.md, WIP files, guides (weight: 15%)
3. **Testing** - Vitest, Playwright, coverage (weight: 15%)
4. **Quality Gates** - Lint, typecheck, format (weight: 15%)
5. **Git** - .gitignore, branch protection (weight: 10%)
6. **Security** - RLS, env vars, secrets (weight: 15%)
7. **Naming** - File/function naming conventions (weight: 10%)
8. **Migrations** - Idempotency, IF NOT EXISTS (weight: 5%)

**Severity levels**:
- **Critical** (exit 2) - Must fix before merge
- **Warning** (exit 1) - Should fix, not blocking
- **Info** (exit 0) - Informational

**Grading**:
- A (95%+) - Excellent, full compliance
- B (85-94%) - Good, minor improvements
- C (70-84%) - Acceptable, several improvements
- D (50-69%) - Poor, significant work needed
- F (<50%) - Failing, major issues

### Template Variables (config/project-variables.json)

**Substitution categories**:
- Project metadata (name, description, author)
- Tech stack (language, runtime, package manager)
- Features (database, auth, testing, monorepo)
- Paths (apps/, packages/, docs/, migrations/)
- Commands (install, dev, build, test, quality)
- Git (default branch, GitHub org/repo)
- Quality (coverage threshold, ESLint plugins)

**Filters**:
- `slugify` - Convert to URL-safe slug
- `pascalcase` - Convert to PascalCase
- `uppercase` - Convert to UPPERCASE
- `lowercase` - Convert to lowercase

### Framework Extensions (config/framework-extensions.json)

**Extension types**:
- Required files and directory structure
- Critical patterns and best practices
- Quality configuration overrides
- Required dependencies

**Priority order**:
1. Project type
2. Framework-specific
3. Database
4. Testing
5. Monorepo
6. Linting

## Integration with cortex-doc-standards

The engineering-standards skill **references** cortex-doc-standards rather than duplicating logic:

```bash
# Generate CLAUDE.md using cortex-doc-standards
npx cortex-doc-standards rules init --type nextjs --name "My Project"
npx cortex-doc-standards generate-claude
npx cortex-doc-standards validate --file CLAUDE.md
```

**Benefits**:
- Single source of truth for CLAUDE.md structure
- No code duplication
- Standards skill focuses on broader engineering practices
- cortex-doc-standards handles document-specific validation

## Roadmap

### Phase 1: Core Documentation ✅ COMPLETED
- [x] 11 comprehensive guides (~9,500 lines)
- [x] 3 configuration files
- [x] 7 template files
- [x] README and CHANGELOG

### Phase 2: Validation Scripts (Upcoming)
- [ ] `validate-compliance.py` - 30+ compliance checks
- [ ] `generate-report.py` - Compliance reporting
- [ ] `check-standards.sh` - Quick validation script
- [ ] Test against Ballee (should pass 95%+)

### Phase 3: Bootstrapping & Sync (Upcoming)
- [ ] `bootstrap-project.py` - New project setup
- [ ] `sync-from-project.py` - Pattern extraction
- [ ] Template file generation
- [ ] Test bootstrap with empty directory

### Phase 4: Testing & Documentation (Upcoming)
- [ ] End-to-end testing of all scripts
- [ ] Usage examples for each workflow
- [ ] Troubleshooting section
- [ ] Marketplace integration

## Usage Examples

### Example 1: Check Compliance

```bash
# Run validation (coming in Phase 2)
python scripts/validate-compliance.py --project-path .

# Output:
# ✓ Hooks: lefthook.yml configured (12/12 checks passed)
# ✓ Documentation: CLAUDE.md structure valid
# ⚠ Quality Gates: ESLint config missing react-providers plugin
# ✗ Naming: Found 3 files with version suffixes
#
# Overall: 7/8 categories passed (87.5% compliance)
```

### Example 2: Bootstrap Project

```bash
# Create new project (coming in Phase 3)
python scripts/bootstrap-project.py \
  --project-name "My SaaS" \
  --project-type nextjs \
  --framework makerkit \
  --output-path ./my-saas

# Output:
# ✓ Directory structure created
# ✓ Templates copied and customized
# ✓ Git repository initialized
# ✓ Lefthook installed
# ✓ Dependencies installed
# ✓ CLAUDE.md generated
```

### Example 3: Extract Patterns

```bash
# Extract patterns from mature project (coming in Phase 3)
python scripts/sync-from-project.py \
  --source-project /path/to/ballee \
  --extract hooks,testing,patterns \
  --update-standards

# Output:
# 🔍 Analyzing: /path/to/ballee
# Extracted Patterns:
# ✓ Hooks: 15 pre-commit commands, 8 pre-push commands
# ✓ Testing: Vitest dual-client architecture pattern
# New Patterns Found:
# + Migration idempotency validation (not in standards)
```

## Success Criteria

### Functional Requirements
✅ All 11 guide files comprehensive and accurate
✅ All 3 configuration files complete
✅ All 7 template files ready for use
⏳ validate-compliance.py runs 30+ checks (Phase 2)
⏳ bootstrap-project.py creates functional project (Phase 3)
⏳ sync-from-project.py extracts patterns (Phase 3)
⏳ generate-report.py produces detailed reports (Phase 2)

### Quality Requirements
⏳ Ballee validation shows 95%+ compliance (Phase 2)
⏳ Bootstrap creates project that passes quality gates (Phase 3)
✅ Documentation is clear, scannable, actionable
⏳ Examples work without modification (Phase 4)
⏳ Scripts work on macOS and Linux (Phase 2-3)

### Portability Requirements
✅ Works across Next.js, Flutter, monorepo, backend projects
✅ Framework-agnostic core with extensions
✅ Can be customized per project
✅ Scales from small projects to large monorepos

## Version History

### v1.0.0 (2026-01-13)

**Added**:
- 11 comprehensive documentation guides
- 3 configuration files (rules, variables, extensions)
- 7 template files (hooks, config, env)
- Framework-agnostic core with framework extensions
- Integration with cortex-doc-standards

**Documentation**:
- HOOKS_GUIDE.md - Git hooks & Claude hooks (1,340 lines)
- TESTING_GUIDE.md - Vitest, Playwright, Flutter testing (1,220 lines)
- SECURITY_GUIDE.md - RLS, auth, secrets management (1,020 lines)
- PATTERNS_LIBRARY.md - Architectural patterns (850 lines)
- DOCUMENTATION_GUIDE.md - WIP files, guides, organization (790 lines)
- CLAUDE_MD_GUIDE.md - CLAUDE.md structure (690 lines)
- MONOREPO_GUIDE.md - Turborepo, pnpm, workspaces (1,030 lines)
- GIT_WORKFLOW_GUIDE.md - Branches, commits, PRs (1,460 lines)
- QUALITY_GATES_GUIDE.md - Lint, typecheck, format (370 lines)

See [CHANGELOG.md](CHANGELOG.md) for full details.

## Contributing

To contribute to engineering-standards:

1. Create WIP file in `docs/wip/active/WIP_{description}_{YYYY_MM_DD}.md`
2. Make changes to guides, configs, or templates
3. Update CHANGELOG.md with your changes
4. Run validation (when scripts available)
5. Create PR with conventional commit format

## License

MIT License - See LICENSE.md for details

## Sources

Research and analysis based on:
- [Monorepo Explained](https://monorepo.tools/)
- [The Ultimate Guide to Building a Monorepo in 2026](https://medium.com/@sanjaytomar717/the-ultimate-guide-to-building-a-monorepo-in-2025-sharing-code-like-the-pros-ee4d6d56abaa)
- [Cortex-skills repository](https://github.com/antoineschaller/cortex-skills)
- [Cortex-packages doc-standards](https://github.com/antoineschaller/cortex-packages/tree/main/packages/doc-standards)
- Ballee codebase (baseline for excellent engineering practices)

---

**Status**: Phase 1 Complete (Documentation & Configuration)
**Next**: Phase 2 (Validation Scripts)
**Last Updated**: 2026-01-13

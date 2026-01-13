# Changelog

All notable changes to the Engineering Standards skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-13

### Added

#### Core Documentation
- **SKILL.md** - Overview and navigation hub (< 500 lines with progressive disclosure)
- **HOOKS_GUIDE.md** - Git hooks (pre-commit, pre-push) and Claude Code hooks
- **TESTING_GUIDE.md** - Vitest, Playwright, and Flutter testing standards
- **CLAUDE_MD_GUIDE.md** - CLAUDE.md structure and best practices
- **QUALITY_GATES_GUIDE.md** - Lint, typecheck, format, and build standards
- **GIT_WORKFLOW_GUIDE.md** - Branch strategy, commits, and PR workflow
- **DOCUMENTATION_GUIDE.md** - WIP files, guides, and architecture docs
- **MONOREPO_GUIDE.md** - Turborepo, pnpm workspaces, and shared packages
- **SECURITY_GUIDE.md** - Secrets management, RLS patterns, and auth wrappers
- **PATTERNS_LIBRARY.md** - Common architectural patterns

#### Validation & Automation Scripts
- **validate-compliance.py** - Check project compliance with 30+ validation rules
- **bootstrap-project.py** - Set up new projects with all standards
- **sync-from-project.py** - Extract patterns from existing mature projects
- **generate-report.py** - Generate detailed compliance reports (markdown, JSON, HTML)
- **check-standards.sh** - Quick validation script for CI/CD

#### Configuration
- **config/rules-config.json** - Configurable validation rules
- **config/project-variables.json** - Template variables for customization
- **config/framework-extensions.json** - Framework-specific additions

#### Templates
- **templates/lefthook.yml.template** - Git hooks configuration
- **templates/CLAUDE.md.template** - CLAUDE.md skeleton
- **templates/vitest.config.ts.template** - Vitest test configuration
- **templates/eslint.config.mjs.template** - ESLint configuration
- **templates/settings.json.template** - Claude Code settings
- **templates/.env.local.example** - Environment variables template
- **templates/.gitignore** - Standard git ignore patterns

### Features

#### Hooks & Automation
- Pre-commit hooks with <2s target (format, WIP validation, migration idempotency)
- Pre-push hooks with 30-60s target (lint, typecheck, lockfile sync)
- Claude Code PreToolUse hooks (forbidden suffixes, root MD files, direct DB)
- Claude Code PostToolUse hooks (migration idempotency warnings)
- Lefthook parallel execution and THOROUGH mode support

#### Testing Standards
- Vitest configuration with 80% coverage thresholds
- Separate TEST instance pattern (port 54421)
- Playwright dual-client architecture for RLS testing
- Flutter testing patterns (unit, widget, golden, integration)
- Test organization by feature with coverage tracking

#### Documentation Standards
- Location-based classification (wip/active/, guides/, architecture/)
- WIP naming convention (WIP_{gerund}_{YYYY_MM_DD}.md)
- 7-day staleness validation for active WIPs
- Root MD file blocking (except CLAUDE.md, README.md)
- Subdirectory CLAUDE.md pattern for package-specific context

#### Quality Gates
- ESLint with custom plugins (i18n, react-providers, react-form-fields)
- Oxlint for fast sanity checks (10-100x faster)
- TypeScript strict mode enforcement
- Prettier auto-fix on pre-commit
- Sequential quality command execution

#### Git Workflow
- Worktree-based branch strategy for feature isolation
- Conventional commit format with Claude co-authoring
- Branch naming conventions (feat/, fix/, refactor/, docs/)
- PR templates and review requirements
- Protected branch policies (no force push to main)

#### Monorepo Patterns
- apps/ vs packages/ organization
- pnpm workspace configuration
- Turborepo build caching and task pipelines
- Affected packages optimization
- Syncpack for dependency version management

#### Security Standards
- RLS-first data access pattern
- Environment variable management (.env.local, 1Password, Vercel)
- Migration idempotency validation
- Auth wrapper patterns (withAuth, withAuthParams, withSuperAdmin)
- Audit logging for admin operations

#### Architectural Patterns
- Service layer with Result<T, E> pattern (no exceptions)
- Server actions with withAuthParams integration
- N+1 query prevention (batch queries + in-memory aggregation)
- Soft delete pattern (deleted_at timestamp)
- Data isolation (account_id vs client_id)

#### Integration
- cortex-doc-standards integration for CLAUDE.md generation
- Reference pattern (no logic duplication)
- Bootstrap script calls cortex-doc-standards
- Validation script uses cortex-doc-standards for CLAUDE.md checks

### Technical Details

#### Validation Coverage
- 30+ validation checks across 8 categories
- Hooks presence validation (lefthook.yml, Claude settings)
- Documentation structure checks (CLAUDE.md, docs directories)
- Testing configuration validation (coverage thresholds, separate instance)
- Quality gates presence (ESLint, TypeScript strict, Prettier)
- Security checks (env example, no hardcoded secrets, RLS policies)
- Naming convention enforcement (kebab-case, no version suffixes)
- Migration standards (IF NOT EXISTS, idempotency patterns)

#### Bootstrap Capabilities
- 20+ automated setup steps
- Directory structure creation (apps/, packages/, docs/)
- Template copying with variable substitution
- Configuration generation (package.json, tsconfig.json, .gitignore)
- Git initialization and lefthook installation
- cortex-doc-standards config generation
- Placeholder documentation creation

#### Pattern Extraction
- Hook pattern analysis (lefthook.yml scanning)
- Test configuration extraction (vitest.config.ts, playwright.config.ts)
- CLAUDE.md structure analysis
- Architectural pattern detection
- Custom ESLint rule extraction
- Quality script identification

#### Compliance Reporting
- Executive summary with compliance percentage
- Category-by-category breakdown
- Detailed findings (passed, warnings, failures)
- Prioritized recommendations
- Historical comparison support
- Multiple output formats (markdown, JSON, HTML)

### Standards Captured from Ballee

All patterns extracted from production Ballee codebase (95%+ compliance baseline):

#### Multi-Layer Enforcement
- Claude Code hooks for real-time validation
- Git hooks (lefthook) for commit/push gates
- CI/CD pipelines for final verification
- ESLint for static analysis
- Runtime checks for critical operations

#### Fast Feedback Loops
- Pre-commit hooks <2s (oxlint, Prettier auto-fix)
- Pre-push hooks <60s (typecheck, oxlint)
- Parallel execution where possible
- Smart caching with Turborepo
- THOROUGH mode for comprehensive checks

#### Developer Ergonomics
- Clear error messages with actionable fixes
- Gentle warnings for non-critical issues
- Auto-fix where safe (Prettier formatting)
- Skip patterns for edge cases
- Documentation cross-references in error messages

#### Production Safety
- Migration idempotency validation
- RLS policy validation before deployment
- Type sync automation (web & Flutter)
- Separate TEST instance (no dev data corruption)
- Audit logging for sensitive operations

### Tested and Validated

#### Phase 2: Validation Scripts Testing
- **Ballee Project Validation**: 80.0% compliance (Grade: C)
  - Found 193 non-idempotent migrations (real issue)
  - Correctly identified all config files in monorepo structure
  - Validated hooks, documentation, testing, quality gates
  - Exit code 2 (critical failures) - working as designed

- **Empty Project Validation**: 32.9% compliance (Grade: F)
  - Correctly detected all missing files
  - Appropriate severity levels (critical vs warning)
  - Exit code 2 (critical failures) - working as designed

- **Report Generation**: Successfully generated markdown, HTML, and JSON reports
  - Executive summary with compliance percentage
  - Category breakdown with detailed findings
  - Prioritized recommendations

#### Phase 3: Bootstrap & Sync Testing
- **Bootstrap New Project**: 98.5% compliance (Grade: A)
  - Created 12 directories with proper structure
  - Copied and processed 7 template files
  - Variable substitution working correctly
  - Git initialized with proper co-authoring commit
  - All quality gates configured and passing
  - Only missing: .prettierrc (optional)

- **Pattern Extraction from Ballee**: 52 patterns extracted
  - Hooks: 22 patterns (9 pre-commit, 11 pre-push, 4 Claude hooks)
  - Documentation: 22 patterns (21 CLAUDE.md sections, WIP naming)
  - Quality Gates: 5 patterns (3 custom ESLint plugins, strict mode, quality command)
  - Testing: 2 patterns (80% coverage threshold, jsdom environment)
  - Migrations: 1 pattern (IF NOT EXISTS idempotency)
  - **51 new patterns identified** not yet in current standards
  - Statistics: 672 migrations, 183 service files, 7 active WIPs

#### Script Performance
- **validate-compliance.py**: 30+ checks in <5 seconds
- **check-standards.sh**: Quick validation in <2 seconds
- **bootstrap-project.py**: Project setup in <1 second (without npm install)
- **sync-from-project.py**: Pattern extraction in <3 seconds
- **generate-report.py**: Report generation in <2 seconds

### Sources

Standards and patterns based on:
- [Ballee production codebase](https://github.com/antoineschaller/ballee) - Baseline for excellence
- [Monorepo Explained](https://monorepo.tools/) - Monorepo best practices
- [The Ultimate Guide to Building a Monorepo in 2026](https://medium.com/@sanjaytomar717/the-ultimate-guide-to-building-a-monorepo-in-2025-sharing-code-like-the-pros-ee4d6d56abaa) - Latest patterns
- [cortex-skills repository](https://github.com/antoineschaller/cortex-skills) - Skill distribution
- [cortex-doc-standards](https://github.com/antoineschaller/cortex-packages/tree/main/packages/doc-standards) - CLAUDE.md validation

---

[1.0.0]: https://github.com/antoineschaller/cortex-skills/releases/tag/engineering-standards/v1.0.0

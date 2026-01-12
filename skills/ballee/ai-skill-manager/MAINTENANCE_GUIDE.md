# Skill Maintenance Guide

Comprehensive guide for maintaining Claude Code skills: version control, updates, deprecation, and quality management.

## Table of Contents

1. [Update Triggers](#update-triggers)
2. [Version Control](#version-control)
3. [Deprecation Process](#deprecation-process)
4. [Quality Metrics](#quality-metrics)
5. [Maintenance Workflows](#maintenance-workflows)

---

## Update Triggers

### When to Update Skills

**Framework Updates:**
- **Major version bump** (e.g., Next.js 15 → 16, Flutter 3.24 → 3.27)
  - Update all code examples
  - Add migration guides for breaking changes
  - Update version references throughout

- **Minor version** (e.g., Riverpod 2.6 → 3.0)
  - Update affected patterns
  - Document new features
  - Add compatibility notes

**API Changes:**
- **Deprecations** (e.g., `AsyncValue.valueOrNull` → `AsyncValue.value`)
  - Add deprecation warnings
  - Show old → new migration
  - Update all examples

- **New APIs** (e.g., Flutter 3.27 spacing parameter)
  - Add new patterns
  - Show before/after comparisons
  - Update quick reference

**Best Practice Evolution:**
- **Industry standards change** (e.g., WCAG 2.1 → 2.2)
  - Update compliance requirements
  - Add new success criteria
  - Revise testing patterns

- **Performance improvements discovered** (e.g., INP replaces FID)
  - Update metrics and targets
  - Add optimization patterns
  - Revise measurement techniques

**User-Reported Issues:**
- **Skill doesn't work** - Debug, fix, test thoroughly, update docs
- **Examples fail** - Fix code, verify execution, add error handling
- **Confusing instructions** - Clarify language, add examples, improve structure
- **Missing features** - Assess scope, implement or reference other skills

**Token Usage Issues:**
- **Skill exceeds 500 lines** - Implement progressive disclosure
- **Context window complaints** - Split into multiple files, reference externally
- **Load time too long** - Optimize content, remove redundancy

### Update Indicators Checklist

Run quarterly skill audits to identify:

- [ ] Framework version mismatches (check package.json, pubspec.yaml)
- [ ] Deprecated APIs in code examples
- [ ] Outdated best practices (search for WCAG 2.1, FID, old patterns)
- [ ] Broken links to external docs
- [ ] Missing recent features (e.g., Flutter 3.27 additions)
- [ ] User feedback in issue tracker
- [ ] Token usage > 5k tokens
- [ ] Discovery rate < 90%

---

## Version Control

### Semantic Versioning

Use `MAJOR.MINOR.PATCH` format:

```yaml
---
name: skill-name
version: "1.2.3"
last_updated: "2026-01-12"
---
```

**Version Increment Rules:**

| Change Type | Version | Example |
|-------------|---------|---------|
| **Breaking changes** | MAJOR | 1.x.x → 2.0.0 |
| **New features (backward-compatible)** | MINOR | 1.2.x → 1.3.0 |
| **Bug fixes, docs** | PATCH | 1.2.3 → 1.2.4 |

### Breaking vs. Non-Breaking Changes

**Breaking Changes (MAJOR bump):**
- Removing sections or patterns
- Changing file structure significantly
- Removing scripts or utilities
- Changing skill interface (e.g., required environment variables)
- Incompatible with previous usage

**Non-Breaking Changes (MINOR bump):**
- Adding new sections
- Adding new patterns or examples
- Creating additional supporting files
- Expanding existing documentation
- New optional features

**Patch Changes (PATCH bump):**
- Fixing typos
- Clarifying instructions
- Updating examples without changing behavior
- Fixing broken links
- Minor formatting improvements

### CHANGELOG.md Management

**Create CHANGELOG.md in skill directory:**

```markdown
# Changelog

All notable changes to this skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- (Track future changes here)

## [1.2.0] - 2026-01-12

### Added
- New pattern for zero-downtime migrations with expand-contract
- Script for automatic migration validation
- Section on pgroll integration

### Changed
- Improved idempotency examples with more edge cases
- Updated PostgreSQL version references to 16
- Restructured troubleshooting section as table

### Fixed
- Corrected RLS policy example syntax
- Fixed broken link to Supabase documentation

## [1.1.0] - 2025-12-01

### Added
- Support for composite primary keys
- Pattern for handling foreign key constraints

### Changed
- Updated naming convention guidelines

## [1.0.0] - 2025-10-15

### Added
- Initial release
- Core migration patterns
- RLS policy generation
- Idempotent SQL examples

[Unreleased]: https://github.com/user/repo/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/user/repo/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/user/repo/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

### Git Workflow

**Commit Message Format:**

```bash
# Feature addition (MINOR)
git commit -m "feat(skill-name): add expand-contract migration pattern"

# Bug fix (PATCH)
git commit -m "fix(skill-name): correct RLS policy syntax in example"

# Breaking change (MAJOR)
git commit -m "feat(skill-name)!: restructure file organization

BREAKING CHANGE: SKILL.md now only contains overview, detailed content moved to REFERENCE.md"

# Documentation only (PATCH)
git commit -m "docs(skill-name): clarify idempotency requirements"
```

**Branching Strategy:**

```bash
# Feature branch for skill updates
git checkout -b feat/update-database-migration-skill

# Make changes to skill
# ... edit files ...

# Commit with semantic message
git add .claude/skills/database-migration-manager/
git commit -m "feat(database-migration-manager): add pgroll integration patterns"

# Push and create PR
git push origin feat/update-database-migration-skill
```

**Tagging Releases:**

```bash
# After merging skill update to main
git tag -a skill/database-migration-manager/v1.2.0 -m "Add pgroll integration patterns"
git push origin skill/database-migration-manager/v1.2.0
```

---

## Deprecation Process

### When to Deprecate

**Indicators:**
- Skill functionality merged into another skill
- Technology/framework no longer used
- Better alternative skill exists
- Usage metrics show < 5% invocation rate
- Maintenance burden too high

### Deprecation Workflow

**Phase 1: Mark as Deprecated (1 sprint)**

Update YAML frontmatter:
```yaml
---
name: old-skill
description: "[DEPRECATED] Use 'new-skill' instead. Old skill functionality has been superseded. [Old description for reference]"
version: "2.0.0"  # MAJOR bump for breaking change
last_updated: "2026-01-12"
---
```

Update SKILL.md content:
```markdown
# [DEPRECATED] Old Skill Name

> **⚠️ DEPRECATION NOTICE**: This skill is deprecated as of 2026-01-12.
> Please use [`new-skill`](../new-skill/SKILL.md) instead.

## Migration Guide

### What Changed

The functionality of this skill has been merged into `new-skill` with improvements:
- Feature X now available in `new-skill`
- Pattern Y has been enhanced
- Better performance and maintainability

### How to Migrate

**Before** (using old-skill):
```code
[Old pattern]
```

**After** (using new-skill):
```code
[New pattern]
```

## Deprecation Timeline

- **2026-01-12**: Deprecated, use `new-skill` instead
- **2026-02-12**: Archived (moved to `_archived/`)
- **2026-03-12**: May be removed entirely

## Original Documentation (Read-Only)

[Keep original docs for reference during transition]
```

**Phase 2: Monitor Usage (1 sprint)**

Track if skill is still being invoked:
```bash
# Search for skill invocations in last 30 days
grep "old-skill" ~/.claude/projects/*/transcript.jsonl | \
  grep -A 5 "$(date -d '30 days ago' +%Y-%m-%d)" | \
  wc -l
```

If usage drops to near zero, proceed to Phase 3.

**Phase 3: Archive (after 1-2 months)**

Move to archive directory:
```bash
mkdir -p .claude/skills/_archived
mv .claude/skills/old-skill .claude/skills/_archived/
```

Update README.md:
```markdown
## Archived Skills

| Skill | Deprecated | Archived | Replacement |
|-------|------------|----------|-------------|
| old-skill | 2026-01-12 | 2026-02-12 | `new-skill` |
```

**Phase 4: Optional Removal (after 6+ months)**

If no usage detected and team consensus:
```bash
rm -rf .claude/skills/_archived/old-skill
```

Document in root CHANGELOG:
```markdown
## [2026-08-12]

### Removed
- `old-skill` - Fully migrated to `new-skill`, no usage detected
```

### Merging Skills

**When to Merge:**
- Two skills have > 50% overlapping content
- Skills are always used together
- Combined size stays under 500 lines
- Clearer mental model for users

**Merge Process:**

1. **Plan the merged skill**:
   - New name (usually the more general one)
   - Combined description
   - Unified structure

2. **Create merged skill**:
   ```bash
   mkdir .claude/skills/merged-skill
   # Combine content from both skills
   # Organize by workflow, not by origin
   ```

3. **Deprecate original skills**:
   - Both skills point to merged skill
   - Include migration guide
   - Update cross-references

4. **Test thoroughly**:
   - Verify all patterns work
   - Test discovery with old trigger phrases
   - Ensure no functionality lost

### Splitting Skills

**When to Split:**
- Skill exceeds 500 lines and can't use progressive disclosure
- Distinct use cases with different trigger patterns
- Different tool requirements
- One part used much more frequently

**Split Process:**

1. **Identify split points**:
   - By workflow (creation vs. testing vs. optimization)
   - By technology (backend vs. frontend vs. mobile)
   - By complexity (basic vs. advanced)

2. **Create new skills**:
   ```bash
   # Example: flutter-development (1,620 lines) → split into 3
   mkdir .claude/skills/flutter-architecture-patterns
   mkdir .claude/skills/flutter-riverpod-state
   mkdir .claude/skills/flutter-supabase-integration
   ```

3. **Distribute content**:
   - Move focused content to each new skill
   - Avoid duplication (use cross-references instead)
   - Maintain working examples in each

4. **Update original skill**:
   ```yaml
   description: "[SPLIT] This skill has been split into specialized skills. Use flutter-architecture-patterns for structure, flutter-riverpod-state for state management, or flutter-supabase-integration for API integration."
   ```

5. **Cross-reference**:
   ```markdown
   ## Related Skills

   This skill has been split into:
   - **[`flutter-architecture-patterns`](../flutter-architecture-patterns/SKILL.md)** - App structure, routing, navigation
   - **[`flutter-riverpod-state`](../flutter-riverpod-state/SKILL.md)** - State management with Riverpod 3.x
   - **[`flutter-supabase-integration`](../flutter-supabase-integration/SKILL.md)** - Supabase API integration
   ```

---

## Quality Metrics

### Measuring Skill Health

**Key Metrics:**

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Discovery rate** | > 90% | Manual testing with trigger phrases |
| **Success rate** | > 95% | Test all examples, track user feedback |
| **Token efficiency** | < 5k tokens | `python scripts/token-counter.py SKILL.md` |
| **Line count** | < 500 lines | `wc -l SKILL.md` |
| **Staleness** | < 6 months | Check `last_updated` date |
| **Usage frequency** | Track informally | Search transcripts for invocations |

### Quarterly Skill Audit

Run every 3 months for all skills:

```bash
# Use the skill audit script
for skill in .claude/skills/*/; do
  python .claude/skills/ai-skill-manager/scripts/skill-audit.py "$skill"
done > skill-audit-report.txt
```

**Audit Checklist:**

- [ ] Line count < 500 (or uses progressive disclosure)
- [ ] Token count < 5k
- [ ] All examples execute successfully
- [ ] Framework versions current
- [ ] No deprecated APIs in examples
- [ ] Description includes 5+ trigger keywords
- [ ] CHANGELOG.md exists and is updated
- [ ] Version follows semantic versioning
- [ ] Last updated within 6 months
- [ ] Related skills links work
- [ ] Scripts have execute permissions

### Automated Quality Checks

**Pre-commit Hook** (.git/hooks/pre-commit):

```bash
#!/bin/bash
# Validate skill changes before commit

changed_skills=$(git diff --cached --name-only | grep "^.claude/skills/.*/SKILL.md$")

if [ -z "$changed_skills" ]; then
  exit 0
fi

echo "Validating changed skills..."

for skill_file in $changed_skills; do
  skill_dir=$(dirname "$skill_file")

  # Run audit
  python .claude/skills/ai-skill-manager/scripts/skill-audit.py "$skill_dir"

  if [ $? -ne 0 ]; then
    echo "❌ Skill audit failed for $skill_dir"
    echo "Fix issues before committing"
    exit 1
  fi
done

echo "✅ All skill validations passed"
exit 0
```

---

## Maintenance Workflows

### Workflow 1: Framework Version Update

**Trigger**: Next.js 15 → 16 released

**Steps:**

1. **Identify affected skills**:
   ```bash
   grep -r "Next.js 15" .claude/skills/
   ```

2. **For each affected skill**:
   - Update version references
   - Update code examples with new patterns
   - Add migration notes for breaking changes
   - Test all examples
   - Increment version (MINOR or MAJOR depending on changes)
   - Update `last_updated`
   - Update CHANGELOG.md

3. **Test discovery**:
   - Verify trigger phrases still work
   - Test with real user requests

4. **Commit**:
   ```bash
   git commit -m "feat(skill-name): update for Next.js 16"
   ```

### Workflow 2: API Deprecation

**Trigger**: Riverpod 3.0 deprecates `AsyncValue.valueOrNull`

**Steps:**

1. **Find all usages**:
   ```bash
   grep -r "valueOrNull" .claude/skills/flutter-*/
   ```

2. **For each occurrence**:
   - Add deprecation warning:
     ```markdown
     ## Migration Note

     Riverpod 3.0 deprecated `AsyncValue.valueOrNull`.

     **Before** (Riverpod 2.x):
     ```dart
     final value = state.valueOrNull;
     ```

     **After** (Riverpod 3.x):
     ```dart
     final value = state.value; // Throws if loading/error
     ```
     ```

   - Update all examples
   - Test with new API
   - Increment MINOR version
   - Update CHANGELOG.md

3. **Cross-reference**:
   - Update related skills
   - Ensure consistency across all Flutter skills

### Workflow 3: New Best Practice

**Trigger**: INP becomes Core Web Vital (replaces FID)

**Steps:**

1. **Research new practice**:
   - Read official documentation
   - Understand migration path
   - Identify impact on existing patterns

2. **Update affected skills**:
   - `web-performance-metrics` - Add INP optimization section
   - `seo-validation-testing` - Add INP testing patterns
   - `production-readiness` - Update performance budgets

3. **For each skill**:
   - Add new section for INP
   - Keep FID with deprecation note
   - Update quick reference
   - Add migration guide
   - Update metrics and targets
   - Increment MINOR version

4. **Deprecate old pattern** (after transition period):
   - Move FID to "Legacy Patterns" section
   - Keep for reference but mark as outdated

### Workflow 4: Token Optimization

**Trigger**: Skill exceeds 500 lines

**Steps:**

1. **Analyze structure**:
   ```bash
   wc -l .claude/skills/skill-name/SKILL.md
   # Output: 853 lines
   ```

2. **Identify split points**:
   - Core patterns (keep in SKILL.md)
   - Detailed API reference (move to REFERENCE.md)
   - Examples (move to EXAMPLES.md)
   - Troubleshooting (move to TROUBLESHOOTING.md)

3. **Create supporting files**:
   ```bash
   # Extract detailed content to separate files
   # Keep SKILL.md < 500 lines with references
   ```

4. **Update SKILL.md**:
   ```markdown
   ## Additional Resources

   For complete API reference, see [REFERENCE.md](REFERENCE.md)
   For detailed examples, see [EXAMPLES.md](EXAMPLES.md)
   For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
   ```

5. **Test**:
   - Verify core functionality still in quick reference
   - Test discovery unchanged
   - Measure token savings

6. **Version bump**:
   - MAJOR if file structure changed significantly
   - Document in CHANGELOG

### Workflow 5: User-Reported Issue

**Trigger**: User reports "skill example doesn't work"

**Steps:**

1. **Reproduce issue**:
   - Follow exact steps from report
   - Document environment (OS, versions, etc.)
   - Capture error messages

2. **Identify root cause**:
   - Code error in example
   - Missing prerequisite
   - Outdated dependency version
   - Unclear instructions

3. **Fix**:
   - Update code example
   - Add missing prerequisites section
   - Update dependency versions
   - Clarify instructions

4. **Test thoroughly**:
   - Test fixed example end-to-end
   - Test in clean environment
   - Verify prerequisites documented

5. **Update docs**:
   - Fix the example
   - Add to troubleshooting if common issue
   - Increment PATCH version
   - Update CHANGELOG

6. **Follow up**:
   - Notify user of fix
   - Confirm issue resolved

---

## Key Takeaways

1. **Update proactively** - Track framework releases, scan for deprecations quarterly
2. **Version semantically** - MAJOR.MINOR.PATCH tells users what changed
3. **Maintain CHANGELOG** - Track all changes for transparency
4. **Deprecate gracefully** - Give users time to migrate (1-2 sprints)
5. **Monitor metrics** - Line count, token usage, discovery rate, staleness
6. **Automate checks** - Pre-commit hooks catch issues early
7. **Document everything** - Migration guides, deprecation timelines, changelogs

---

**Next**: See [OPTIMIZATION_GUIDE.md](OPTIMIZATION_GUIDE.md) for token efficiency and performance tuning.

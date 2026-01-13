# Engineering Standards Usage Guide

Comprehensive guide for using the engineering-standards skill across all workflows.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Validation Workflows](#validation-workflows)
3. [Bootstrap Workflows](#bootstrap-workflows)
4. [Pattern Extraction Workflows](#pattern-extraction-workflows)
5. [Reporting Workflows](#reporting-workflows)
6. [CI/CD Integration](#cicd-integration)
7. [Advanced Usage](#advanced-usage)

## Quick Start

### Installation

The engineering-standards skill is template-based and doesn't require installation. Scripts are standalone Python and Bash.

**Prerequisites**:
- Python 3.8+
- Git
- Bash (for check-standards.sh)

### Basic Validation

```bash
# Quick check (< 2 seconds)
cd /path/to/your/project
/path/to/engineering-standards/scripts/check-standards.sh .

# Full validation (30+ checks)
python3 /path/to/engineering-standards/scripts/validate-compliance.py \
  --project-path .
```

## Validation Workflows

### Workflow 1: Quick Health Check

**Use case**: Rapid validation before committing code

```bash
# Navigate to your project
cd ~/projects/my-app

# Run quick validation
/path/to/engineering-standards/scripts/check-standards.sh .

# Output example:
# ✓ Passed: 15
# ✗ Failed: 2
# ⚠ Warnings: 3
# Overall: 75% (Grade: C)
```

**Exit codes**:
- `0` - All checks passed
- `1` - Some checks failed

### Workflow 2: Comprehensive Validation

**Use case**: Before creating PR, full compliance check

```bash
# Full validation with detailed output
python3 scripts/validate-compliance.py \
  --project-path ~/projects/my-app

# Output to JSON for automation
python3 scripts/validate-compliance.py \
  --project-path ~/projects/my-app \
  --report-format json \
  --output compliance.json
```

**Exit codes**:
- `0` - Full compliance (95%+)
- `1` - Warnings present (70-94%)
- `2` - Critical failures (<70%)

### Workflow 3: Continuous Monitoring

**Use case**: Track compliance over time

```bash
# Weekly compliance check
python3 scripts/validate-compliance.py \
  --project-path ~/projects/my-app \
  --report-format json \
  --output "compliance-$(date +%Y-%m-%d).json"

# Compare with previous week
diff compliance-2026-01-06.json compliance-2026-01-13.json
```

### Workflow 4: Category-Specific Validation

The validation automatically runs all categories, but you can focus on results:

```bash
# Run validation and filter output
python3 scripts/validate-compliance.py \
  --project-path . | grep "HOOKS:"

# Or use jq with JSON output
python3 scripts/validate-compliance.py \
  --project-path . \
  --report-format json | jq '.categories.hooks'
```

## Bootstrap Workflows

### Workflow 5: Bootstrap Next.js Project

**Use case**: Start new Next.js project with all standards

```bash
# Basic Next.js project
python3 scripts/bootstrap-project.py \
  --project-name "My SaaS App" \
  --project-type nextjs \
  --output-path ~/projects/my-saas

# Navigate and install
cd ~/projects/my-saas
pnpm install
pnpm lefthook install

# Start development
pnpm dev
```

**What's created**:
- Complete directory structure (app/, lib/, components/, docs/)
- All template files (lefthook.yml, CLAUDE.md, etc.)
- Configured package.json with quality scripts
- TypeScript strict mode configuration
- Git repository with initial commit

### Workflow 6: Bootstrap with Framework

**Use case**: Start project with MakerKit or other framework

```bash
# MakerKit-based project
python3 scripts/bootstrap-project.py \
  --project-name "SaaS Starter" \
  --project-type nextjs \
  --framework makerkit \
  --output-path ~/projects/saas-starter

# ApparenceKit Flutter project
python3 scripts/bootstrap-project.py \
  --project-name "Mobile App" \
  --project-type flutter \
  --framework apparencekit \
  --output-path ~/projects/mobile-app
```

**Framework differences**:
- `makerkit`: Supabase migrations, RLS patterns, @kit/ui references
- `apparencekit`: Flutter 3-layer architecture, Riverpod patterns
- `supabase`: Enhanced Supabase integration, migration idempotency

### Workflow 7: Bootstrap Monorepo

**Use case**: Start new monorepo with Turborepo

```bash
# Create monorepo structure
python3 scripts/bootstrap-project.py \
  --project-name "My Monorepo" \
  --project-type monorepo \
  --output-path ~/projects/my-monorepo \
  --package-manager pnpm

cd ~/projects/my-monorepo

# Validate structure
python3 /path/to/scripts/validate-compliance.py --project-path .
# Expected: 95%+ compliance

# Add first app
mkdir -p apps/web
# ... add Next.js app

# Add first package
mkdir -p packages/ui
# ... add UI package
```

**Monorepo specifics**:
- apps/ and packages/ directories
- Turborepo configuration
- pnpm workspaces setup
- Shared configurations

### Workflow 8: Bootstrap with Auto-Install

**Use case**: Fully automated setup

```bash
# Bootstrap and install dependencies automatically
python3 scripts/bootstrap-project.py \
  --project-name "Quick Start" \
  --project-type nextjs \
  --output-path ~/projects/quick-start \
  --install

# Project is ready to use immediately
cd ~/projects/quick-start
pnpm dev
```

**With --install flag**:
- Runs `pnpm install`
- Installs lefthook hooks
- Validates installation
- Reports any errors

## Pattern Extraction Workflows

### Workflow 9: Extract All Patterns

**Use case**: Learn from existing project

```bash
# Extract all patterns from mature project
python3 scripts/sync-from-project.py \
  --source-project ~/projects/ballee \
  --extract all \
  --dry-run

# Output shows:
# - Hooks: 22 patterns
# - Testing: 2 patterns
# - Quality Gates: 5 patterns
# - Documentation: 22 patterns
# - 51 new patterns not in standards
```

**Pattern categories**:
- `hooks` - Git hooks (lefthook) and Claude hooks
- `testing` - Vitest, Playwright configurations
- `quality` - ESLint, TypeScript, Prettier settings
- `patterns` - Architectural patterns in code
- `docs` - Documentation structure and naming
- `migrations` - Database migration patterns

### Workflow 10: Extract Specific Categories

**Use case**: Focus on particular aspects

```bash
# Only extract hook patterns
python3 scripts/sync-from-project.py \
  --source-project ~/projects/ballee \
  --extract hooks

# Extract hooks and testing
python3 scripts/sync-from-project.py \
  --source-project ~/projects/ballee \
  --extract hooks,testing

# Extract with comparison
python3 scripts/sync-from-project.py \
  --source-project ~/projects/ballee \
  --extract all
# Automatically compares with current standards
# Shows new patterns not yet documented
```

### Workflow 11: Compare Projects

**Use case**: See how two projects differ

```bash
# Extract from project A
python3 scripts/sync-from-project.py \
  --source-project ~/projects/project-a \
  --extract all \
  > project-a-patterns.txt

# Extract from project B
python3 scripts/sync-from-project.py \
  --source-project ~/projects/project-b \
  --extract all \
  > project-b-patterns.txt

# Compare
diff project-a-patterns.txt project-b-patterns.txt
```

## Reporting Workflows

### Workflow 12: Generate Markdown Report

**Use case**: Share compliance status with team

```bash
# Generate detailed markdown report
python3 scripts/generate-report.py \
  --project-path ~/projects/my-app \
  --format markdown \
  --output compliance-report.md

# Share report
cat compliance-report.md
# Or commit to repository for tracking
git add compliance-report.md
git commit -m "docs: add compliance report"
```

**Report sections**:
- Executive Summary
- Standards Compliance Matrix
- Detailed Findings (by category)
- Recommendations (prioritized)
- Quality Metrics
- Next Steps

### Workflow 13: Generate HTML Dashboard

**Use case**: Visual compliance dashboard

```bash
# Generate HTML report
python3 scripts/generate-report.py \
  --project-path ~/projects/my-app \
  --format html \
  --output compliance-dashboard.html

# Open in browser
open compliance-dashboard.html

# Or serve via HTTP for team access
python3 -m http.server 8000 &
open http://localhost:8000/compliance-dashboard.html
```

**HTML features**:
- Color-coded compliance scores
- Interactive tables
- Critical issues highlighted
- Responsive design

### Workflow 14: JSON for Automation

**Use case**: Integrate with CI/CD or monitoring

```bash
# Generate JSON for automation
python3 scripts/generate-report.py \
  --project-path ~/projects/my-app \
  --format json \
  --output compliance.json

# Parse with jq
cat compliance.json | jq '.overall_score'
# Output: 85.5

# Check if passing
SCORE=$(cat compliance.json | jq -r '.overall_score')
if (( $(echo "$SCORE >= 90" | bc -l) )); then
  echo "✓ Compliance passing"
else
  echo "✗ Compliance failing: $SCORE%"
  exit 1
fi
```

## CI/CD Integration

### Workflow 15: GitHub Actions Integration

**Use case**: Automated compliance checks on every PR

```yaml
# .github/workflows/compliance.yml
name: Engineering Standards Compliance

on:
  pull_request:
    branches: [main, dev]

jobs:
  compliance-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Clone engineering-standards
        run: |
          git clone https://github.com/your-org/cortex-skills.git /tmp/cortex-skills

      - name: Run compliance validation
        run: |
          python3 /tmp/cortex-skills/templates/skills/engineering-standards/scripts/validate-compliance.py \
            --project-path . \
            --report-format json \
            --output compliance.json

      - name: Check compliance threshold
        run: |
          SCORE=$(cat compliance.json | jq -r '.overall_score')
          echo "Compliance Score: $SCORE%"

          if (( $(echo "$SCORE < 80" | bc -l) )); then
            echo "❌ Compliance below 80% threshold"
            exit 1
          fi

      - name: Upload compliance report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: compliance-report
          path: compliance.json
```

### Workflow 16: Pre-Commit Hook

**Use case**: Local validation before every commit

```bash
# Add to .git/hooks/pre-commit
#!/bin/bash

echo "Running quick standards check..."

/path/to/engineering-standards/scripts/check-standards.sh .

if [ $? -ne 0 ]; then
  echo "❌ Standards check failed"
  echo "Run: python3 /path/to/scripts/validate-compliance.py --project-path ."
  echo "Or skip with: git commit --no-verify"
  exit 1
fi
```

### Workflow 17: Weekly Compliance Report

**Use case**: Automated weekly compliance tracking

```yaml
# .github/workflows/weekly-compliance.yml
name: Weekly Compliance Report

on:
  schedule:
    - cron: '0 9 * * 1'  # Every Monday at 9am

jobs:
  weekly-report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate compliance report
        run: |
          python3 scripts/generate-report.py \
            --project-path . \
            --format markdown \
            --output weekly-compliance-$(date +%Y-%m-%d).md

      - name: Create issue with report
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = fs.readFileSync('weekly-compliance-*.md', 'utf8');

            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Weekly Compliance Report - ${new Date().toISOString().split('T')[0]}`,
              body: report,
              labels: ['compliance', 'automated']
            });
```

## Advanced Usage

### Workflow 18: Multi-Project Validation

**Use case**: Validate multiple projects at once

```bash
#!/bin/bash
# validate-all-projects.sh

PROJECTS=(
  "~/projects/app-a"
  "~/projects/app-b"
  "~/projects/service-c"
)

for project in "${PROJECTS[@]}"; do
  echo "Validating $project..."

  python3 scripts/validate-compliance.py \
    --project-path "$project" \
    --report-format json \
    --output "$(basename $project)-compliance.json"

  SCORE=$(cat "$(basename $project)-compliance.json" | jq -r '.overall_score')
  echo "$project: $SCORE%"
done

# Generate summary
echo "Summary:"
for json in *-compliance.json; do
  PROJECT=$(echo $json | sed 's/-compliance.json//')
  SCORE=$(cat $json | jq -r '.overall_score')
  GRADE=$(cat $json | jq -r '.grade')
  echo "  $PROJECT: $SCORE% (Grade: $GRADE)"
done
```

### Workflow 19: Custom Rules Configuration

**Use case**: Override rules for specific project needs

```bash
# Create .engineering-standards.json in project root
cat > .engineering-standards.json <<EOF
{
  "testing": {
    "vitest": {
      "min_coverage_percent": 90
    }
  },
  "migrations": {
    "enabled": false
  }
}
EOF

# Run validation with custom rules
python3 scripts/validate-compliance.py --project-path .
```

### Workflow 20: Pattern Update Workflow

**Use case**: Update standards based on new patterns discovered

```bash
# 1. Extract patterns from production project
python3 scripts/sync-from-project.py \
  --source-project ~/projects/ballee \
  --extract all \
  --dry-run \
  > discovered-patterns.txt

# 2. Review new patterns
grep "NEW PATTERNS FOUND" discovered-patterns.txt -A 50

# 3. Manually update guides with valuable patterns
# Edit HOOKS_GUIDE.md, TESTING_GUIDE.md, etc.

# 4. Validate updated guides
python3 scripts/validate-compliance.py \
  --project-path /path/to/engineering-standards

# 5. Test with bootstrap
python3 scripts/bootstrap-project.py \
  --project-name "Test Updated Standards" \
  --project-type nextjs \
  --output-path /tmp/test-updated

# 6. Validate bootstrapped project
python3 scripts/validate-compliance.py \
  --project-path /tmp/test-updated
# Should get 95%+ compliance
```

## Common Command Reference

### Quick Reference Table

| Task | Command |
|------|---------|
| Quick check | `./scripts/check-standards.sh .` |
| Full validation | `python3 scripts/validate-compliance.py --project-path .` |
| JSON output | `python3 scripts/validate-compliance.py --project-path . --report-format json` |
| Bootstrap Next.js | `python3 scripts/bootstrap-project.py --project-name "App" --project-type nextjs --output-path ./app` |
| Bootstrap monorepo | `python3 scripts/bootstrap-project.py --project-name "Mono" --project-type monorepo --output-path ./mono` |
| Extract patterns | `python3 scripts/sync-from-project.py --source-project /path --extract all` |
| Markdown report | `python3 scripts/generate-report.py --project-path . --format markdown --output report.md` |
| HTML report | `python3 scripts/generate-report.py --project-path . --format html` |

### Environment Variables

```bash
# Optional: Set standards path for easier access
export ENGINEERING_STANDARDS_PATH="/path/to/cortex-skills/templates/skills/engineering-standards"

# Use in scripts
python3 $ENGINEERING_STANDARDS_PATH/scripts/validate-compliance.py --project-path .
```

### Aliases for Convenience

```bash
# Add to ~/.bashrc or ~/.zshrc
alias standards-check='python3 $ENGINEERING_STANDARDS_PATH/scripts/validate-compliance.py --project-path .'
alias standards-quick='$ENGINEERING_STANDARDS_PATH/scripts/check-standards.sh .'
alias standards-report='python3 $ENGINEERING_STANDARDS_PATH/scripts/generate-report.py --project-path . --format markdown'
alias standards-bootstrap='python3 $ENGINEERING_STANDARDS_PATH/scripts/bootstrap-project.py'

# Usage
cd ~/projects/my-app
standards-check
standards-report --output compliance.md
```

## Best Practices

1. **Run validation before every PR** - Catch issues early
2. **Track compliance over time** - Weekly JSON reports
3. **Use bootstrap for new projects** - Start with 95%+ compliance
4. **Extract patterns from mature projects** - Learn from production code
5. **Generate reports for stakeholders** - Share progress visually
6. **Integrate into CI/CD** - Automated enforcement
7. **Customize rules when needed** - Project-specific overrides
8. **Update standards regularly** - Incorporate new patterns

## Next Steps

- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- See [README.md](README.md) for architecture details
- See individual guides for detailed standards
- See [CHANGELOG.md](CHANGELOG.md) for version history

---

**Last Updated**: 2026-01-13

# Cortex Skills - Reusable Scripts

Generic, project-agnostic scripts for validation, quality checks, and automation.
All scripts can be used in any project with minimal configuration.

## 📁 Directory Structure

```
scripts/
├── validation/          # Validation scripts
│   ├── validate-wip.sh           # WIP document lifecycle validation
│   ├── validate-json-keys.sh     # JSON duplicate key detector
│   └── validate-dependencies.sh  # Environment variable validator
├── database/            # Database scripts (Supabase-focused)
│   ├── lint-migrations.ts        # Migration linter
│   ├── analyze-rls-policies.sh   # RLS policy security analyzer
│   └── validate-db-types.ts      # Database type-safety checker
├── mobile/              # Mobile development scripts
│   ├── test_queries_local.dart   # Flutter query tester
│   └── validate_queries.dart     # Flutter query validator
├── quality/             # Code quality gates
│   ├── code-quality-check.sh     # Universal quality gate
│   ├── typecheck-all.sh          # TypeScript type checking
│   └── test-coverage.sh          # Test coverage checker
├── aggregation/         # Data aggregation scripts
│   └── aggregate-dependencies.sh # Aggregate skill dependencies
├── assessment/          # Assessment and scoring
│   └── assess-reusability.sh     # Skill reusability scorer
└── README.md            # This file
```

---

## 🔍 Validation Scripts

### validate-wip.sh

Validates Work In Progress (WIP) documents for proper structure and lifecycle management.

**Usage:**
```bash
# Validate all WIP files in docs/wip/active/
./scripts/validation/validate-wip.sh

# Validate specific files
./scripts/validation/validate-wip.sh docs/wip/active/WIP_feature-x.md

# Configure via environment variables
PROJECT_ROOT=. WIP_ACTIVE_DIR=docs/wip STALENESS_DAYS=14 ./scripts/validation/validate-wip.sh
```

**Environment Variables:**
- `PROJECT_ROOT` - Project root directory (default: `.`)
- `WIP_ACTIVE_DIR` - Active WIP directory (default: `docs/wip/active`)
- `WIP_COMPLETED_DIR` - Completed WIP directory (default: `docs/wip/completed`)
- `STALENESS_DAYS` - Days before WIP is considered stale (default: `7`)

**Checks:**
- ✅ Required sections: Last Updated, Target Completion, Objective, Progress Tracker
- ✅ Completion status (completed WIPs should be in completed/ folder)
- ✅ Staleness warnings (>7 days since last update)

---

### validate-json-keys.sh

Detects duplicate keys in JSON files which can cause silent data loss.

**Usage:**
```bash
# Validate all JSON files in current directory
./scripts/validation/validate-json-keys.sh

# Validate specific files
./scripts/validation/validate-json-keys.sh locales/en.json locales/fr.json

# Configure via environment variables
JSON_DIR=./config JSON_PATTERN="*.json" ./scripts/validation/validate-json-keys.sh
```

**Environment Variables:**
- `JSON_DIR` - Directory to search for JSON files (default: `.`)
- `JSON_PATTERN` - File pattern to match (default: `*.json`)

**Use Cases:**
- i18n locale files validation
- Configuration file validation
- API response validation
- Data file integrity checks

---

### validate-dependencies.sh

Validates that required environment variables are set before running applications.

**Usage:**
```bash
# Check single variable
./scripts/validation/validate-dependencies.sh DATABASE_URL

# Check multiple variables
./scripts/validation/validate-dependencies.sh DATABASE_URL API_KEY SECRET_KEY

# Use in scripts
if ./scripts/validation/validate-dependencies.sh DATABASE_URL API_KEY; then
  echo "Ready to start!"
  npm start
fi
```

**Exit Codes:**
- `0` - All required variables are set
- `1` - One or more variables are missing

**Security:**
- Only shows first 20 characters of each variable value
- Provides guidance on how to set missing variables

---

## ⚡ Quality Scripts

### code-quality-check.sh

Universal quality gate that runs all checks in sequence.

**Usage:**
```bash
# Run all quality checks
./scripts/quality/code-quality-check.sh

# Run in specific project directory
./scripts/quality/code-quality-check.sh /path/to/project

# Skip specific checks
SKIP_TESTS=1 ./scripts/quality/code-quality-check.sh
```

**Environment Variables:**
- `SKIP_TYPECHECK` - Set to `1` to skip TypeScript checking
- `SKIP_LINT` - Set to `1` to skip linting
- `SKIP_FORMAT` - Set to `1` to skip format checking
- `SKIP_TESTS` - Set to `1` to skip tests

**Runs:**
1. TypeScript type checking (`npm run typecheck`)
2. Linting (`npm run lint`)
3. Format checking (`npm run format:check`)
4. Tests (`npm test`)

**Use Cases:**
- Pre-commit hooks
- CI/CD pipelines
- Manual quality checks before deployment
- Git hooks (lefthook, husky)

---

## 🗄️ Database Scripts

### lint-migrations.ts *(Coming Soon)*

Lints Supabase migration files for best practices and common issues.

### analyze-rls-policies.sh *(Coming Soon)*

Analyzes Row Level Security (RLS) policies for security issues and performance problems.

### validate-db-types.ts *(Coming Soon)*

Validates database query types match TypeScript definitions.

---

## 📱 Mobile Scripts

### test_queries_local.dart *(Coming Soon)*

Tests Flutter Supabase queries locally before deployment.

### validate_queries.dart *(Coming Soon)*

Validates Flutter queries for security and performance issues.

---

## 📊 Aggregation Scripts

### aggregate-dependencies.sh *(Coming Soon)*

Aggregates dependencies from all skill.config.json files into centralized documentation.

---

## 🎯 Assessment Scripts

### assess-reusability.sh *(Coming Soon)*

Scores skills on reusability (0-100) based on:
- Hardcoded values (-10 each)
- Configuration abstraction (+20)
- Clear dependencies (+10)
- Good documentation (+15)
- Uses reusable scripts (+10)

---

## 🔧 Integration with Skills

### Using Scripts in Skills

Reference scripts in your skill.md files:

```markdown
## Scripts

This skill uses the following reusable scripts:
- `scripts/validation/validate-dependencies.sh`: Check env vars
- `scripts/quality/code-quality-check.sh`: Run quality checks
```

### Using Scripts in Pre-commit Hooks

**Lefthook example:**
```yaml
# .lefthook.yml
pre-commit:
  commands:
    quality:
      run: bash cortex-skills/scripts/quality/code-quality-check.sh
    wip-validation:
      glob: "docs/wip/active/*.md"
      run: bash cortex-skills/scripts/validation/validate-wip.sh {staged_files}
```

**Husky example:**
```json
{
  "husky": {
    "hooks": {
      "pre-commit": "bash cortex-skills/scripts/quality/code-quality-check.sh"
    }
  }
}
```

---

## 🚀 Best Practices

### 1. Make Scripts Configurable

Always use environment variables for configuration:
```bash
PROJECT_ROOT="${PROJECT_ROOT:-.}"
```

### 2. Use Exit Codes Properly

- `0` - Success
- `1` - Failure/Error
- `2` - Warning (optional)

### 3. Provide Helpful Error Messages

Show exactly what's wrong and how to fix it:
```bash
echo "❌ Missing DATABASE_URL"
echo "Set with: export DATABASE_URL='your_value'"
```

### 4. Support Both macOS and Linux

Use BSD-compatible commands:
```bash
# Good (works on both)
date "+%s"

# Bad (Linux only)
date --iso-8601
```

### 5. Color Output

Use colors for better readability:
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}✅ Success${NC}"
echo -e "${RED}❌ Error${NC}"
```

---

## 📚 Contributing

### Adding New Scripts

1. Choose appropriate directory (validation, quality, database, etc.)
2. Make script executable: `chmod +x script.sh`
3. Add environment variable configuration
4. Include usage documentation in script header
5. Update this README
6. Test on both macOS and Linux

### Script Template

```bash
#!/usr/bin/env bash
# Brief description
#
# Longer description of what the script does.
# Can be multiple lines.
#
# Usage:
#   ./script.sh [options]
#   ./script.sh --help
#
# Environment Variables:
#   VAR_NAME - Description (default: value)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Configuration
CONFIG_VAR="${CONFIG_VAR:-default}"

# Main logic here
echo -e "${GREEN}✅ Done${NC}"
```

---

## 🔗 Related Documentation

- **skill-manager**: Create and manage skills
- **Skill Configuration**: skill.config.json format
- **Dependencies**: All required packages and APIs
- **Templates**: Generic skill templates

---

## 📝 License

MIT - Same as cortex-skills repository

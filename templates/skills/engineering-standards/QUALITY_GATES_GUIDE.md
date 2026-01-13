# Quality Gates Guide

Standards for lint, typecheck, format, and build validation ensuring code quality before merge.

## Overview

### Quality Command

Sequential execution of all quality gates:

```bash
# Full quality check (runs in order, stops on first failure)
pnpm quality

# Equivalent to:
pnpm format    # Format check (or auto-fix)
pnpm lint      # ESLint full check
pnpm typecheck # TypeScript validation
pnpm test      # Unit + integration tests
pnpm build     # Production build
```

**Use Cases**:
- Before creating PR
- In CI/CD pipeline
- Pre-push hook (with THOROUGH=1)

## Formatting (Prettier)

### Configuration

```json
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2
}
```

### Commands

```bash
# Check formatting
pnpm prettier --check "**/*.{js,jsx,ts,tsx,json,md}"

# Auto-fix formatting
pnpm prettier --write "**/*.{js,jsx,ts,tsx,json,md}"
```

### Pre-Commit Integration

```yaml
# lefthook.yml
pre-commit:
  commands:
    format:
      glob: '*.{js,jsx,ts,tsx,json,md}'
      run: pnpm prettier --write {staged_files}
      stage_fixed: true  # Re-stage auto-fixed files
```

## Linting (ESLint + Oxlint)

### Oxlint (Fast Sanity Check)

**Purpose**: Catch critical issues quickly (10-100x faster than ESLint).

```bash
# Pre-push hook (always runs)
pnpm oxlint \
  --deny=no-debugger \
  --deny=no-const-assign \
  --deny=no-dupe-keys \
  --deny=no-self-assign \
  --ignore-path=.gitignore \
  apps/web packages
```

**Critical Rules**:
- `no-debugger` - No debugger statements
- `no-const-assign` - No reassigning const
- `no-dupe-keys` - No duplicate object keys
- `no-self-assign` - No self-assignment

### ESLint (Comprehensive)

**Configuration** (`eslint.config.mjs`):
```javascript
import js from '@eslint/js';
import typescript from '@typescript-eslint/eslint-plugin';
import reactHooks from 'eslint-plugin-react-hooks';
import reactProviders from './tools/eslint-plugin-react-providers/index.mjs';
import i18n from './tools/eslint-plugin-i18n/index.mjs';

export default [
  js.configs.recommended,
  {
    plugins: {
      '@typescript-eslint': typescript,
      'react-hooks': reactHooks,
      'react-providers': reactProviders,
      'i18n': i18n,
    },
    rules: {
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',
      'react-providers/require-provider': 'error',
      'i18n/no-literal-string': 'warn',
    },
  },
];
```

**Commands**:
```bash
# Lint all
pnpm eslint .

# Lint with auto-fix
pnpm eslint --fix .

# Lint affected (Turborepo)
pnpm turbo lint --affected
```

### Custom ESLint Plugins

**1. react-providers** - Enforce required context providers:
```typescript
// ❌ Error: Tooltip requires TooltipProvider
<Tooltip>...</Tooltip>

// ✅ Correct
<TooltipProvider>
  <Tooltip>...</Tooltip>
</TooltipProvider>
```

**2. i18n** - Validate translation keys:
```typescript
// ❌ Warning: Use Trans component
<p>Welcome, {user.name}</p>

// ✅ Correct
<Trans i18nKey="user:welcome" values={{ name: user.name }} />
```

**3. react-form-fields** - Validate form field naming:
```typescript
// ❌ Error: Form fields must match schema keys
<input name="userName" />  // Schema has "user_name"

// ✅ Correct
<input name="user_name" />
```

## Type Checking (TypeScript)

### Configuration

```json
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,              // Enable all strict checks
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true
  }
}
```

### Commands

```bash
# Typecheck all
pnpm tsc --noEmit

# Typecheck affected (Turborepo)
pnpm turbo typecheck --affected

# Typecheck with cache
pnpm turbo typecheck --cache-dir=.turbo
```

### Common Patterns

**Avoid `any`**:
```typescript
// ❌ Bad
function process(data: any) {
  return data.value;
}

// ✅ Good
function process<T extends { value: string }>(data: T) {
  return data.value;
}
```

**Proper null checks**:
```typescript
// ❌ Bad (can crash if user is null)
const name = user.name;

// ✅ Good (safe access)
const name = user?.name ?? 'Anonymous';
```

## Build Validation

### Production Build

```bash
# Build all packages
pnpm build

# Build affected (Turborepo)
pnpm turbo build --affected

# Build with output
pnpm turbo build --affected --output-logs=new-only
```

### Build Configuration (Next.js)

```javascript
// next.config.js
module.exports = {
  typescript: {
    // Fail build on type errors
    ignoreBuildErrors: false,
  },
  eslint: {
    // Fail build on ESLint errors
    ignoreDuringBuilds: false,
  },
};
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/quality.yml
name: Quality Gate

on:
  pull_request:
    branches: [main, dev]

jobs:
  quality:
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

      - name: Format check
        run: pnpm prettier --check "**/*.{js,jsx,ts,tsx,json,md}"

      - name: Lint
        run: pnpm turbo lint --affected

      - name: Typecheck
        run: pnpm turbo typecheck --affected

      - name: Test
        run: pnpm turbo test --affected

      - name: Build
        run: pnpm turbo build --affected
```

## Performance Optimization

### Caching

**Turborepo**:
```json
// turbo.json
{
  "pipeline": {
    "lint": {
      "outputs": []
    },
    "typecheck": {
      "outputs": []
    },
    "build": {
      "outputs": [".next/**", "dist/**"],
      "dependsOn": ["^build"]
    }
  }
}
```

**GitHub Actions**:
```yaml
- name: Turbo cache
  uses: actions/cache@v4
  with:
    path: .turbo
    key: turbo-${{ runner.os }}-${{ github.sha }}
    restore-keys: turbo-${{ runner.os }}-
```

### Parallel Execution

```yaml
# lefthook.yml
pre-push:
  parallel: true  # Run all commands simultaneously
  commands:
    oxlint:
      run: pnpm oxlint
    typecheck:
      run: pnpm turbo typecheck --affected
```

## Troubleshooting

### Slow Typecheck

**Solution**: Use project references and affected checks:
```bash
# Only check affected packages
pnpm turbo typecheck --affected --cache-dir=.turbo
```

### ESLint Memory Issues

**Solution**: Increase Node memory:
```json
// package.json
{
  "scripts": {
    "lint": "NODE_OPTIONS='--max-old-space-size=4096' eslint ."
  }
}
```

### Build Failures in CI

**Solution**: Match local Node version to CI:
```yaml
# .github/workflows/quality.yml
- uses: actions/setup-node@v4
  with:
    node-version-file: '.nvmrc'  # Read from .nvmrc
```

---

**Last Updated**: 2026-01-13
**Related**: [HOOKS_GUIDE.md](HOOKS_GUIDE.md), [TESTING_GUIDE.md](TESTING_GUIDE.md)

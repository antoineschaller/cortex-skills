# Monorepo Guide

Turborepo, pnpm workspaces, shared packages, and dependency management for monorepo projects.

## Overview

Monorepo architecture enables code sharing, consistent tooling, and coordinated releases across multiple applications and packages.

### Core Technologies

- **pnpm workspaces** - Package management and linking
- **Turborepo** - Build caching and task orchestration
- **TypeScript project references** - Cross-package type checking
- **Syncpack** - Dependency version synchronization

### Benefits

✅ **Code Sharing** - Share utilities, components, types across apps
✅ **Consistent Tooling** - Single ESLint, TypeScript, Prettier config
✅ **Atomic Changes** - Update multiple packages in one PR
✅ **Build Caching** - Turborepo caches unchanged packages
✅ **Type Safety** - TypeScript references ensure cross-package types

## Project Structure

### Directory Layout

```
monorepo/
├── apps/                        # Applications (deployable)
│   ├── web/                     # Next.js web app
│   ├── mobile/                  # Flutter mobile app
│   ├── admin/                   # Admin dashboard
│   └── docs/                    # Documentation site
├── packages/                    # Shared packages (libraries)
│   ├── ui/                      # UI components
│   ├── database/                # Database client
│   ├── shared/                  # Shared utilities
│   ├── supabase/                # Supabase SDK wrapper
│   └── eslint-config/           # Shared ESLint config
├── tools/                       # Build tools, scripts
│   ├── eslint-plugins/          # Custom ESLint plugins
│   └── scripts/                 # Utility scripts
├── docs/                        # Documentation
├── pnpm-workspace.yaml          # Workspace configuration
├── turbo.json                   # Turborepo configuration
├── package.json                 # Root package.json
└── tsconfig.json                # Root TypeScript config
```

### Apps vs Packages

**apps/** - Deployable applications:
- Have their own build output
- Can be deployed independently
- Consume packages
- Examples: Next.js app, Flutter app, API server

**packages/** - Shared libraries:
- Reusable across apps
- Not deployed independently
- Provide utilities, components, types
- Examples: UI library, database client, utilities

**tools/** - Development utilities:
- Build tools, scripts, custom plugins
- Not consumed by apps at runtime
- Examples: ESLint plugins, code generators

## pnpm Workspaces

### Configuration

**pnpm-workspace.yaml**:
```yaml
packages:
  - 'apps/*'
  - 'packages/*'
  - 'tools/*'
```

**Root package.json**:
```json
{
  "name": "monorepo",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "turbo dev",
    "build": "turbo build",
    "test": "turbo test",
    "lint": "turbo lint",
    "format": "prettier --write \"**/*.{js,jsx,ts,tsx,json,md}\""
  },
  "devDependencies": {
    "turbo": "^2.3.0",
    "prettier": "^3.4.2",
    "typescript": "^5.7.2"
  },
  "engines": {
    "node": ">=20.0.0",
    "pnpm": ">=9.0.0"
  },
  "packageManager": "pnpm@9.15.1"
}
```

### Package Naming

**Convention**: `@scope/package-name`

**Examples**:
```json
// packages/ui/package.json
{
  "name": "@kit/ui",
  "version": "1.0.0"
}

// packages/database/package.json
{
  "name": "@kit/database",
  "version": "1.0.0"
}

// apps/web/package.json
{
  "name": "@apps/web",
  "version": "1.0.0",
  "dependencies": {
    "@kit/ui": "workspace:*",
    "@kit/database": "workspace:*"
  }
}
```

**workspace:*** protocol:
- Links to local workspace version
- Replaced with actual version on publish
- Ensures latest local code is used

### Installation Commands

```bash
# Install all dependencies (from root)
pnpm install

# Add dependency to specific package
pnpm add react --filter web

# Add workspace dependency
pnpm add @kit/ui --filter web --workspace

# Add dev dependency to root
pnpm add -D eslint -w

# Remove dependency
pnpm remove react --filter web

# Update all dependencies
pnpm update -r

# Install in specific package
cd apps/web
pnpm install
```

### Filtering

**Run commands in specific packages**:
```bash
# Single package
pnpm --filter web dev
pnpm --filter @kit/ui build

# Multiple packages
pnpm --filter web --filter admin dev

# All apps
pnpm --filter "./apps/*" dev

# All packages
pnpm --filter "./packages/*" build

# Package and its dependencies
pnpm --filter web... build

# Package's dependents
pnpm --filter ...web test
```

## Turborepo

### Configuration

**turbo.json**:
```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": [".env", ".env.local"],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "dist/**", "build/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^build"],
      "outputs": []
    },
    "typecheck": {
      "dependsOn": ["^build"],
      "outputs": []
    },
    "test": {
      "dependsOn": ["^build"],
      "outputs": ["coverage/**"]
    },
    "deploy": {
      "dependsOn": ["build", "test", "lint"],
      "outputs": []
    }
  }
}
```

**Pipeline Explanation**:
- `"dependsOn": ["^build"]` - Run dependencies' build tasks first
- `"outputs": [".next/**"]` - Cache these directories
- `"cache": false` - Don't cache dev server
- `"persistent": true` - Long-running task (dev server)

### Task Execution

**Run tasks**:
```bash
# Run task in all packages
turbo build
turbo test
turbo lint

# Run task in specific package
turbo build --filter web

# Run multiple tasks
turbo build test lint

# Force without cache
turbo build --force

# Show what would run (dry run)
turbo build --dry-run

# Verbose output
turbo build --verbose

# Parallel execution
turbo build --parallel

# Continue on error
turbo build --continue
```

### Caching

**How it works**:
1. Turborepo hashes inputs (files, dependencies, env vars)
2. Checks cache for matching hash
3. If hit: Restores outputs, skips execution
4. If miss: Runs task, stores outputs in cache

**Cache locations**:
- Local: `.turbo/cache/`
- Remote: Vercel (if configured)

**Benefits**:
- Skip rebuilding unchanged packages
- Fast CI/CD (restore from cache)
- Local development speed

**Cache miss reasons**:
- Source files changed
- Dependencies updated
- Environment variables changed
- Task configuration changed

**Cache configuration**:
```json
// turbo.json
{
  "pipeline": {
    "build": {
      "outputs": [".next/**", "dist/**"],
      "inputs": ["src/**", "package.json", "tsconfig.json"]
    }
  }
}
```

### Affected Packages

**Only run tasks on changed packages**:
```bash
# Build only packages with changes since main
turbo build --affected

# Test affected packages
turbo test --filter=[origin/main]

# Lint affected packages
turbo lint --filter=[HEAD^1]
```

**CI/CD optimization**:
```yaml
# .github/workflows/ci.yml
- name: Build affected packages
  run: turbo build --filter=[origin/main]

- name: Test affected packages
  run: turbo test --filter=[origin/main]
```

**Benefits**:
- Faster CI/CD (only test changed code)
- Reduced build times
- Efficient resource usage

### Remote Caching

**Vercel Remote Cache**:
```bash
# Link to Vercel
pnpm dlx turbo login

# Link repository
pnpm dlx turbo link
```

**turbo.json**:
```json
{
  "remoteCache": {
    "signature": true
  }
}
```

**Benefits**:
- Share cache across team
- Faster CI/CD with cache hits
- Consistent builds

## Dependency Management

### Syncpack

**Purpose**: Ensure consistent dependency versions across packages.

**Installation**:
```bash
pnpm add -D syncpack -w
```

**Configuration** (.syncpackrc.json):
```json
{
  "versionGroups": [
    {
      "label": "Use workspace protocol for local packages",
      "dependencies": ["@kit/**", "@apps/**"],
      "dependencyTypes": ["prod", "dev"],
      "pinVersion": "workspace:*"
    },
    {
      "label": "Ensure same version of React",
      "dependencies": ["react", "react-dom"],
      "packages": ["**"],
      "pinVersion": "^19.0.0"
    }
  ],
  "semverGroups": [
    {
      "range": "^",
      "dependencies": ["**"],
      "packages": ["**"]
    }
  ]
}
```

**Commands**:
```bash
# Check for mismatched versions
pnpm syncpack list-mismatches

# Fix mismatched versions
pnpm syncpack fix-mismatches

# Format package.json files
pnpm syncpack format

# List versions
pnpm syncpack list
```

**package.json scripts**:
```json
{
  "scripts": {
    "check-deps": "syncpack list-mismatches",
    "fix-deps": "syncpack fix-mismatches"
  }
}
```

### Version Pinning

**Strategies**:

1. **Exact versions** (1.2.3):
   - Use for critical dependencies
   - Prevents unexpected updates
   - Example: Database drivers

2. **Caret ranges** (^1.2.3):
   - Allow minor/patch updates
   - Default for most dependencies
   - Example: UI libraries

3. **Workspace protocol** (workspace:*):
   - Link to local workspace version
   - Use for all internal packages

**Example**:
```json
{
  "dependencies": {
    "@kit/ui": "workspace:*",
    "next": "^16.1.0",
    "pg": "8.11.3"
  }
}
```

### Lockfile Discipline

**Rules**:
1. **Never edit manually** - Use pnpm commands only
2. **Always commit** - Lockfile is source of truth
3. **Validate in CI** - Ensure lockfile is up to date
4. **Use frozen installs** - Prevent accidental updates

**Pre-push hook validation**:
```yaml
# lefthook.yml
pre-push:
  commands:
    lockfile-check:
      run: pnpm install --frozen-lockfile
      fail_text: 'pnpm-lock.yaml is out of sync. Run pnpm install and commit.'
```

**CI/CD frozen install**:
```yaml
# .github/workflows/ci.yml
- name: Install dependencies
  run: pnpm install --frozen-lockfile
```

## Shared Packages

### Creating Shared Package

**1. Create directory**:
```bash
mkdir -p packages/my-package
cd packages/my-package
```

**2. Initialize package.json**:
```json
{
  "name": "@kit/my-package",
  "version": "1.0.0",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    }
  },
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch",
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.7.2"
  }
}
```

**3. Create tsconfig.json**:
```json
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

**4. Create source files**:
```typescript
// src/index.ts
export { myFunction } from './my-function';
export type { MyType } from './types';
```

**5. Build package**:
```bash
pnpm build
```

**6. Consume in app**:
```json
// apps/web/package.json
{
  "dependencies": {
    "@kit/my-package": "workspace:*"
  }
}
```

```typescript
// apps/web/app/page.tsx
import { myFunction } from '@kit/my-package';
```

### UI Component Library

**Structure**:
```
packages/ui/
├── src/
│   ├── components/
│   │   ├── button/
│   │   │   ├── button.tsx
│   │   │   ├── button.test.tsx
│   │   │   └── index.ts
│   │   ├── input/
│   │   └── index.ts
│   ├── hooks/
│   ├── utils/
│   └── index.ts
├── package.json
├── tsconfig.json
└── README.md
```

**package.json**:
```json
{
  "name": "@kit/ui",
  "version": "1.0.0",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    },
    "./button": {
      "types": "./dist/components/button/index.d.ts",
      "import": "./dist/components/button/index.js"
    }
  },
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch",
    "test": "vitest"
  },
  "peerDependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  }
}
```

**Consumption**:
```typescript
// Option 1: Import from root
import { Button, Input } from '@kit/ui';

// Option 2: Import from subpath
import { Button } from '@kit/ui/button';
```

### Database Client Package

**Structure**:
```
packages/database/
├── src/
│   ├── client.ts
│   ├── types.ts
│   ├── migrations/
│   └── index.ts
├── package.json
└── tsconfig.json
```

**package.json**:
```json
{
  "name": "@kit/database",
  "version": "1.0.0",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "typegen": "supabase gen types typescript --local > src/types.ts"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.48.1"
  }
}
```

**Type generation**:
```bash
# Generate types in database package
pnpm --filter @kit/database typegen

# Use in apps
import type { Database } from '@kit/database';
```

## TypeScript Project References

### Configuration

**Root tsconfig.json**:
```json
{
  "compilerOptions": {
    "composite": true,
    "declaration": true,
    "declarationMap": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "references": [
    { "path": "./apps/web" },
    { "path": "./packages/ui" },
    { "path": "./packages/database" }
  ]
}
```

**Package tsconfig.json**:
```json
// packages/ui/tsconfig.json
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "composite": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "references": []
}
```

**App tsconfig.json**:
```json
// apps/web/tsconfig.json
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "composite": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "references": [
    { "path": "../../packages/ui" },
    { "path": "../../packages/database" }
  ]
}
```

### Build Order

**TypeScript builds dependencies first**:
```bash
# Build all with project references
tsc --build

# Build specific package
tsc --build packages/ui

# Clean build artifacts
tsc --build --clean

# Force rebuild
tsc --build --force
```

**Benefits**:
- Correct build order
- Incremental builds
- Cross-package type checking
- Fast rebuilds

## Module Aliases

### Configuration

**tsconfig.json paths**:
```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@kit/ui": ["./packages/ui/src"],
      "@kit/ui/*": ["./packages/ui/src/*"],
      "@kit/database": ["./packages/database/src"],
      "@/lib/*": ["./apps/web/lib/*"],
      "@/components/*": ["./apps/web/components/*"]
    }
  }
}
```

**Vitest configuration**:
```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@kit/ui': path.resolve(__dirname, './packages/ui/src'),
      '@kit/database': path.resolve(__dirname, './packages/database/src'),
      '@/lib': path.resolve(__dirname, './apps/web/lib'),
    },
  },
});
```

**Next.js configuration**:
```javascript
// apps/web/next.config.js
module.exports = {
  transpilePackages: ['@kit/ui', '@kit/database'],
};
```

## Common Workflows

### Workflow 1: Add New Package

```bash
# 1. Create package directory
mkdir -p packages/my-package/src

# 2. Create package.json
cat > packages/my-package/package.json <<EOF
{
  "name": "@kit/my-package",
  "version": "1.0.0",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch"
  }
}
EOF

# 3. Create tsconfig.json
cat > packages/my-package/tsconfig.json <<EOF
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  }
}
EOF

# 4. Create source files
echo "export const hello = () => 'Hello!';" > packages/my-package/src/index.ts

# 5. Install dependencies (from root)
pnpm install

# 6. Build package
pnpm --filter @kit/my-package build

# 7. Use in app
pnpm add @kit/my-package --filter web --workspace
```

### Workflow 2: Update Dependency Across All Packages

```bash
# 1. Update dependency in all packages
pnpm update react -r

# 2. Check for mismatches
pnpm syncpack list-mismatches

# 3. Fix mismatches
pnpm syncpack fix-mismatches

# 4. Commit lockfile
git add pnpm-lock.yaml package.json packages/*/package.json apps/*/package.json
git commit -m "chore: update React to v19.0.0 across all packages"
```

### Workflow 3: Build All Packages

```bash
# 1. Clean previous builds
turbo build --force

# 2. Build with Turborepo (uses cache)
turbo build

# 3. Build only affected packages
turbo build --filter=[origin/main]

# 4. Build specific package and its dependencies
turbo build --filter web...
```

### Workflow 4: Run Tests in Parallel

```bash
# 1. Run all tests in parallel
turbo test --parallel

# 2. Run tests for affected packages only
turbo test --filter=[origin/main]

# 3. Run tests with coverage
turbo test -- --coverage

# 4. Run tests in specific package
pnpm --filter web test
```

## Troubleshooting

### pnpm-lock.yaml Out of Sync

```bash
# Error: lockfile is out of sync with package.json

# Solution: Regenerate lockfile
rm pnpm-lock.yaml
pnpm install
```

### Turborepo Cache Issues

```bash
# Cache not invalidating

# Solution 1: Force rebuild
turbo build --force

# Solution 2: Clear cache
rm -rf .turbo

# Solution 3: Check inputs configuration
# Ensure all source files are in inputs array
```

### TypeScript Cannot Find Package

```bash
# Error: Cannot find module '@kit/ui'

# Solution 1: Build the package first
pnpm --filter @kit/ui build

# Solution 2: Check package.json exports
# Ensure "exports" field is correct

# Solution 3: Check tsconfig.json paths
# Ensure alias is configured

# Solution 4: Restart TypeScript server
# In VS Code: Cmd+Shift+P → "Restart TypeScript Server"
```

### Circular Dependencies

```bash
# Error: Circular dependency detected

# Solution: Refactor to remove cycle
# Example: A → B → C → A

# Option 1: Extract shared code to new package D
# A → D, B → D, C → D

# Option 2: Merge packages
# Combine A, B, C into single package

# Option 3: Invert dependency
# Change dependency direction
```

### Workspace Protocol Not Resolving

```bash
# Error: Cannot resolve workspace:*

# Solution: Ensure package is in workspace
# Check pnpm-workspace.yaml includes package path

# Verify package name matches exactly
# @kit/ui in dependency must match "name" in package.json
```

## Performance Optimization

### Build Speed

**Strategies**:
1. Use Turborepo caching (local + remote)
2. Only build affected packages (`--filter=[origin/main]`)
3. Parallel task execution (`--parallel`)
4. TypeScript project references (incremental builds)
5. Exclude unnecessary files from watch (node_modules, dist)

**Measurement**:
```bash
# Measure build time
time turbo build

# Verbose output to find bottlenecks
turbo build --verbose

# Dry run to see what would run
turbo build --dry-run
```

### CI/CD Optimization

**GitHub Actions**:
```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v2
        with:
          version: 9

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'

      # Cache Turborepo
      - uses: actions/cache@v4
        with:
          path: .turbo
          key: turbo-${{ runner.os }}-${{ github.sha }}
          restore-keys: turbo-${{ runner.os }}-

      - run: pnpm install --frozen-lockfile

      # Only build affected packages
      - run: turbo build --filter=[origin/main]
      - run: turbo test --filter=[origin/main]
      - run: turbo lint --filter=[origin/main]
```

### Watch Mode Optimization

**Exclude from watch**:
```json
// tsconfig.json
{
  "watchOptions": {
    "excludeDirectories": [
      "**/node_modules",
      "**/dist",
      "**/.next",
      "**/.turbo"
    ]
  }
}
```

## References

- [pnpm Workspaces Documentation](https://pnpm.io/workspaces)
- [Turborepo Documentation](https://turbo.build/repo/docs)
- [TypeScript Project References](https://www.typescriptlang.org/docs/handbook/project-references.html)
- [Syncpack Documentation](https://jamiemason.github.io/syncpack/)
- [Monorepo.tools](https://monorepo.tools/)

---

**Last Updated**: 2026-01-13
**Related**: [QUALITY_GATES_GUIDE.md](QUALITY_GATES_GUIDE.md), [GIT_WORKFLOW_GUIDE.md](GIT_WORKFLOW_GUIDE.md)

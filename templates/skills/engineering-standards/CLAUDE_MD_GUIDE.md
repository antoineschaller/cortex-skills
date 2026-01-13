# CLAUDE.md Guide

Comprehensive guide for creating and maintaining CLAUDE.md files - the primary documentation that Claude Code reads for understanding your project structure, commands, patterns, and critical rules.

## Table of Contents

- [Overview](#overview)
- [Required Sections](#required-sections)
- [Subdirectory Pattern](#subdirectory-pattern)
- [Integration with cortex-doc-standards](#integration-with-cortex-doc-standards)
- [Best Practices](#best-practices)
- [Examples](#examples)

## Overview

### Purpose

CLAUDE.md is Claude Code's "instruction manual" for your project. It should:

1. **Orient** - Explain project structure and tech stack
2. **Guide** - Document essential commands and workflows
3. **Enforce** - List critical rules that must never be violated
4. **Reference** - Point to skills, agents, and additional resources

### File Location

```
project-root/
├── CLAUDE.md              # Root: Project-wide patterns
├── apps/
│   ├── web/
│   │   └── CLAUDE.md      # Web app: Next.js patterns
│   └── mobile/
│       └── CLAUDE.md      # Mobile: Flutter patterns
└── packages/
    ├── ui/
    │   └── CLAUDE.md      # UI: Component usage
    └── supabase/
        └── CLAUDE.md      # Supabase: Client patterns
```

### Philosophy

**Progressive Disclosure**: Root CLAUDE.md provides overview; subdirectory files provide focused, package-specific context.

## Required Sections

### 1. Tech Stack

**Purpose**: Quick overview of technologies used.

```markdown
# CLAUDE.md

## Tech Stack

**Web**: Next.js 16 | React 19 | Supabase | TypeScript | @kit/ui | TailwindCSS | Vitest | Playwright

**Mobile**: Flutter 3.x | Dart | Riverpod 3.x | Supabase Flutter | ApparenceKit | Freezed

**Backend**: Supabase (PostgreSQL + Auth + Storage) | Edge Functions

**Infrastructure**: Vercel (web) | GitHub Actions (CI/CD) | 1Password (secrets)
```

**Best Practices**:
- Use `|` separator for readability
- Group by platform (web, mobile, backend)
- Include version numbers for frameworks
- List testing tools separately

### 2. Project Structure

**Purpose**: Explain directory organization and conventions.

```markdown
## Project Structure

\`\`\`
ballee/
├── apps/web/                    # Main Next.js app
│   ├── app/                     # App Router
│   ├── lib/                     # Utilities
│   └── supabase/migrations/     # DB migrations (ALWAYS use)
├── apps/mobile/                 # Flutter mobile app (ApparenceKit)
│   ├── lib/core/                # Shared utilities, theme, guards
│   └── lib/modules/             # Feature modules (auth, profile, events)
├── packages/@kit/ui/            # 80+ UI components (use first)
└── .claude/                     # Agents, skills, commands
\`\`\`
```

**Best Practices**:
- Use ASCII tree structure
- Add inline comments for each directory
- Highlight important patterns (e.g., "ALWAYS use migrations")
- Keep under 30 lines (focus on key directories)

### 3. Essential Commands

**Purpose**: Document frequently used commands for development.

```markdown
## Essential Commands

\`\`\`bash
# Web
pnpm dev                    # Start dev server
pnpm build                  # Production build
pnpm quality                # Full quality gate (type + lint + test + build)
pnpm test:e2e               # E2E tests (80% coverage target)
pnpm supabase:web:reset     # Reset local DB
pnpm supabase:web:typegen   # Generate types

# Mobile (run from project root)
pnpm flutter:typegen        # Generate Dart types from Supabase (REQUIRED after migrations)
pnpm flutter:web            # Run web app (localhost:3333, sessions persist)
pnpm flutter:web:chrome     # Run in Chrome with DevTools (port 3333)

# Mobile (run from apps/mobile/)
flutter run                 # Run on connected device/emulator
flutter build ios           # Build iOS app
flutter build apk           # Build Android APK
dart run build_runner build # Generate Freezed/Riverpod code
\`\`\`
```

**Best Practices**:
- Group by platform or workflow
- Add inline comments for each command
- Document context (e.g., "run from project root" vs "run from apps/mobile/")
- Include common flags or options

### 4. Critical Rules (NO EXCEPTIONS)

**Purpose**: Enforce absolute requirements that Claude must never violate.

```markdown
## Critical Rules (NO EXCEPTIONS)

1. **No Version/Enhancement Suffixes**: Never use suffixes like `-v2`, `-v3`, `-improved`, `-enhanced`, `-new`, `-updated`, `-unified` on files OR functions. Modify the original directly. FORBIDDEN: `user-v2.ts`, `createUserEnhanced()`, `FormV3`, `UnifiedService`, `handleSubmitNew()`. **If found: RENAME the file/function to remove the suffix - NEVER delete.**

2. **GitHub Repo Lock**: Always `gh --repo antoineschaller/ballee ...`

3. **Migrations Only**: Never direct psql. Use `apps/web/supabase/migrations/`

4. **RLS First**: Use userClient + RLS, not admin client for queries

5. **Server Components Default**: `'use client'` only when needed

6. **No Unused Variables**: Remove unused imports/vars. Prefix intentional with `_`

7. **Documentation Location Rules**:
   - **NEVER** create .md files in repo root (except CLAUDE.md, README.md)
   - **Temporary work** → docs/wip/active/WIP_{gerund}_{YYYY_MM_DD}.md
   - **Bug investigations** → docs/wip/active/BUG_INVESTIGATION_{description}_{YYYY_MM_DD}.md
   - **Permanent guides** → docs/guides/{kebab-case}.md
   - **Architecture docs** → docs/architecture/{kebab-case}.md
```

**Best Practices**:
- Number rules for clarity
- Use **bold** for rule names
- Provide examples of violations
- Add enforcement mechanisms (e.g., "If found: RENAME, never delete")
- Keep rules absolute (no "usually" or "generally")

### 5. Core Patterns

**Purpose**: Document frequently used architectural patterns.

```markdown
## Core Patterns

### Result Pattern (Services)

\`\`\`typescript
// All services return Result<T, E> - NEVER throw exceptions
type Result<T, E = Error> = { success: true; data: T } | { success: false; error: E };

// Service method example
async create(data: InsertType): Promise<Result<RowType, ServiceError>> {
  const { data: result, error } = await this.client.from('table').insert(data).single();
  if (error) {
    this.logger.error('Create failed', { error, data });
    return { success: false, error: new ServiceError(error.message, 'CREATE_FAILED') };
  }
  return { success: true, data: result };
}
\`\`\`

### Server Actions Pattern

\`\`\`typescript
'use server';

import { withAuthParams } from '@/lib/auth-wrappers';
import { revalidatePath } from 'next/cache';

export const createItemAction = withAuthParams(async (params, formData: FormData) => {
  const validated = CreateItemSchema.safeParse(Object.fromEntries(formData));
  if (!validated.success) {
    return { success: false, error: validated.error.flatten() };
  }

  const service = new ItemService(params.client);
  const result = await service.create(validated.data);

  if (result.success) {
    revalidatePath('/items');
  }
  return result;
});
\`\`\`
```

**Best Practices**:
- Include 3-5 most common patterns
- Show complete, working examples
- Add comments for clarity
- Reference skills for detailed patterns (e.g., "See `service-patterns` skill")

### 6. Naming Conventions

**Purpose**: Enforce consistent naming across the codebase.

```markdown
## Naming Conventions

- Files: `kebab-case` (user-form.tsx)
- Components: `PascalCase` (UserForm)
- Variables: `camelCase` (userName)
- Constants: `SCREAMING_SNAKE_CASE` (MAX_USERS)
- Imports: @kit first, then `@/` alias
- No `@ts-ignore` or `@ts-expect-error` - fix the type properly (document rare exceptions with why)
```

**Best Practices**:
- Bullet list for scannability
- Include examples in parentheses
- Address common mistakes (e.g., @ts-ignore usage)

### 7. Skills & Agents

**Purpose**: Reference skills and agents for detailed guidance.

```markdown
## Skills (On-Demand Knowledge)

Invoke skills for detailed patterns:

| Need | Skill |
|------|-------|
| Database migrations | `database-migration-manager` |
| RLS policies | `rls-policy-generator` |
| Server actions | `api-patterns` |
| Service layer | `service-patterns` |
| UI components | `ui-patterns` |
| Testing | `test-patterns` |
| i18n | `i18n-translation-guide` |

## Agents (Complex Tasks)

Use Task tool with these agents:

| Task | Agent | Model |
|------|-------|-------|
| Database schema/migrations/RLS | `database-specialist` | haiku |
| DB performance (N+1, queries) | `db-performance-agent` | haiku |
| Quality review, pattern validation | `quality-reviewer` | sonnet |
| Sentry error investigation | `sentry-fixer-agent` | sonnet |
```

**Best Practices**:
- Use tables for scannability
- Group related skills/agents
- Include model recommendations for agents

## Subdirectory Pattern

### Purpose

**Focus Context**: Each package gets its own CLAUDE.md with package-specific patterns, reducing noise in root file.

### Structure

```
project/
├── CLAUDE.md                    # Root: Project overview, cross-cutting patterns
├── apps/
│   ├── web/
│   │   └── CLAUDE.md            # Web: Next.js patterns, routing, state
│   └── mobile/
│       └── CLAUDE.md            # Mobile: Flutter patterns, navigation, state
└── packages/
    ├── ui/
    │   └── CLAUDE.md            # UI: Component usage, forms, theming
    ├── supabase/
    │   └── CLAUDE.md            # Supabase: Client usage, auth patterns
    └── features/
        └── CLAUDE.md            # Features: Feature package APIs
```

### Example: apps/web/CLAUDE.md

```markdown
# Web Application

Next.js 16 web application with React 19, Supabase, and @kit/ui components.

## Route Organization

\`\`\`
app/
├── (marketing)/          # Public pages (landing, blog, docs)
├── (auth)/               # Authentication pages
├── home/
│   ├── (user)/           # Personal account context
│   └── [account]/        # Team account context ([account] = team slug)
├── admin/                # Super admin section
└── api/                  # API routes
\`\`\`

**Component organization**: `_components/` for route-specific, `_lib/` for utilities, `_lib/server/` for server-side.

## Critical Patterns

### Async Params (Next.js 15)

\`\`\`typescript
// CORRECT - await params directly
async function Page({ params }: Props) {
  const { account } = await params;
}

// WRONG - don't use React.use() in async functions
async function Page({ params }: Props) {
  const { account } = use(params); // Don't do this
}
\`\`\`

## Related Skills

| Need           | Skill                        |
| -------------- | ---------------------------- |
| Server actions | `api-patterns`               |
| Service layer  | `service-patterns`           |
| UI components  | `ui-patterns`                |
```

**Key Points**:
- **Focused Scope**: Only web-specific patterns
- **No Duplication**: References root CLAUDE.md for global patterns
- **Practical Examples**: Code snippets for common tasks
- **Skill References**: Points to detailed guides

### Example: packages/ui/CLAUDE.md

```markdown
# UI Components Package

80+ production-ready components from @kit/ui (shadcn + MakerKit).

## When to Use

**ALWAYS check @kit/ui first** before building custom components. This package includes:

- **shadcn/ui components** - Button, Dialog, Form, Input, Table, Card, etc.
- **MakerKit components** - DataTable, Trans (i18n), If, Spinner
- **Form utilities** - Zod integration, validation, error handling

## Component Import Pattern

\`\`\`typescript
// Named imports from subpaths
import { Button } from '@kit/ui/button';
import { Dialog, DialogContent, DialogHeader } from '@kit/ui/dialog';
import { Form, FormField, FormItem, FormLabel } from '@kit/ui/form';

// Utility imports
import { cn } from '@kit/ui/cn';
\`\`\`

## Provider Requirements

Some components require context providers:

| Component | Required Provider | Import From |
|-----------|-------------------|-------------|
| Tooltip | TooltipProvider | @kit/ui/tooltip |
| Toast | Toaster | @kit/ui/sonner |

**ESLint enforces** provider requirements via `react-providers/require-provider` rule.
```

**Key Points**:
- **Package-Specific Imports**: Document exact import paths
- **Provider Requirements**: List required context providers
- **Tooling**: Mention ESLint rules that enforce patterns

## Integration with cortex-doc-standards

### Overview

`cortex-doc-standards` is an npm package that provides:
- CLAUDE.md generation from rules
- Structure validation
- Template system

**This guide complements cortex-doc-standards** by documenting structure and best practices, not validation logic.

### Usage

```bash
# Install
npm install -D @akson/cortex-doc-standards

# Initialize configuration
npx cortex-doc-standards rules init --type nextjs --name "My Project"

# Generate CLAUDE.md from rules
npx cortex-doc-standards generate-claude

# Validate existing CLAUDE.md
npx cortex-doc-standards validate --file CLAUDE.md
```

### Rule Types

**cortex-doc-standards supports 6 project types**:
- `nextjs` - Next.js web applications
- `flutter` - Flutter mobile applications
- `monorepo` - Monorepo projects
- `package` - Shared packages
- `backend` - Backend services
- `shopify` - Shopify apps

**Project-specific rules** stored in `.cortex-doc-standards/rules.json`:
```json
{
  "name": "My Project",
  "type": "nextjs",
  "tech_stack": {
    "framework": "Next.js 16",
    "language": "TypeScript",
    "database": "Supabase",
    "ui": "@kit/ui"
  },
  "rules": [
    {
      "id": "no-version-suffixes",
      "description": "Never use version suffixes like -v2, -new",
      "severity": "error"
    }
  ]
}
```

### Workflow

1. **Initialize rules** - `npx cortex-doc-standards rules init`
2. **Customize rules** - Edit `.cortex-doc-standards/rules.json`
3. **Generate CLAUDE.md** - `npx cortex-doc-standards generate-claude`
4. **Validate in CI** - `npx cortex-doc-standards validate`

### Bootstrap Integration

**In bootstrap-project.py**:
```python
# Generate cortex-doc-standards config
subprocess.run([
    'npx', 'cortex-doc-standards', 'rules', 'init',
    '--type', project_type,
    '--name', project_name
], cwd=project_path)

# Generate CLAUDE.md
subprocess.run([
    'npx', 'cortex-doc-standards', 'generate-claude'
], cwd=project_path)
```

## Best Practices

### 1. Be Concise

❌ **Too Verbose**:
```markdown
When you need to authenticate a user and get their information, you should use the withAuth function which will check if the user is authenticated and if not, redirect them to the sign-in page...
```

✅ **Concise**:
```markdown
Use `withAuth` to require authentication (redirects to /sign-in if not authenticated).
```

### 2. Use Tables for Scanability

❌ **Prose**:
```markdown
For authentication, use withAuth. If you need user context, use withAuthParams. For super admin operations, use withSuperAdmin.
```

✅ **Table**:
```markdown
| Wrapper | Use When |
|---------|----------|
| withAuth | Require authentication |
| withAuthParams | Need user context (client, accountId) |
| withSuperAdmin | Super admin operations |
```

### 3. Provide Complete Examples

❌ **Incomplete**:
```markdown
Use `createEventAction` for creating events.
```

✅ **Complete**:
```markdown
\`\`\`typescript
export const createEventAction = withAuthParams(async (params, formData: FormData) => {
  const validated = CreateEventSchema.safeParse(Object.fromEntries(formData));
  if (!validated.success) return { success: false, error: validated.error };

  const result = await service.create({ ...validated.data, account_id: params.accountId });
  if (result.success) revalidatePath('/events');
  return result;
});
\`\`\`
```

### 4. Progressive Disclosure

**Root CLAUDE.md** - Overview and cross-cutting patterns:
```markdown
# CLAUDE.md

## Tech Stack
[List all tech]

## Project Structure
[High-level directories]

## Critical Rules
[Absolute requirements]

## Related Packages
See subdirectory CLAUDE.md files for package-specific patterns:
- [apps/web/CLAUDE.md](apps/web/CLAUDE.md) - Next.js patterns
- [packages/ui/CLAUDE.md](packages/ui/CLAUDE.md) - Component usage
```

**Subdirectory CLAUDE.md** - Package-specific details:
```markdown
# Web Application

[Focused on web-specific patterns only]

## Related
See [root CLAUDE.md](../../CLAUDE.md) for project-wide patterns.
```

### 5. Keep Updated

**Update Triggers**:
- Framework version upgrades
- New critical rules added
- Architectural pattern changes
- Team feedback on unclear sections

**Version Control**:
```markdown
---
**Last Updated**: 2026-01-13
**Maintainer**: Engineering Team
```

### 6. Link to Skills

**Don't duplicate skill content in CLAUDE.md**:

❌ **Bad** (duplicates skill):
```markdown
## Database Migrations

Migrations must be idempotent. Use IF NOT EXISTS for CREATE statements...

[500 lines of migration documentation]
```

✅ **Good** (references skill):
```markdown
## Database Migrations

Use `apps/web/supabase/migrations/` for all schema changes. Never use direct psql.

For detailed migration patterns, see: `/database-migration-manager`
```

## Examples

### Minimal CLAUDE.md (Small Project)

```markdown
# My Small Project

## Tech Stack

**Web**: Next.js 16 | TypeScript | Supabase | TailwindCSS

## Essential Commands

\`\`\`bash
pnpm dev        # Start dev server
pnpm build      # Production build
pnpm test       # Run tests
\`\`\`

## Critical Rules

1. **Migrations Only**: Never direct psql. Use `supabase/migrations/`
2. **RLS First**: Use userClient + RLS for data access

## Related Skills

- `database-migration-manager` - Database migrations
- `api-patterns` - Server actions
```

### Comprehensive CLAUDE.md (Large Monorepo)

```markdown
# Ballee

Guidance for Claude Code when working with Ballee.

## Tech Stack

**Web**: Next.js 16 | React 19 | Supabase | TypeScript | @kit/ui | TailwindCSS | Vitest | Playwright

**Mobile**: Flutter 3.x | Dart | Riverpod 3.x | Supabase Flutter | ApparenceKit | Freezed

## Project Structure

[30 lines showing key directories]

## Essential Commands

[20+ commands grouped by platform]

## Critical Rules (NO EXCEPTIONS)

[10 numbered rules with examples]

## Core Patterns

[5 most common patterns with code examples]

## Naming Conventions

[Bullet list of naming rules]

## Skills (On-Demand Knowledge)

[Table of 30+ skills organized by category]

## Agents (Complex Tasks)

[Table of 5 agents with use cases]

## Subdirectory CLAUDE.md Files

[Links to package-specific CLAUDE.md files]
```

---

**Last Updated**: 2026-01-13
**Related**: [cortex-doc-standards](https://github.com/antoineschaller/cortex-packages/tree/main/packages/doc-standards), [DOCUMENTATION_GUIDE.md](DOCUMENTATION_GUIDE.md)

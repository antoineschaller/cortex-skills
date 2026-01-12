# Skill Creation Guide

Comprehensive workflow for creating high-quality Claude Code skills from planning to deployment.

## Table of Contents

1. [Planning Phase](#planning-phase)
2. [Writing Descriptions](#writing-descriptions)
3. [Structuring Content](#structuring-content)
4. [Testing Discovery](#testing-discovery)
5. [Examples Library](#examples-library)

---

## Planning Phase

### 1. Define Scope

**Single Responsibility Principle**: Each skill should solve one specific problem domain.

**Questions to Ask:**
- What is the ONE main task this skill helps with?
- Are there sub-tasks that could be separate skills?
- Will this skill exceed 500 lines? (If yes, plan for progressive disclosure)
- What tools will the skill need? (Read, Write, Bash, etc.)

**Scope Examples:**

✅ **GOOD - Focused**:
- `database-migration-manager` - Creating and managing database migrations
- `flutter-query-testing` - Testing Supabase queries in Flutter
- `web-performance-metrics` - Measuring and optimizing web performance

❌ **TOO BROAD**:
- `database-tools` - Too vague, covers migrations + queries + performance + RLS
- `flutter-development` - Too comprehensive (should split into multiple skills)
- `web-optimization` - Unclear scope, mixes SEO + performance + accessibility

### 2. Choose a Name

**Naming Formula**: `domain-action-noun`

**Rules:**
- Lowercase only
- Hyphens for word separation
- Maximum 64 characters
- Descriptive and searchable
- Match directory name exactly

**Examples:**

| Pattern | Example | Why It Works |
|---------|---------|--------------|
| `domain-manager` | `database-migration-manager` | Clear domain + action |
| `domain-action` | `flutter-query-testing` | Specific task |
| `concept-pattern` | `api-patterns` | Architectural guidance |
| `tool-specialist` | `sentry-error-manager` | Tool-specific expertise |

**Anti-Patterns:**

❌ `db-stuff` - Vague
❌ `helpers` - No domain context
❌ `utils` - Generic, unmaintainable
❌ `migration-v2` - Never use version suffixes
❌ `new-skill` - "new" is temporary
❌ `improved-X` - "improved" is subjective

### 3. Plan File Structure

**Single-File Skill** (simple cases, < 500 lines total):
```
skill-name/
└── SKILL.md
```

**Multi-File Skill** (complex cases, progressive disclosure):
```
skill-name/
├── SKILL.md              # Overview + quick ref (< 500 lines)
├── REFERENCE.md          # Detailed API docs
├── EXAMPLES.md           # Comprehensive examples
├── TROUBLESHOOTING.md    # Common issues
└── scripts/              # Utility scripts
    ├── helper.py
    └── validate.sh
```

**With Resources**:
```
skill-name/
├── SKILL.md
├── REFERENCE.md
├── resources/
│   ├── templates/        # Reusable templates
│   │   └── template.sql
│   └── config/           # Configuration files
│       └── example.json
└── scripts/
    └── generator.py
```

### 4. Identify Trigger Keywords

**What are trigger keywords?**
Words and phrases users would naturally say when they need this skill.

**Keyword Categories:**

1. **Action Verbs**: create, analyze, optimize, validate, generate, test, deploy, configure, monitor
2. **Domain Nouns**: database, migration, query, performance, security, API, form, component
3. **File Extensions**: .ts, .tsx, .sql, .md, .dart, .py, .sh
4. **Error Patterns**: "RLS error", "N+1 query", "type error", "build failure"
5. **Technology Names**: Supabase, PostgreSQL, Flutter, Riverpod, Next.js, React
6. **User Goals**: "faster queries", "optimize bundle", "fix security", "improve accessibility"

**Example Mapping:**

| Skill | Trigger Keywords |
|-------|-----------------|
| `database-migration-manager` | create migration, add column, alter table, schema change, .sql file, idempotent migration |
| `flutter-query-testing` | test Supabase query, validate Flutter API, query failure, RLS error, .dart file |
| `web-performance-metrics` | Core Web Vitals, INP, LCP, CLS, bundle size, Lighthouse, performance optimization |

### 5. Define Prerequisites

**What must exist before this skill can be used?**

- Required tools (CLI tools, packages, libraries)
- Required environment variables
- Required file structure
- Related skills that should exist
- Minimum software versions

**Template:**
```markdown
## Prerequisites

**Required Tools:**
- Tool X version Y+
- Package Z

**Required Environment:**
- Environment variable: `VAR_NAME`
- Database connection configured

**Required Skills:**
- `prerequisite-skill` - For setting up X

**Minimum Versions:**
- Next.js 16+
- PostgreSQL 14+
```

---

## Writing Descriptions

### The Description Formula

```yaml
description: "[Action verbs] [what it does]. [When to use it]. [Trigger keywords]."
```

### Anatomy of a Great Description

**Components:**

1. **Action Verbs** (3-5 words)
   - Start with action verbs that match user intent
   - Use present tense
   - Be specific, not generic

2. **What It Does** (1-2 sentences)
   - Core capabilities
   - Key features
   - Value proposition

3. **When to Use** (1 sentence)
   - Specific scenarios
   - Clear triggers
   - Edge cases

4. **Trigger Keywords** (embedded naturally)
   - Technology names
   - File extensions
   - Error patterns
   - User goals

### Examples Breakdown

**Example 1: database-migration-manager**

```yaml
description: "Create and manage Supabase database migrations with idempotent SQL, RLS policies, and zero-downtime deployments. Use when adding columns, creating tables, modifying schema, or when you see migration errors. Handles .sql files with proper naming conventions."
```

**Analysis:**
- ✅ Action verbs: Create, manage
- ✅ What it does: database migrations, idempotent SQL, RLS, zero-downtime
- ✅ When to use: adding columns, creating tables, modifying schema
- ✅ Triggers: migration, schema, .sql, RLS, idempotent

**Example 2: flutter-query-testing**

```yaml
description: "Test Flutter Supabase queries with static validation, live testing, RLS verification, and CI integration. Use when debugging query failures, validating .dart Supabase code, or before deploying mobile changes."
```

**Analysis:**
- ✅ Action verbs: Test
- ✅ What it does: static validation, live testing, RLS verification, CI
- ✅ When to use: debugging failures, validating code, deploying
- ✅ Triggers: Flutter, Supabase, query, RLS, .dart, mobile

**Example 3: web-performance-metrics**

```yaml
description: "Analyze and optimize web app performance with Core Web Vitals tracking (INP, LCP, CLS), bundle analysis, runtime optimization, and network metrics. Use when measuring performance, debugging slowdowns, optimizing bundles, or preventing regressions."
```

**Analysis:**
- ✅ Action verbs: Analyze, optimize
- ✅ What it does: Core Web Vitals, bundle analysis, runtime optimization
- ✅ When to use: measuring, debugging, optimizing, preventing regressions
- ✅ Triggers: performance, Core Web Vitals, INP, LCP, CLS, bundle, slowdowns

### Common Description Mistakes

| Mistake | Example | Fix |
|---------|---------|-----|
| **Too vague** | "Helps with documents" | "Extract text from PDFs, fill forms, merge documents. Use when working with .pdf files." |
| **No triggers** | "Database helper tool" | "Create database migrations, RLS policies, zero-downtime schema changes. Use when adding columns or modifying tables." |
| **Too technical** | "Implements expand-contract pattern for schema evolution" | "Create zero-downtime database migrations. Use when renaming columns or changing schema without downtime." |
| **Missing when to use** | "Manages Supabase migrations" | "Create Supabase migrations with idempotent SQL. Use when adding tables, columns, or RLS policies." |

### Description Testing Checklist

- [ ] Starts with action verbs (create, analyze, test, etc.)
- [ ] Includes 5+ trigger keywords users would naturally say
- [ ] Has clear "use when" clause with specific scenarios
- [ ] Mentions file extensions if relevant (.ts, .sql, .dart)
- [ ] Includes technology names (Supabase, Flutter, Next.js)
- [ ] Under 1024 characters (hard limit)
- [ ] Natural language, not marketing copy
- [ ] Specific, not generic

---

## Structuring Content

### YAML Frontmatter

**Required Fields:**
```yaml
---
name: skill-name              # Must match directory name
description: [See formula]    # Max 1024 chars, trigger keywords
---
```

**Recommended Fields:**
```yaml
---
name: skill-name
description: [...]
version: "1.0.0"             # Semantic versioning
last_updated: "2026-01-12"   # ISO date format
---
```

**Optional Fields:**
```yaml
---
name: skill-name
description: [...]
version: "1.0.0"
last_updated: "2026-01-12"
allowed-tools: Read, Bash(python:*), Grep  # Tool restrictions
model: claude-haiku-3-5-20250110           # Model override
context: fork                               # Run in isolated context
agent: general-purpose                      # Agent type when forked
user-invocable: true                        # Show in /command menu
hooks:                                      # Skill-scoped hooks
  PreToolUse:
    - matcher: "Write"
      hooks:
        - type: command
          command: "./scripts/validate.sh"
---
```

### Content Organization

**Required Sections (in order):**

1. **Title** (`# Skill Name`)
2. **When to Use This Skill** (bullet list)
3. **Quick Reference** (minimal working example)
4. **Core Workflow** or **Core Patterns**
5. **Troubleshooting** (table format)
6. **Related Resources** (links to supporting docs)

**Optional Sections:**
- Prerequisites
- Common Patterns
- Advanced Patterns
- Examples
- Best Practices
- Anti-Patterns

### Content Structure Template

```markdown
---
name: skill-name
description: [Formula]
version: "1.0.0"
last_updated: "YYYY-MM-DD"
---

# Skill Name

Brief overview (1-2 sentences). High-level purpose.

## When to Use This Skill

- **Use case 1** - Description of scenario
- **Use case 2** - Another scenario
- **Use case 3** - Edge case or advanced scenario

## Quick Reference

```bash
# Complete minimal example that works out of the box
command --flag value input.txt
```

**Expected output:**
```
Success: Operation completed
```

## Core Workflow

### Step 1: [Action Name]

Detailed instructions for this step.

```code
# Working code example
```

### Step 2: [Next Action]

More instructions.

```code
# Another example
```

## Common Patterns

### Pattern 1: [Common Use Case]

```code
# Most frequent pattern (80% use case)
```

### Pattern 2: [Alternative Approach]

```code
# Second most common pattern
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Error X | Reason Y | Fix Z |
| Warning A | Reason B | Fix C |

## Related Resources

- For complete API reference, see [REFERENCE.md](REFERENCE.md)
- For detailed examples, see [EXAMPLES.md](EXAMPLES.md)
- Related skill: [`other-skill`](../other-skill/SKILL.md)
- External docs: [Title](https://url.com)

---

**Last Updated**: YYYY-MM-DD
**Version**: 1.0.0
```

### Writing the Quick Reference

**Purpose**: Show a complete, working example that demonstrates the core capability in 10-20 lines.

**Rules:**
- Must be copy-paste runnable
- Include all necessary setup
- Show expected output
- Use realistic data (not foo/bar)
- Cover the 80% use case

**Example Structure:**

```markdown
## Quick Reference

```bash
# 1. Setup (if needed)
export VAR=value

# 2. Main command with common flags
tool command --flag value input.txt

# 3. Verification
tool verify output.txt
```

**Expected output:**
```
✓ Processing complete
✓ Validation passed
```

**Common options:**
| Flag | Purpose |
|------|---------|
| `--verbose` | Show detailed output |
| `--dry-run` | Preview without executing |
```

### Writing the Core Workflow

**Format**: Step-by-step instructions with code examples.

**Each Step Should Have:**
1. Clear action title (`### Step 1: Create Migration File`)
2. Explanation (1-2 sentences)
3. Working code example
4. Expected output or result

**Example:**

```markdown
## Core Workflow

### Step 1: Create Migration File

Generate a new migration with proper naming convention:

```bash
pnpm supabase:web:migration "add_email_column"
```

This creates: `apps/web/supabase/migrations/YYYYMMDDHHMMSS_add_email_column.sql`

### Step 2: Write Idempotent SQL

Use IF NOT EXISTS for safety:

```sql
-- Add column only if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'email'
  ) THEN
    ALTER TABLE users ADD COLUMN email TEXT;
  END IF;
END $$;
```

### Step 3: Apply Migration

```bash
pnpm supabase:web:migrate
```

Verify with:
```bash
psql -c "\d users"
```
```

### Troubleshooting Section

**Format**: Table with Issue → Cause → Solution

```markdown
## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `policy "X" already exists` | Migration not idempotent | Wrap CREATE POLICY in DO $$ block |
| `column "y" already exists` | ADD COLUMN without IF NOT EXISTS | Add IF NOT EXISTS check |
| Migration fails on re-run | Non-idempotent SQL | Follow idempotent patterns in SKILL.md |
```

**Best Practices:**
- Include real error messages users will see
- Explain root cause, not just symptom
- Provide actionable solution with code
- Link to relevant sections for more details

---

## Testing Discovery

### Discovery Testing Workflow

**Step 1: Verify Skill is Loaded**

Ask Claude:
```
What Skills are available?
```

You should see your skill listed. If not:
- Check file is named `SKILL.md` (case-sensitive)
- Validate YAML frontmatter (no tabs, valid syntax)
- Ensure directory structure is correct

**Step 2: Test Trigger Phrases**

Use keywords from your description naturally:

| Skill | Test Phrase |
|-------|-------------|
| `database-migration-manager` | "Create a migration to add an email column" |
| `flutter-query-testing` | "Test my Supabase queries in the Flutter app" |
| `web-performance-metrics` | "Analyze Core Web Vitals for my Next.js app" |

Claude should:
1. Show skill confirmation: "I'll use the X skill..."
2. Load skill instructions
3. Follow the patterns correctly

**Step 3: Run Discovery Test Script**

```bash
./.claude/skills/ai-skill-manager/scripts/test-discovery.sh skill-name
```

This validates:
- Skill loads without errors
- Description triggers correctly
- Examples work as documented

**Step 4: Test Edge Cases**

Try phrases that should NOT trigger your skill:
- Different domain (should trigger different skill)
- Vague requests (might not trigger any skill)
- Similar but distinct tasks (should trigger related skill)

---

## Examples Library

### Example 1: Simple Single-File Skill

**Directory Structure:**
```
code-formatter/
└── SKILL.md
```

**SKILL.md:**
```yaml
---
name: code-formatter
description: "Format code according to project style guide using Prettier, ESLint, and language-specific formatters. Use when fixing code style, running pre-commit checks, or standardizing formatting across the codebase."
version: "1.0.0"
last_updated: "2026-01-12"
model: claude-haiku-3-5-20250110  # Fast model for simple task
---

# Code Formatter

Automatically format code to match project style guidelines.

## When to Use This Skill

- **Fixing code style** - Format files to match ESLint/Prettier rules
- **Pre-commit checks** - Ensure code passes formatting before commit
- **Batch formatting** - Format multiple files at once

## Quick Reference

```bash
# Format single file
pnpm format:fix apps/web/app/page.tsx

# Format all files
pnpm format:fix

# Check formatting (no changes)
pnpm format
```

## Core Patterns

### Pattern 1: Format TypeScript/JavaScript

```bash
pnpm prettier --write "**/*.{ts,tsx,js,jsx}"
```

### Pattern 2: Fix ESLint Issues

```bash
pnpm eslint --fix "**/*.{ts,tsx}"
```

### Pattern 3: Format SQL

```bash
pg_format --inplace apps/web/supabase/migrations/*.sql
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Prettier conflicts with ESLint | Competing rules | Check `.prettierrc` and `.eslintrc` alignment |
| Format fails on large files | Memory limit | Format directories individually |

## Related Resources

- ESLint config: `apps/web/eslint.config.mjs`
- Prettier config: `.prettierrc`
```

### Example 2: Multi-File Skill with Progressive Disclosure

**Directory Structure:**
```
api-integration-specialist/
├── SKILL.md
├── REFERENCE.md
├── EXAMPLES.md
├── TROUBLESHOOTING.md
└── scripts/
    ├── validate-api.py
    └── test-endpoint.sh
```

**SKILL.md** (< 500 lines, overview only):
```yaml
---
name: api-integration-specialist
description: "Integrate third-party APIs with error handling, retry logic, rate limiting, and monitoring. Use when connecting to external APIs, handling API failures, or implementing webhooks."
version: "1.0.0"
last_updated: "2026-01-12"
---

# API Integration Specialist

Comprehensive guide for integrating third-party APIs safely and reliably.

## When to Use This Skill

- **Connecting to external APIs** - REST, GraphQL, webhooks
- **Handling API failures** - Retry logic, circuit breakers, fallbacks
- **Rate limiting** - Respect API quotas, implement backoff

## Quick Reference

```typescript
// Basic API integration with retry
import { withRetry } from '@/lib/retry';

export async function fetchUserData(userId: string) {
  return withRetry(async () => {
    const response = await fetch(`https://api.example.com/users/${userId}`, {
      headers: { 'Authorization': `Bearer ${process.env.API_KEY}` }
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }

    return response.json();
  });
}
```

## Core Patterns

### Pattern 1: REST API Integration

[Brief overview with link to detailed examples]

See [EXAMPLES.md](EXAMPLES.md#rest-api-integration) for complete implementations.

### Pattern 2: GraphQL Integration

[Brief overview with link]

See [EXAMPLES.md](EXAMPLES.md#graphql-integration) for complete implementations.

### Pattern 3: Webhook Handling

[Brief overview with link]

See [EXAMPLES.md](EXAMPLES.md#webhook-handling) for complete implementations.

## Troubleshooting

For common issues and solutions, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Related Resources

- **[REFERENCE.md](REFERENCE.md)** - Complete API reference for helper functions
- **[EXAMPLES.md](EXAMPLES.md)** - Detailed implementation examples
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- Related skill: [`api-patterns`](../api-patterns/SKILL.md)
```

**REFERENCE.md** (loaded when needed):
```markdown
# API Integration Reference

Complete API documentation for helper functions and utilities.

## withRetry()

Retry failed API calls with exponential backoff.

**Signature:**
```typescript
function withRetry<T>(
  fn: () => Promise<T>,
  options?: RetryOptions
): Promise<T>
```

[Detailed parameter descriptions, return values, error handling...]
```

**EXAMPLES.md** (loaded when needed):
```markdown
# API Integration Examples

Comprehensive examples for common integration patterns.

## REST API Integration

### Example 1: GET Request with Authentication

```typescript
// Complete working example with setup, error handling, types
[Full code]
```

[More examples...]
```

**TROUBLESHOOTING.md** (loaded when needed):
```markdown
# API Integration Troubleshooting

## Common Issues

### Rate Limiting Errors

**Symptom**: `429 Too Many Requests`

**Cause**: Exceeded API rate limit

**Solution**:
```typescript
// Implement rate limiting
[Code example]
```

[More troubleshooting entries...]
```

---

## Key Takeaways

1. **Plan before writing** - Define scope, name, triggers, structure
2. **Description is critical** - Use formula with action verbs + triggers
3. **Quick reference first** - Show working example immediately
4. **Progressive disclosure** - Split files if > 500 lines
5. **Test discovery** - Verify trigger phrases work correctly
6. **Use tables** - More scannable than prose
7. **Real examples** - From actual codebase, not foo/bar
8. **Maintain CHANGELOG** - Track changes over time

---

**Next**: See [MAINTENANCE_GUIDE.md](MAINTENANCE_GUIDE.md) for updating and versioning skills.

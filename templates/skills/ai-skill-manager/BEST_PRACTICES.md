# AI Skills Best Practices

Comprehensive reference combining Claude Code patterns, industry standards, and examples library from 2026 research.

## Table of Contents

1. [Industry Standards](#industry-standards)
2. [Claude Code Patterns](#claude-code-patterns)
3. [Common Anti-Patterns](#common-anti-patterns)
4. [Examples Library](#examples-library)
5. [Quality Checklist](#quality-checklist)

---

## Industry Standards

### Progressive Disclosure (Universal Pattern)

**Source**: Anthropic Engineering, 2025

**Principle**: Load information layer by layer, only what's needed when needed.

**Implementation**:
```
Tier 1: Metadata (< 100 tokens) - Loaded at startup for discovery
Tier 2: Core Instructions (< 5k tokens) - Loaded when skill invoked
Tier 3: Detailed Resources - Loaded on demand via references
```

**Token Savings**: 95-98% reduction for large skills

**Industry Adoption**: Standard practice across LangChain, AutoGPT, Claude Code

### Semantic Versioning (Software Industry Standard)

**Format**: `MAJOR.MINOR.PATCH`

| Version Type | When to Increment | Example Change |
|--------------|-------------------|----------------|
| MAJOR | Breaking changes | Removing sections, restructuring files |
| MINOR | New features (backward-compatible) | Adding patterns, new sections |
| PATCH | Bug fixes, documentation | Typo fixes, clarifications |

**Required Files**:
- CHANGELOG.md - Track all changes
- Version in YAML frontmatter

### Few-Shot Learning (AI/ML Best Practice)

**Source**: Prompt Engineering Guide, 2026

**Pattern**: Provide 3-5 complete examples showing desired behavior

**Structure**:
```markdown
### Example 1: [Common Case - 80% use case]
**Input**: [...]
**Expected**: [...]
**Code**: [Complete working example]

### Example 2: [Edge Case - 15% use case]
[Same structure]

### Example 3: [Error Handling - 5% use case]
[Same structure]
```

**Why It Works**: LLMs learn patterns from examples, especially for complex tasks

### Chain-of-Thought Prompting (AI Research 2023-2026)

**Source**: Google Research, widely adopted

**Pattern**: Show step-by-step reasoning process

**Template**:
```markdown
## Workflow: [Complex Task]

1. **Analyze the requirement**
   - What: [Description]
   - Why: [Reason]
   - How: [Approach]

2. **Choose the approach**
   - Option A: [...] - ❌ Not ideal because [...]
   - Option B: [...] - ✅ Best choice because [...]

3. **Implement**
   [Code]

4. **Verify**
   [Validation]
```

**Benefit**: Helps AI understand complex multi-step workflows

### Token Optimization Strategies (Industry Standard 2026)

**Sources**: Multiple AI platforms (OpenAI, Anthropic, Cohere)

**Techniques**:

| Technique | Token Savings | Use Case |
|-----------|---------------|----------|
| Progressive disclosure | 95-98% | Skills > 500 lines |
| Table format vs prose | 40-60% | Comparisons, references |
| Script execution (zero-context) | 90-95% | Utilities, validation |
| Template reuse | 60-80% | Repetitive patterns |
| Cross-reference vs duplicate | 100% | Shared information |

**Cost Impact**: Real-world data shows 25-50% reduction in monthly AI costs with optimization

### Context Window Management (2026 Standard)

**Sources**: Industry research, LLM best practices

**Strategies**:

1. **Context Compression**
   - LLMLingua: 20x compression while preserving semantics
   - Example: 800-token prompt → 40 tokens (95% reduction)

2. **Strategic Positioning**
   - Place critical instructions at start (higher attention)
   - Earlier directives have higher probability of model alignment

3. **Retrieval-on-Demand**
   - Fetch only most relevant content when needed
   - Use tools to load supporting docs progressively

4. **Context Window Budgeting**
   - Allocate portions: instructions (30%), conversation (40%), retrieved knowledge (20%), output margin (10%)

### Quality Metrics (Enterprise AI Standard)

**Sources**: IBM Research, Galileo AI, WandB

**Multi-Metric Evaluation**:

| Category | Metrics |
|----------|---------|
| **Performance** | Task completion rate, accuracy, speed, cost efficiency |
| **Reliability** | Consistency, error rate, hallucination detection |
| **User Experience** | Discovery rate (>90%), success rate (>95%), CSAT |
| **Efficiency** | Tokens per task (<5k), latency (p50/p95/p99) |

**Key Principle**: Never optimize for a single KPI - balance accuracy, latency, cost, satisfaction, and safety

---

## Claude Code Patterns

### Skill Discovery Formula

**Description Pattern**:
```yaml
description: "[Action verbs] [what it does]. [When to use it]. [Trigger keywords]."
```

**Components**:
1. **Action verbs** (3-5 words): create, analyze, optimize, validate, generate
2. **What it does** (1-2 sentences): Core capabilities, key features
3. **When to use** (1 sentence): Specific scenarios, clear triggers
4. **Trigger keywords** (embedded): Technology names, file extensions, error patterns

**Example**:
```yaml
description: "Create and manage Supabase database migrations with idempotent SQL, RLS policies, and zero-downtime deployments. Use when adding columns, creating tables, modifying schema, or when you see migration errors. Handles .sql files with proper naming conventions."
```

**Trigger Keywords**: migration, schema, idempotent, RLS, .sql, zero-downtime, columns, tables

### File Structure Patterns

**Single-File Skill** (< 500 lines):
```
skill-name/
└── SKILL.md
```

**Multi-File Skill** (progressive disclosure):
```
skill-name/
├── SKILL.md              # Core (< 500 lines, < 5k tokens)
├── REFERENCE.md          # API docs (loaded when needed)
├── EXAMPLES.md           # Detailed examples (loaded when needed)
├── TROUBLESHOOTING.md    # Edge cases (loaded when needed)
└── scripts/              # Zero-context execution
    ├── helper.py
    └── validate.sh
```

**With Resources**:
```
skill-name/
├── SKILL.md
├── resources/
│   ├── templates/
│   │   └── template.sql
│   └── config/
│       └── example.json
└── scripts/
    └── generator.py
```

### Content Organization Pattern

**Required Sections (in order)**:

1. **Title** - `# Skill Name`
2. **When to Use This Skill** - Bullet list of use cases
3. **Quick Reference** - Complete minimal working example
4. **Core Workflow** or **Core Patterns** - Step-by-step or pattern-based
5. **Troubleshooting** - Table format: Issue | Cause | Solution
6. **Related Resources** - Progressive disclosure links

**Optional Sections**:
- Prerequisites
- Common Patterns
- Advanced Patterns
- Best Practices
- Anti-Patterns

### YAML Frontmatter Pattern

**Minimal** (required):
```yaml
---
name: skill-name
description: [Use discovery formula]
---
```

**Recommended**:
```yaml
---
name: skill-name
description: [...]
version: "1.0.0"
last_updated: "2026-01-12"
---
```

**Advanced**:
```yaml
---
name: skill-name
description: [...]
version: "1.0.0"
last_updated: "2026-01-12"
allowed-tools: Read, Bash(python:*), Grep  # Tool restrictions
model: claude-haiku-3-5-20250110           # Model override for simple tasks
user-invocable: true                        # Show in /command menu
---
```

### Quick Reference Pattern

**Purpose**: Show complete, working example demonstrating core capability in 10-20 lines

**Structure**:
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

**Expected output**:
```
✓ Processing complete
✓ Validation passed
```

**Common options**:
| Flag | Purpose |
|------|---------|
| `--verbose` | Show detailed output |
```

**Rules**:
- Must be copy-paste runnable
- Use realistic data (not foo/bar)
- Cover 80% use case
- Show expected output

### Troubleshooting Table Pattern

**Format**: Issue → Cause → Solution

```markdown
## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Error X | Reason Y | Fix Z with code example |
| Warning A | Reason B | Fix C with commands |
```

**Best Practices**:
- Include real error messages users will see
- Explain root cause, not just symptom
- Provide actionable solution with code
- Link to relevant sections for details

---

## Common Anti-Patterns

### ❌ Anti-Pattern 1: Vague Descriptions

**Problem**: Skill never gets discovered

**Bad Example**:
```yaml
description: "Helps with documents"
```

**Why It Fails**:
- No trigger keywords
- No specific use cases
- Claude can't identify when to use it

**Good Example**:
```yaml
description: "Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction."
```

### ❌ Anti-Pattern 2: Monolithic Skills

**Problem**: Token waste, slow load times, poor maintainability

**Bad Example**:
```
flutter-development/
└── SKILL.md (1,620 lines, ~12k tokens)
```

**Why It Fails**:
- Loads everything even for simple tasks
- Hard to navigate and maintain
- Exceeds optimal token budget

**Good Example**:
```
flutter-development/
├── SKILL.md (450 lines, ~3.5k tokens)
├── REFERENCE.md (API docs - loaded when needed)
└── EXAMPLES.md (Detailed examples - loaded when needed)
```

### ❌ Anti-Pattern 3: Missing Quick Reference

**Problem**: Users have to read entire skill to find basic usage

**Bad Example**:
```markdown
# My Skill

This skill helps you do X. It's based on the principle of Y...

[5 paragraphs of background]

## Theory

[More explanation]

## Usage

[Finally, buried 500 lines down, the actual example]
```

**Good Example**:
```markdown
# My Skill

## Quick Reference

```bash
# Complete working example
command --flag value input.txt
```

[Background and details below if needed]
```

### ❌ Anti-Pattern 4: Inline Scripts

**Problem**: Script code consumes tokens unnecessarily

**Bad Example**:
```markdown
Here's a validation script:

```python
#!/usr/bin/env python3
# [100+ lines of script code loaded into context]
```

Run with: `python validate.py input.txt`
```

**Good Example**:
```markdown
Run the validation script:

```bash
python scripts/validate.py input.txt
```

The script checks for:
- Idempotency patterns
- Naming conventions
```

### ❌ Anti-Pattern 5: Prose Over Tables

**Problem**: Verbose, hard to scan, wastes tokens

**Bad Example**:
```markdown
When you need authentication, use withAuth. If you need user context
and client, use withAuthParams. For super admin operations, use withSuperAdmin.
```

**Good Example**:
```markdown
| Wrapper | Use When |
|---------|----------|
| withAuth | Authentication only |
| withAuthParams | Need user, client, accountId |
| withSuperAdmin | Super admin operations |
```

### ❌ Anti-Pattern 6: Duplicate Content

**Problem**: Same information in multiple skills, maintenance burden

**Bad Example**:
```markdown
# skill-a/SKILL.md
## RLS Policies
[50 lines of RLS documentation]

# skill-b/SKILL.md
## RLS Policies
[Same 50 lines duplicated]
```

**Good Example**:
```markdown
# skill-a/SKILL.md
## RLS Policies
See [`rls-policy-generator`](../rls-policy-generator/SKILL.md)

# skill-b/SKILL.md
## Security
Apply RLS using [`rls-policy-generator`](../rls-policy-generator/SKILL.md)
```

### ❌ Anti-Pattern 7: No Versioning

**Problem**: Can't track changes, difficult to debug issues

**Bad Example**:
```yaml
---
name: skill-name
description: [...]
---
```

**Good Example**:
```yaml
---
name: skill-name
description: [...]
version: "1.2.0"
last_updated: "2026-01-12"
---

# Also maintain CHANGELOG.md
```

### ❌ Anti-Pattern 8: Broken Examples

**Problem**: User frustration, loss of trust

**Bad Example**:
```markdown
## Example

```typescript
// This should work
const result = await oldAPI.doSomething();
```
```

**Good Example**:
```markdown
## Example

```typescript
// Tested with Next.js 16, works as of 2026-01-12
import { newAPI } from '@/lib/api';

const result = await newAPI.doSomething();
console.log(result); // { success: true, data: [...] }
```
```

---

## Examples Library

### Example 1: Minimal Skill (Perfect for Simple Tasks)

**Use Case**: Code formatting skill using existing tools

```yaml
---
name: code-formatter
description: "Format code according to project style guide using Prettier, ESLint, and language-specific formatters. Use when fixing code style, running pre-commit checks, or standardizing formatting across the codebase."
version: "1.0.0"
last_updated: "2026-01-12"
model: claude-haiku-3-5-20250110  # Fast model for simple task
---

# Code Formatter

## When to Use This Skill

- **Fixing code style** - Format files to match ESLint/Prettier rules
- **Pre-commit checks** - Ensure code passes formatting before commit

## Quick Reference

```bash
# Format single file
pnpm format:fix apps/web/app/page.tsx

# Format all files
pnpm format:fix
```

## Common Patterns

### TypeScript/JavaScript
```bash
pnpm prettier --write "**/*.{ts,tsx,js,jsx}"
```

### SQL
```bash
pg_format --inplace apps/web/supabase/migrations/*.sql
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Prettier conflicts with ESLint | Competing rules | Check config alignment |

## Related Resources

- ESLint config: `apps/web/eslint.config.mjs`
```

**Token Count**: ~400 tokens
**Line Count**: ~50 lines
**Perfect for**: Simple, tool-based tasks

### Example 2: Progressive Disclosure Skill

**Use Case**: Complex API integration with multiple workflows

**SKILL.md** (Core - < 500 lines):
```yaml
---
name: api-integration-specialist
description: "Integrate third-party APIs with error handling, retry logic, rate limiting, and monitoring. Use when connecting to external APIs, handling API failures, or implementing webhooks."
version: "1.0.0"
last_updated: "2026-01-12"
---

# API Integration Specialist

## When to Use This Skill

- **Connecting to external APIs** - REST, GraphQL, webhooks
- **Handling API failures** - Retry logic, circuit breakers, fallbacks

## Quick Reference

```typescript
import { withRetry } from '@/lib/retry';

export async function fetchUserData(userId: string) {
  return withRetry(async () => {
    const response = await fetch(`https://api.example.com/users/${userId}`);
    if (!response.ok) throw new Error(`API error: ${response.status}`);
    return response.json();
  });
}
```

## Core Patterns

### REST API Integration

[Brief overview with core example]

See [EXAMPLES.md#rest-api](EXAMPLES.md#rest-api-integration) for complete implementations.

### GraphQL Integration

[Brief overview]

See [EXAMPLES.md#graphql](EXAMPLES.md#graphql-integration).

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues.

## Related Resources

- **[REFERENCE.md](REFERENCE.md)** - Complete API reference
- **[EXAMPLES.md](EXAMPLES.md)** - Detailed examples
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Debugging guide
```

**REFERENCE.md** (Loaded when needed):
```markdown
# API Integration Reference

## withRetry()

Retry failed API calls with exponential backoff.

**Signature:**
```typescript
function withRetry<T>(
  fn: () => Promise<T>,
  options?: RetryOptions
): Promise<T>
```

**Parameters:**
[Detailed parameter docs]

**Returns:**
[Return value documentation]

**Example:**
[Complete working example]
```

**Token Savings**: ~60% by loading reference only when needed

### Example 3: Skill with Utility Scripts

**Use Case**: Database migration validation

**Directory Structure:**
```
database-migration-manager/
├── SKILL.md
├── REFERENCE.md
└── scripts/
    ├── validate-migration.py
    └── test-migration.sh
```

**SKILL.md** (references scripts):
```markdown
## Validation

Run the validation script before committing:

```bash
python scripts/validate-migration.py apps/web/supabase/migrations/your-file.sql
```

**Checks performed:**
- Idempotency (IF NOT EXISTS/IF EXISTS)
- Naming conventions (YYYYMMDDHHMMSS_description.sql)
- RLS policy patterns (DO $$ blocks)
- Foreign key handling

**Expected output:**
```json
{
  "valid": true,
  "message": "Migration is valid and idempotent"
}
```
```

**scripts/validate-migration.py**:
```python
#!/usr/bin/env python3
import sys
import json

def validate_migration(file_path):
    issues = []
    with open(file_path) as f:
        content = f.read()

    # Check idempotency
    if 'CREATE POLICY' in content and 'DO $$' not in content:
        issues.append({
            'type': 'error',
            'message': 'CREATE POLICY must be wrapped in DO $$ block'
        })

    return issues

if __name__ == '__main__':
    issues = validate_migration(sys.argv[1])
    result = {'valid': len(issues) == 0}
    if issues:
        result['issues'] = issues
    print(json.dumps(result, indent=2))
    sys.exit(0 if result['valid'] else 1)
```

**Benefit**: Script executes without loading code into context (zero tokens)

---

## Quality Checklist

### Pre-Commit Checklist

Before committing any skill, verify:

**Content Quality**:
- [ ] Description includes 5+ specific trigger keywords
- [ ] Quick reference shows complete working example (80% use case)
- [ ] All code examples tested and work correctly
- [ ] Troubleshooting section included with real error messages
- [ ] Related skills/files documented and linked

**Structure**:
- [ ] SKILL.md under 500 lines (or uses progressive disclosure)
- [ ] YAML frontmatter is valid (no tabs, proper syntax)
- [ ] Version follows semantic versioning (MAJOR.MINOR.PATCH)
- [ ] CHANGELOG.md exists and is updated
- [ ] Last_updated is current date

**Technical**:
- [ ] Token usage < 5k tokens for SKILL.md (`python scripts/token-counter.py`)
- [ ] Scripts have execute permissions (`chmod +x scripts/*`)
- [ ] Scripts handle errors gracefully (proper exit codes)
- [ ] No deprecated APIs in examples
- [ ] Framework versions are current

**Discovery & Usability**:
- [ ] Discovery tested ("What Skills are available?")
- [ ] Trigger phrases tested with real user requests
- [ ] Examples use realistic data (not foo/bar)
- [ ] Prerequisites clearly stated
- [ ] Cross-references work (no broken links)

### Quarterly Audit Checklist

Run every 3 months for all skills:

**Automated Checks**:
- [ ] Run `python scripts/skill-audit.py` on all skills
- [ ] Check for framework version mismatches
- [ ] Scan for deprecated APIs (`grep -r "oldAPI" .claude/skills/`)
- [ ] Measure token usage for all skills

**Manual Review**:
- [ ] Test discovery with updated trigger phrases
- [ ] Verify all examples still execute correctly
- [ ] Check for outdated best practices
- [ ] Review user feedback and usage metrics
- [ ] Update skills based on new framework features

**Maintenance**:
- [ ] Update skills last modified > 6 months ago
- [ ] Archive skills with < 5% usage rate
- [ ] Merge skills with > 50% overlapping content
- [ ] Split skills > 500 lines without progressive disclosure

---

## Sources & References

### Claude Code Official Documentation
- [Agent Skills Documentation](https://code.claude.com/docs/en/skills)
- [Skill Authoring Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Equipping Agents for the Real World with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)

### Industry Research (2026)
- [Progressive Disclosure: 90s UX to 2026 AI](https://aipositive.substack.com/p/progressive-disclosure-matters)
- [Optimizing Token Efficiency in Claude Code](https://medium.com/@pierreyohann16/optimizing-token-efficiency-in-claude-code-workflows-managing-large-model-context-protocol-f41eafdab423)
- [Shared Skills, Shared Success: Claude Code Plugins](https://medium.com/@pekastel/shared-skills-shared-success-how-claude-code-plugins-embed-team-expertise-5012bc0ff232)

### AI Agent Frameworks
- [LangChain Autonomous Agents](https://blog.langchain.com/agents-round/)
- [Prompt Engineering for AI Agents](https://www.prompthub.us/blog/prompt-engineering-for-ai-agents)
- [AI Agent Evaluation: Metrics and Best Practices](https://wandb.ai/onlineinference/genai-research/reports/AI-agent-evaluation-Metrics-strategies-and-best-practices--VmlldzoxMjM0NjQzMQ)

### Token Optimization & Performance
- [Mastering AI Token Cost Optimization](https://10clouds.com/blog/a-i/mastering-ai-token-optimization-proven-strategies-to-cut-ai-cost/)
- [Optimizing Token Usage for AI Efficiency](https://sparkco.ai/blog/optimizing-token-usage-for-ai-efficiency-in-2025/)
- [Context Window Management Strategies](https://www.getmaxim.ai/articles/context-window-management-strategies-for-long-context-ai-agents-and-chatbots/)

---

**Last Updated**: 2026-01-12
**Version**: 1.0.0

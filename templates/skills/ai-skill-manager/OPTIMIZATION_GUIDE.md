# Skill Optimization Guide

Comprehensive guide for optimizing Claude Code skills for token efficiency, performance, and user experience.

## Table of Contents

1. [Token Efficiency](#token-efficiency)
2. [Progressive Disclosure](#progressive-disclosure)
3. [Content Strategy](#content-strategy)
4. [Performance Metrics](#performance-metrics)
5. [Optimization Workflows](#optimization-workflows)

---

## Token Efficiency

### Why Token Efficiency Matters

**Impact:**
- **Cost**: Higher token usage = higher API costs
- **Latency**: More tokens = slower processing
- **Context limits**: Large skills consume precious context window
- **User experience**: Faster responses, lower costs

**Target Metrics:**
- **Metadata**: ~100 tokens (name, description, basic info)
- **Full instructions**: < 5,000 tokens (complete skill content)
- **Progressive disclosure**: Load only what's needed when needed

### Token Counting

**Estimate Tokens:**
- **Rule of thumb**: 1 token ≈ 4 characters ≈ 0.75 words
- **English text**: ~750 tokens per 1,000 words
- **Code**: ~1 token per 3-4 characters (varies by language)

**Measure Exact Tokens:**

```bash
# Use the token counter script
python .claude/skills/ai-skill-manager/scripts/token-counter.py path/to/SKILL.md

# Output:
# File: SKILL.md
# Characters: 15,234
# Estimated tokens: 3,809
# Status: ✅ Under 5k token target
```

### Token Optimization Techniques

#### 1. Progressive Disclosure (95-98% Savings)

**Problem**: Loading entire 1,000+ line skill wastes tokens

**Solution**: Split into focused files, load only when needed

**Before** (monolithic):
```
flutter-development/
└── SKILL.md (1,620 lines, ~12k tokens)
```

**After** (progressive disclosure):
```
flutter-development/
├── SKILL.md (450 lines, ~3.5k tokens) ✅
├── REFERENCE.md (loaded only when needed)
├── EXAMPLES.md (loaded only when needed)
└── ADVANCED.md (loaded only when needed)
```

**Token Savings**: 12k → 3.5k = **71% reduction** on initial load

#### 2. Use Tables Over Prose

**Problem**: Verbose explanations consume tokens

**Solution**: Use tables for comparisons, options, references

**Before** (verbose):
```markdown
When you need to use authentication, you should use the withAuth wrapper.
However, if you need access to the user context, client, and accountId
parameters, then you should use withAuthParams instead. For operations that
require super admin privileges, you must use withSuperAdmin, which checks
the user's role before allowing the action to proceed.
```
**Tokens**: ~60

**After** (table):
```markdown
| Wrapper | Use When |
|---------|----------|
| withAuth | Authentication only |
| withAuthParams | Need user, client, accountId |
| withSuperAdmin | Super admin operations |
```
**Tokens**: ~30 (50% savings)

#### 3. Quick Reference Pattern

**Problem**: Users have to read entire skill to find basic usage

**Solution**: Put complete working example at the top

**Before**:
```markdown
# My Skill

This skill helps you do X. It's useful for Y. Here's some background...

[5 paragraphs of explanation]

## Usage

[Finally, the example]
```

**After**:
```markdown
# My Skill

## Quick Reference

```bash
# Complete working example
command --flag value input.txt
```

[Details below if needed]
```

**Benefit**: Users get answer immediately, may not need rest of skill

#### 4. Script-Based Execution (Zero-Context)

**Problem**: Including script code in SKILL.md wastes tokens

**Solution**: External scripts - only output consumes tokens

**Before** (inline):
```markdown
Here's a Python script to validate migrations:

```python
#!/usr/bin/env python3
import sys
import re

def validate_migration(file_path):
    with open(file_path) as f:
        content = f.read()

    # [50+ lines of script code]

    return issues

if __name__ == '__main__':
    # [More code]
```

Run with: `python validate.py migration.sql`
```
**Tokens**: ~500+ (script code loaded into context)

**After** (external script):
```markdown
Run the validation script:

```bash
python scripts/validate-migration.py migration.sql
```

The script checks for:
- Idempotency (IF NOT EXISTS/IF EXISTS)
- Naming conventions
- RLS policy patterns
```
**Tokens**: ~40 (only description, script executes without loading)

**Token Savings**: 500 → 40 = **92% reduction**

#### 5. Template Reuse

**Problem**: Repeating similar code patterns

**Solution**: External templates, reference instead of repeat

**Before**:
```markdown
## Pattern 1: Simple Migration

```sql
-- Migration: add_email_column.sql
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

## Pattern 2: Complex Migration

```sql
-- Migration: add_phone_column.sql
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'phone'
  ) THEN
    ALTER TABLE users ADD COLUMN phone TEXT;
  END IF;
END $$;
```

[More repetitive examples...]
```

**After**:
```markdown
## Pattern: Add Column

Use the template in `resources/templates/add-column-template.sql`:

```sql
-- Template structure (copy and modify)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = '{{TABLE}}' AND column_name = '{{COLUMN}}'
  ) THEN
    ALTER TABLE {{TABLE}} ADD COLUMN {{COLUMN}} {{TYPE}};
  END IF;
END $$;
```

Copy template and replace:
- `{{TABLE}}` → your table name
- `{{COLUMN}}` → your column name
- `{{TYPE}}` → column data type
```

**Benefit**: One example instead of many repetitive ones

#### 6. Cross-Reference Instead of Duplicate

**Problem**: Same information in multiple skills

**Solution**: Reference canonical source

**Before**:
```markdown
# skill-a/SKILL.md
## RLS Policy Pattern

CREATE POLICY "policy_name" ON table_name
  FOR SELECT
  USING (auth.uid() = user_id);

# skill-b/SKILL.md
## RLS Policy Pattern

CREATE POLICY "policy_name" ON table_name
  FOR SELECT
  USING (auth.uid() = user_id);
```

**After**:
```markdown
# skill-a/SKILL.md
## RLS Policies

See [`rls-policy-generator`](../rls-policy-generator/SKILL.md) for complete RLS patterns.

# skill-b/SKILL.md
## Security

Apply RLS policies using [`rls-policy-generator`](../rls-policy-generator/SKILL.md).
```

**Benefit**: Single source of truth, less duplication

---

## Progressive Disclosure

### What is Progressive Disclosure?

**Definition**: Loading information layer by layer, only what's needed when needed.

**Three-Tier Architecture:**

1. **Tier 1: Metadata** (loaded at startup for all skills)
   - Name, description, version
   - ~100 tokens per skill
   - Enables skill discovery

2. **Tier 2: Core Instructions** (loaded when skill invoked)
   - SKILL.md overview
   - Quick reference
   - Essential patterns
   - < 500 lines, < 5k tokens

3. **Tier 3: Detailed Resources** (loaded on demand)
   - REFERENCE.md (API docs)
   - EXAMPLES.md (comprehensive examples)
   - TROUBLESHOOTING.md (edge cases)
   - Only loaded when referenced

### When to Use Progressive Disclosure

**Indicators:**

- SKILL.md exceeds 500 lines
- Content naturally splits into overview vs. details
- Some sections rarely needed (advanced patterns, edge cases)
- Multiple distinct workflows

**File Organization:**

```
skill-name/
├── SKILL.md              # Tier 2: Core (< 500 lines)
│   ├── Quick Reference
│   ├── When to Use
│   ├── Core Workflow (80% use cases)
│   └── Links to detailed resources
├── REFERENCE.md          # Tier 3: Complete API reference
├── EXAMPLES.md           # Tier 3: Comprehensive examples
├── ADVANCED.md           # Tier 3: Advanced patterns
└── TROUBLESHOOTING.md    # Tier 3: Edge cases, debugging
```

### Progressive Disclosure Template

**SKILL.md** (Core - always loaded):

```markdown
---
name: skill-name
description: [...]
---

# Skill Name

## Quick Reference

[Complete minimal example - 80% use case]

## Core Workflow

### Step 1: [Most Common Action]
[Instructions with example]

### Step 2: [Next Common Action]
[Instructions with example]

## Common Patterns

### Pattern 1: [Frequent Use Case]
[Brief example]

### Pattern 2: [Second Most Common]
[Brief example]

## Additional Resources

For complete API documentation, see [REFERENCE.md](REFERENCE.md)

For detailed examples and edge cases, see [EXAMPLES.md](EXAMPLES.md)

For advanced patterns and optimization, see [ADVANCED.md](ADVANCED.md)

For troubleshooting and debugging, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
```

**REFERENCE.md** (Loaded only when user needs API details):

```markdown
# Skill Name - API Reference

Complete API documentation for all functions, parameters, and return values.

## Function: doSomething()

**Signature:**
```typescript
function doSomething(
  param1: string,
  options?: DoSomethingOptions
): Promise<Result>
```

**Parameters:**
- `param1` (string, required): Description
- `options` (object, optional): Configuration
  - `option1` (boolean, default: `false`): Description
  - `option2` (number, default: `10`): Description

**Returns:**
- `Promise<Result>`: Description
  - `success` (boolean): Whether operation succeeded
  - `data` (T): Result data if successful
  - `error` (Error): Error object if failed

**Throws:**
- `ValidationError`: If param1 is invalid
- `NetworkError`: If connection fails

**Example:**
```typescript
const result = await doSomething("input", { option1: true });
```

[More functions...]
```

**EXAMPLES.md** (Loaded only when user needs detailed examples):

```markdown
# Skill Name - Examples

Comprehensive examples for all use cases.

## Example 1: Basic Usage

**Scenario**: [Description]

**Setup:**
```bash
# Prerequisites
npm install package
```

**Code:**
```typescript
// Complete working example
[Full code with imports, setup, execution, error handling]
```

**Expected Output:**
```
[Output]
```

**Explanation:**
[Line-by-line breakdown if needed]

## Example 2: Advanced Usage

[Same detailed structure]

[More examples...]
```

**ADVANCED.md** (Loaded only when user explicitly asks for advanced patterns):

```markdown
# Skill Name - Advanced Patterns

Advanced use cases, optimization techniques, and edge cases.

## Pattern 1: Performance Optimization

[Detailed performance tuning]

## Pattern 2: Error Recovery

[Sophisticated error handling]

## Pattern 3: Custom Configuration

[Complex configuration scenarios]
```

**TROUBLESHOOTING.md** (Loaded only when user encounters issues):

```markdown
# Skill Name - Troubleshooting

Common issues, edge cases, and debugging workflows.

## Issue 1: [Problem]

**Symptom**: [What user sees]

**Cause**: [Root cause explanation]

**Diagnosis:**
```bash
# Commands to diagnose
```

**Solution:**
```typescript
// Code fix
```

**Prevention:**
[How to avoid in future]

[More issues...]
```

### Token Savings Calculation

**Example: `api-patterns` skill**

**Before** (monolithic):
- SKILL.md: 1,021 lines
- Estimated tokens: ~8,500

**After** (progressive disclosure):
- SKILL.md: 450 lines (~3,500 tokens) - Always loaded
- REFERENCE.md: 300 lines (~2,500 tokens) - Loaded when needed
- EXAMPLES.md: 200 lines (~1,700 tokens) - Loaded when needed
- TROUBLESHOOTING.md: 100 lines (~800 tokens) - Loaded when needed

**Token Savings**:
- Typical invocation (just needs core): 8,500 → 3,500 = **59% reduction**
- With reference: 8,500 → 6,000 = **29% reduction**
- All files loaded: 8,500 → 8,500 = 0% (but rare)

**Result**: Average savings of 40-60% per skill invocation

---

## Content Strategy

### Few-Shot Learning Patterns

**What**: Provide 3-5 complete examples showing desired behavior

**Why**: Claude learns patterns from examples, especially for complex tasks

**Template:**

```markdown
## Examples

### Example 1: [Common Case]

**Input**: [User request or data]
**Expected**: [Desired output or behavior]
**Code**:
```code
// Complete working example
[Full implementation]
```

### Example 2: [Edge Case]

**Input**: [Different scenario]
**Expected**: [Different output]
**Code**:
```code
// Alternative implementation
[Full code]
```

### Example 3: [Error Case]

**Input**: [Invalid input]
**Expected**: [Graceful error handling]
**Code**:
```code
// Error handling example
[Full code with try/catch, validation]
```
```

**Key Principles:**
- Show complete examples, not fragments
- Include input, expected output, and full code
- Cover common case, edge case, error case
- Use realistic data (not foo/bar)
- Demonstrate best practices in examples

### Anti-Pattern Documentation

**What**: Show what NOT to do alongside correct approach

**Why**: Prevents common mistakes, clarifies intent

**Template:**

```markdown
## Anti-Patterns

### ❌ Don't: [Bad Pattern Name]

```code
// BAD: Problematic code
[Example of anti-pattern]
```

**Why This is Bad:**
- Reason 1 (security, performance, maintainability)
- Reason 2
- Reason 3

### ✅ Do: [Correct Pattern Name]

```code
// GOOD: Recommended approach
[Correct implementation]
```

**Why This is Better:**
- Benefit 1
- Benefit 2
- Benefit 3
```

**Examples:**

```markdown
## Anti-Patterns

### ❌ Don't: Query Inside Loops (N+1 Problem)

```typescript
// BAD: N+1 queries
for (const event of events) {
  const host = await db.from('users').select().eq('id', event.host_id).single();
  // Process host...
}
```

**Why This is Bad:**
- Makes N+1 database queries (1 query per event)
- Extremely slow with large datasets
- Exhausts database connection pool

### ✅ Do: Batch Query Then Match In-Memory

```typescript
// GOOD: 2 queries total
const events = await db.from('events').select();
const host_ids = events.map(e => e.host_id);
const hosts = await db.from('users').select().in('id', host_ids);

// Match in-memory
const hostsMap = Object.fromEntries(hosts.map(h => [h.id, h]));
const eventsWithHosts = events.map(e => ({
  ...e,
  host: hostsMap[e.host_id]
}));
```

**Why This is Better:**
- Only 2 database queries total
- Scales to thousands of events
- Efficient connection pool usage
```

### Chain-of-Thought Prompting

**What**: Show step-by-step reasoning process

**Why**: Helps Claude understand complex workflows

**Template:**

```markdown
## Workflow: [Complex Task]

**Goal**: [What we're trying to achieve]

**Step-by-step reasoning:**

1. **Analyze the requirement**
   - What: [Description]
   - Why: [Reason]
   - How: [Approach]

2. **Choose the approach**
   - Option A: [Description] - ❌ Not ideal because [reason]
   - Option B: [Description] - ✅ Best choice because [reason]

3. **Implement the solution**
   ```code
   // Step 3: Implementation
   [Code]
   ```

4. **Verify the result**
   ```bash
   # Step 4: Verification
   [Commands]
   ```

5. **Handle edge cases**
   - Case 1: [Scenario] → [Solution]
   - Case 2: [Scenario] → [Solution]
```

**Example:**

```markdown
## Workflow: Zero-Downtime Column Rename

**Goal**: Rename `first_name` → `given_name` without downtime

**Step-by-step reasoning:**

1. **Analyze the requirement**
   - What: Column rename on production table
   - Why: Better naming convention alignment
   - Risk: Direct rename causes downtime (reads/writes fail during DDL)

2. **Choose the approach**
   - ❌ Simple ALTER TABLE RENAME: Locks table, causes downtime
   - ✅ Expand-contract pattern: Zero downtime, safe rollback

3. **Expand: Add new column** (Migration 1)
   ```sql
   ALTER TABLE users ADD COLUMN IF NOT EXISTS given_name TEXT;
   UPDATE users SET given_name = first_name WHERE given_name IS NULL;
   ```

4. **Dual-write: Update application** (Deploy 1)
   ```typescript
   // Write to both columns
   await db.from('users').update({
     first_name: value,  // old
     given_name: value   // new
   });
   ```

5. **Contract: Remove old column** (Migration 2, after deploy stable)
   ```sql
   ALTER TABLE users DROP COLUMN IF EXISTS first_name;
   ```
```

---

## Performance Metrics

### Measuring Skill Performance

**Key Performance Indicators:**

| Metric | Measurement | Target |
|--------|-------------|--------|
| **Token count** | `python scripts/token-counter.py` | < 5,000 tokens |
| **Line count** | `wc -l SKILL.md` | < 500 lines |
| **Load time** | Time from invocation to first instruction | < 2 seconds |
| **Discovery rate** | Manual testing with trigger phrases | > 90% |
| **Success rate** | Examples execute without errors | > 95% |

### Benchmarking

**Baseline Measurement:**

```bash
# Before optimization
python scripts/token-counter.py .claude/skills/skill-name/SKILL.md

# Output:
# File: SKILL.md
# Lines: 853
# Characters: 47,282
# Estimated tokens: 11,821
# Status: ⚠️  Exceeds 5k token target
```

**After Optimization:**

```bash
# Split with progressive disclosure
python scripts/token-counter.py .claude/skills/skill-name/SKILL.md

# Output:
# File: SKILL.md
# Lines: 442
# Characters: 22,103
# Estimated tokens: 5,526
# Status: ⚠️  Close to 5k token target (consider further optimization)

# Further optimization
python scripts/token-counter.py .claude/skills/skill-name/SKILL.md

# Output:
# File: SKILL.md
# Lines: 398
# Characters: 18,764
# Estimated tokens: 4,691
# Status: ✅ Under 5k token target
```

**Token Savings**: 11,821 → 4,691 = **60% reduction**

---

## Optimization Workflows

### Workflow 1: Optimize Oversized Skill

**Trigger**: `wc -l SKILL.md` shows > 500 lines

**Steps:**

1. **Audit current structure**:
   ```bash
   python scripts/skill-audit.py .claude/skills/skill-name/
   ```

2. **Identify split points**:
   - Core patterns (keep in SKILL.md)
   - API reference (move to REFERENCE.md)
   - Detailed examples (move to EXAMPLES.md)
   - Advanced patterns (move to ADVANCED.md)
   - Troubleshooting (move to TROUBLESHOOTING.md)

3. **Create supporting files**:
   ```bash
   # Extract sections to new files
   # SKILL.md retains only core content
   ```

4. **Update cross-references**:
   ```markdown
   ## Additional Resources
   - [REFERENCE.md](REFERENCE.md)
   - [EXAMPLES.md](EXAMPLES.md)
   ```

5. **Measure improvement**:
   ```bash
   python scripts/token-counter.py SKILL.md
   # Before: 11,821 tokens
   # After: 4,691 tokens
   # Savings: 60%
   ```

6. **Test discovery**:
   - Verify trigger phrases still work
   - Ensure quick reference covers 80% use cases
   - Test progressive loading of supporting files

### Workflow 2: Remove Token Bloat

**Trigger**: Token counter shows > 5k tokens for SKILL.md

**Steps:**

1. **Identify verbose sections**:
   ```bash
   # Find longest sections
   grep -n "^##" SKILL.md | \
     awk -F: '{print $1, $2}' | \
     while read line1 title; do
       line2=$(grep -n "^##" SKILL.md | awk -F: -v l=$((line1+1)) '$1>=l {print $1; exit}')
       echo "$((line2-line1)) lines: $title"
     done | sort -rn
   ```

2. **Apply optimization techniques**:
   - Convert prose to tables
   - Remove redundant explanations
   - Reference external docs instead of duplicating
   - Move examples to EXAMPLES.md
   - Extract templates to resources/

3. **Verify clarity maintained**:
   - Quick reference still complete
   - Core workflow still clear
   - No critical information lost

4. **Measure savings**:
   ```bash
   python scripts/token-counter.py SKILL.md
   ```

---

## Key Takeaways

1. **Progressive disclosure is powerful** - 95-98% token reduction for large skills
2. **Tables > Prose** - 50% more scannable, uses fewer tokens
3. **Scripts = Zero-context** - External scripts don't consume tokens
4. **Quick reference first** - Users get answer immediately
5. **Target < 5k tokens** - Keeps skills fast and efficient
6. **Measure everything** - Use token-counter.py to track improvements
7. **Few-shot learning** - 3-5 complete examples teach patterns
8. **Anti-patterns prevent mistakes** - Show what NOT to do

---

**Next**: See [BEST_PRACTICES.md](BEST_PRACTICES.md) for industry standards and examples library.

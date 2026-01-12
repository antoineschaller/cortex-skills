# Skill Manager

**Purpose:** Create, edit, validate, and manage Claude Code skills and skill collections.

**When to use:**
- Creating new skills from templates
- Editing existing skill files
- Validating skill structure and format
- Adding skills to marketplace.json
- Organizing skill collections

**Not for:**
- General code editing (use Edit tool)
- Plugin installation (use /plugin commands)
- Agent management (use separate agent-manager skill)

---

## Skill Structure

Claude Code skills follow this structure:

```
skills/collection-name/skill-name/
├── skill.md              # Main skill file (required)
├── examples/             # Usage examples (optional)
│   ├── example1.md
│   └── example2.md
└── README.md            # Documentation (optional)
```

### skill.md Format

```markdown
# Skill Name

**Purpose:** One-line description

**When to use:**
- Bullet points of use cases

**Not for:**
- When NOT to use this skill

---

## [Section 1: Context/Background]

Provide necessary context...

## [Section 2: Patterns/Examples]

Show code patterns...

## [Section 3: Guidelines]

Best practices and rules...

---

## Quick Reference

Key commands, checklists, or reference tables.
```

---

## Creating a New Skill

### Step 1: Choose Template (if applicable)

Available templates in `cortex-skills/templates/skills/`:
- `api-patterns` - API/server patterns
- `service-patterns` - Service layer patterns
- `test-patterns` - Testing patterns
- `ui-patterns` - UI component patterns
- `error-handling` - Error handling patterns
- `db-anti-patterns` - Database anti-patterns
- `rls-security` - Row-level security
- `auth-patterns` - Authentication patterns
- `data-management` - Data management patterns
- `flutter-patterns` - Flutter mobile patterns
- `flutter-testing` - Flutter testing patterns
- `mobile-cicd` - Mobile CI/CD patterns
- `logging-patterns` - Logging/observability
- `caching-patterns` - Caching strategies
- `background-jobs` - Queue/worker patterns
- `production-readiness` - Production patterns
- `cicd-patterns` - CI/CD patterns
- `i18n-patterns` - Internationalization
- `state-management` - State management

### Step 2: Create Skill Directory

```bash
# For project-specific skill
mkdir -p cortex-skills/skills/[collection]/[skill-name]

# For generic template
mkdir -p cortex-skills/templates/skills/[pattern-name]
```

### Step 3: Create skill.md

Use this template structure:

```markdown
# [Skill Name]

**Purpose:** [One-line description of what this skill does]

**When to use:**
- [Use case 1]
- [Use case 2]
- [Use case 3]

**Not for:**
- [When NOT to use this skill]
- [Alternative approaches]

---

## Context

[Background information needed to understand this skill]

## Patterns

[Code patterns, examples, or guidelines]

## Rules

[Critical rules or constraints]

---

## Quick Reference

[Checklists, commands, or reference tables]
```

### Step 4: Add Examples (Optional)

```bash
mkdir -p cortex-skills/skills/[collection]/[skill-name]/examples
```

Create example files showing usage:
- `example1.md` - Basic usage
- `example2.md` - Advanced usage
- `example3.md` - Edge cases

### Step 5: Update marketplace.json

Add skill to collection in `.claude-plugin/marketplace.json`:

```json
{
  "name": "collection-name",
  "skills": [
    "./existing-skill",
    "./new-skill-name"
  ]
}
```

---

## Editing Existing Skills

### Locate Skill File

```bash
# Find skill in project-specific collections
find cortex-skills/skills -name "skill.md" -path "*[skill-name]*"

# Find template
find cortex-skills/templates -name "skill.md" -path "*[pattern-name]*"
```

### Edit Guidelines

1. **Preserve structure:** Keep sections in order (Purpose → When/Not → Content → Quick Reference)
2. **Update examples:** Ensure code examples are current
3. **Maintain clarity:** Skills should be scannable in <2 minutes
4. **Add dates:** Note when significant updates are made
5. **Keep concise:** Remove outdated or redundant information

---

## Validating Skill Structure

### Required Elements

✅ **skill.md must have:**
- Title (# header)
- **Purpose:** section
- **When to use:** bullet list
- **Not for:** bullet list
- At least one content section
- Quick Reference section

### Quality Checks

```bash
# Check all required sections exist
grep -q "^# " skill.md && \
grep -q "\*\*Purpose:\*\*" skill.md && \
grep -q "\*\*When to use:\*\*" skill.md && \
grep -q "\*\*Not for:\*\*" skill.md && \
grep -q "## Quick Reference" skill.md && \
echo "✅ Structure valid" || echo "❌ Missing required sections"

# Check file size (skills should be concise)
wc -l skill.md  # Aim for <300 lines

# Validate markdown syntax
npx markdownlint-cli2 skill.md
```

---

## Managing Skill Collections

### Creating a New Collection

1. **Create directory:**
```bash
mkdir -p cortex-skills/skills/[collection-name]
```

2. **Add to marketplace.json:**
```json
{
  "plugins": [
    {
      "name": "collection-name-skills",
      "description": "Brief description of collection",
      "version": "1.0.0",
      "author": {
        "name": "Your Name"
      },
      "source": "./skills/collection-name",
      "category": "development|analytics|business|content",
      "skills": []
    }
  ]
}
```

3. **Create README:**
```bash
cat > cortex-skills/skills/[collection-name]/README.md << 'EOF'
# [Collection Name] Skills

Brief description of this skill collection.

## Skills

- **skill-1** - Description
- **skill-2** - Description

## Installation

\`\`\`bash
/plugin install collection-name-skills@cortex-skills
\`\`\`
EOF
```

### Organizing Collections

**By domain:**
- `shopify-skills` - Shopify-specific
- `supabase-skills` - Supabase database
- `analytics-skills` - Analytics & tracking

**By project:**
- `ballee-skills` - Ballee dance production
- `myarmy-skills` - MyArmy e-commerce

**By pattern:**
- Keep generic patterns in `templates/skills/`
- Keep project-specific in `skills/[project]/`

---

## Common Operations

### Clone Template to New Skill

```bash
# Copy template
cp -r cortex-skills/templates/skills/api-patterns \
      cortex-skills/skills/myarmy/api-patterns

# Customize for project
# Edit skill.md to add project-specific patterns
```

### Move Skill Between Collections

```bash
# Move skill directory
mv cortex-skills/skills/old-collection/skill-name \
   cortex-skills/skills/new-collection/skill-name

# Update old collection marketplace.json (remove skill)
# Update new collection marketplace.json (add skill)
```

### Archive Outdated Skill

```bash
# Move to archive directory
mkdir -p cortex-skills/archive
mv cortex-skills/skills/collection/outdated-skill \
   cortex-skills/archive/

# Remove from marketplace.json
# Add note in collection README about deprecation
```

---

## Skill Naming Conventions

### Skill Names
- Use **kebab-case**: `database-migration-manager`
- Be descriptive: `flutter-testing` not just `testing`
- Include scope: `mobile-cicd` not just `cicd`

### Collection Names
- End with `-skills`: `shopify-skills`
- Use singular project name: `ballee-skills` not `ballees-skills`

### File Names
- Main file: Always `skill.md`
- Examples: `example1.md`, `example2.md`, etc.
- README: Always `README.md`

---

## Testing Skills

### Manual Testing

1. **Install locally:**
```bash
/plugin marketplace add file:///path/to/cortex-skills
/plugin install collection-name@cortex-skills
```

2. **Invoke skill:**
```bash
/skill-name
```

3. **Verify behavior:**
- Skill loads without errors
- Instructions are clear
- Examples work as expected
- Quick reference is helpful

### Validation Script

```bash
#!/usr/bin/env bash
# validate-skill.sh

SKILL_PATH=$1

echo "Validating $SKILL_PATH..."

# Check required files
[[ -f "$SKILL_PATH/skill.md" ]] || { echo "❌ Missing skill.md"; exit 1; }

# Check required sections
grep -q "^# " "$SKILL_PATH/skill.md" || { echo "❌ Missing title"; exit 1; }
grep -q "\*\*Purpose:\*\*" "$SKILL_PATH/skill.md" || { echo "❌ Missing Purpose"; exit 1; }
grep -q "\*\*When to use:\*\*" "$SKILL_PATH/skill.md" || { echo "❌ Missing When to use"; exit 1; }
grep -q "\*\*Not for:\*\*" "$SKILL_PATH/skill.md" || { echo "❌ Missing Not for"; exit 1; }

# Check markdown syntax
npx markdownlint-cli2 "$SKILL_PATH/skill.md" 2>/dev/null || echo "⚠️  Markdown linting issues"

# Check file size
LINES=$(wc -l < "$SKILL_PATH/skill.md")
[[ $LINES -lt 500 ]] || echo "⚠️  Skill is long ($LINES lines) - consider splitting"

echo "✅ Skill structure valid"
```

---

## Quick Reference

### Create New Skill
```bash
mkdir -p cortex-skills/skills/[collection]/[skill-name]
# Create skill.md with template structure
# Update marketplace.json
```

### Edit Skill
```bash
# Find skill
find cortex-skills -name "skill.md" -path "*[skill-name]*"
# Edit with Read + Edit tools
```

### Validate Skill
```bash
# Check structure
grep "**Purpose:**" skill.md
grep "**When to use:**" skill.md
grep "**Not for:**" skill.md
grep "## Quick Reference" skill.md

# Check size
wc -l skill.md
```

### Add to Collection
```bash
# Edit marketplace.json
# Add "./skill-name" to skills array
```

### Test Skill
```bash
/plugin marketplace add file:///path/to/cortex-skills
/plugin install collection-name@cortex-skills
/skill-name
```

---

## Best Practices

1. **Keep skills focused:** One skill = one specific task or pattern
2. **Use examples:** Show don't tell - include code examples
3. **Quick reference:** Always include a scannable quick reference section
4. **Test before commit:** Install and test locally before pushing
5. **Document changes:** Note significant updates in git commits
6. **Link related skills:** Reference related skills in "See also" sections
7. **Update regularly:** Review and update skills quarterly
8. **Archive outdated:** Don't leave deprecated skills active

---

## Troubleshooting

### Skill not showing in /plugin list
- Check marketplace.json syntax (valid JSON)
- Verify skill path in "skills" array
- Ensure skill.md exists in directory

### Skill loads but instructions unclear
- Add more examples
- Simplify language
- Break into smaller sections
- Add visual diagrams if helpful

### Skill conflicts with existing skill
- Rename skill to be more specific
- Update "Not for" section to clarify scope
- Consider merging related skills

### Skill too long or complex
- Split into multiple skills
- Move detailed examples to separate files
- Keep skill.md focused on essentials
- Link to external documentation for deep dives

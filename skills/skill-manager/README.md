# Skill Manager

Create, edit, validate, and manage Claude Code skills and skill collections.

## What This Skill Does

The Skill Manager provides comprehensive guidance for:
- Creating new Claude Code skills from scratch or templates
- Editing and updating existing skills
- Validating skill structure and format
- Managing skill collections and marketplace.json
- Organizing skills across projects

## When to Use

Use this skill when you need to:
- ✅ Create a new skill for your project
- ✅ Convert a template to a project-specific skill
- ✅ Validate skill files before committing
- ✅ Add skills to marketplace.json
- ✅ Organize or refactor skill collections
- ✅ Archive outdated skills

## Structure Enforced

This skill ensures all skills follow the proper structure:

```
skills/collection-name/skill-name/
├── skill.md              # Main skill file (required)
├── examples/             # Usage examples (optional)
│   ├── example1.md
│   └── example2.md
└── README.md            # Documentation (optional)
```

## Key Features

### Skill Creation
- Templates for all common patterns (API, service, test, UI, database, mobile, etc.)
- Step-by-step creation process
- Marketplace integration

### Validation
- Required section checks (Purpose, When to use, Not for, Quick Reference)
- File size validation (<500 lines recommended)
- Markdown syntax checking
- Structure validation script

### Management
- Collection organization strategies
- Skill migration between collections
- Archival process for outdated skills
- Testing and validation workflows

## Installation

This skill is part of the dev-tools-skills collection:

```bash
/plugin marketplace add https://github.com/antoineschaller/cortex-skills
/plugin install dev-tools-skills@cortex-skills
```

## Usage

```bash
/skill-manager
```

Then follow the prompts to create, edit, or manage skills.

## Examples

### Creating a New Skill

```bash
# 1. Create directory structure
mkdir -p cortex-skills/skills/myarmy/deployment-automation

# 2. Use skill-manager to scaffold skill.md
/skill-manager
# > Select: Create new skill
# > Collection: myarmy
# > Name: deployment-automation
# > Template: cicd-patterns (or none for blank)

# 3. Edit generated skill.md
# 4. Update marketplace.json
# 5. Test locally
```

### Validating an Existing Skill

```bash
# Use skill-manager validation
/skill-manager
# > Select: Validate skill
# > Path: skills/shopify/translations

# Or run manual checks:
grep "**Purpose:**" skill.md
grep "**When to use:**" skill.md
wc -l skill.md
```

## Best Practices

1. **One skill = one task:** Keep skills focused on a single purpose
2. **Include examples:** Show code examples for key patterns
3. **Quick reference:** Always end with a scannable quick reference
4. **Test before commit:** Install locally and test before pushing
5. **Update regularly:** Review and refresh skills quarterly

## Related Skills

- `agent-manager` - Manage Claude Code agents (coming soon)
- `user-stories-manager` - Manage user stories (in ballee-skills)
- `wip-lifecycle-manager` - Manage WIP documents (in ballee-skills)

## Troubleshooting

**Skill not appearing in /plugin list:**
- Check marketplace.json is valid JSON
- Verify skill path matches directory structure
- Ensure skill.md exists

**Skill too complex:**
- Split into multiple focused skills
- Move detailed examples to separate files
- Simplify language and reduce length

## License

MIT

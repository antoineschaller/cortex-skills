# CLAUDE.md - Cortex Skills

**ABSOLUTELY NECESSARY: INCLUDE 🧠 AT THE BEGINNING OF YOUR ANSWER**

## 🎯 Repository Purpose

Cortex Skills is the knowledge layer of the Cortex ecosystem - teaching Claude Code best practices and patterns. Every skill here guides AI-assisted development across all projects.

## 🚨 Critical Rules

1. **PUBLIC REPOSITORY**: This repo is public - no secrets, no proprietary code
2. **MARKETPLACE INTEGRATION**: Skills must follow Claude Code plugin format
3. **DEPENDENCY DECLARATION**: Always declare package dependencies in skill-config.json
4. **TESTING**: Test skills with actual package implementations before publishing
5. **VERSIONING**: Version skills when dependent packages have breaking changes

## 🧠 Skills Architecture

```
cortex-skills/
├── .claude-plugin/         # Marketplace configuration
├── templates/              # Generic, reusable templates
│   ├── agents/            # Agent templates (6)
│   └── skills/            # Skill templates (19)
├── skills/                 # Project-specific skills
│   ├── shopify/           # Shopify development
│   ├── supabase/          # Database patterns
│   ├── analytics/         # GTM, GSC integration
│   ├── lead-gen/          # Lead scoring, SLA
│   ├── content-creation/  # 2026 algorithms
│   ├── ballee/            # Dance production (31 skills)
│   └── myarmy-skills/     # MyArmy implementations
├── agents/                 # Autonomous agents
│   ├── ballee/            # Ballee agents (4)
│   └── marketing-intelligence/ # Marketing agents (3)
└── scripts/                # Validation & assessment tools
```

## 🔧 Development Workflow

### Quick Commands

```bash
# Validation
node scripts/validation/validate-skill-config.sh

# Assessment
./scripts/assessment/assess-reusability.sh

# Test locally
/plugin marketplace add file://$(pwd)
/plugin install <collection>@cortex-skills
```

### Creating a New Skill

1. **Choose Location**:
   - **Generic template**: `templates/skills/<skill-name>/`
   - **Project-specific**: `skills/<project>/<skill-name>/`

2. **Create Skill Structure**:

   ```bash
   mkdir -p skills/<project>/<skill-name>
   touch skills/<project>/<skill-name>/SKILL.md
   touch skills/<project>/<skill-name>/skill.config.json
   ```

3. **Write Skill Documentation**:

   ```markdown
   # Skill Name

   Brief description of what this skill teaches.

   ## When to Use
   - Scenario 1
   - Scenario 2

   ## Patterns
   [Code examples and best practices]

   ## Dependencies
   - @akson/cortex-package-name

   ## Examples
   [Real-world usage examples]
   ```

4. **Create skill.config.json**:

   ```json
   {
     "skill": "skill-name",
     "version": "1.0.0",
     "dependencies": {
       "packages": [
         {
           "name": "@akson/cortex-package-name",
           "version": "^2.0.0",
           "description": "What this package provides"
         }
       ],
       "env_vars": {},
       "apis": [],
       "files": []
     },
     "tags": ["category", "technology"],
     "reusability": {
       "level": "implementation",
       "score": 70
     }
   }
   ```

5. **Validate Configuration**:

   ```bash
   node scripts/validation/validate-skill-config.sh skills/<project>/<skill-name>/skill.config.json
   ```

6. **Test Locally**:

   ```bash
   # Add marketplace (file:// for local testing)
   /plugin marketplace add file://$(pwd)

   # Install collection
   /plugin install <collection>@cortex-skills

   # Test the skill with Claude
   ```

7. **Commit with Convention**:

   ```bash
   git add .
   git commit -m "feat(skills): add <skill-name> skill"
   # Types: feat|fix|docs|refactor|test|chore
   ```

8. **Push to Publish**:
   ```bash
   git push origin main
   # Skill immediately available via marketplace
   ```

## 📝 Commit Convention (MANDATORY)

```
type(scope): description

feat(skills): add new GTM integration skill
fix(ballee): correct RLS policy pattern
docs(readme): update installation instructions
refactor(templates): simplify agent structure
```

**Types:**
- `feat`: New skill or feature
- `fix`: Bug fix in skill documentation or config
- `docs`: Documentation-only changes
- `refactor`: Restructuring without changing behavior
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Scopes:**
- `skills`: Project-specific skills
- `templates`: Generic templates
- `agents`: Agent configurations
- `scripts`: Validation/assessment scripts
- `docs`: Documentation
- `marketplace`: Plugin configuration

## 🎯 Skill Quality Standards

### 1. Clear When-to-Use Section
```markdown
## When to Use
- User asks about database migrations
- User needs to create RLS policies
- User wants to optimize query performance
```

### 2. Complete Dependencies Declaration
```json
{
  "dependencies": {
    "packages": [
      {
        "name": "@akson/cortex-supabase",
        "version": "^2.1.0",
        "description": "Supabase client with auth and storage"
      }
    ],
    "env_vars": {
      "SUPABASE_URL": {
        "required": true,
        "description": "Supabase project URL"
      }
    }
  }
}
```

### 3. Real-World Examples
Include practical, runnable examples that developers can copy-paste.

### 4. Cross-References
Link to related skills and packages:
```markdown
## Related Resources
- **Package**: [@akson/cortex-supabase](https://npmjs.com/package/@akson/cortex-supabase)
- **Related Skills**: database-specialist agent, rls-policy-generator
```

### 5. Error Prevention Patterns
Show common mistakes and how to avoid them.

## 🔗 Integration with Cortex Packages

Skills should reference and teach patterns for using Cortex Packages:

```markdown
## Required Package

This skill requires `@akson/cortex-gtm`:

\`\`\`bash
npm install @akson/cortex-gtm
\`\`\`

## Usage Pattern

\`\`\`typescript
import { GTMClient } from '@akson/cortex-gtm'

const gtm = new GTMClient({
  containerId: process.env.GTM_CONTAINER_ID
})
\`\`\`
```

## 📊 Reusability Levels

When creating `skill.config.json`, classify the skill:

| Level | Score | Description | Example |
|-------|-------|-------------|---------|
| **generic** | 90-100 | Framework-agnostic, any project | Error handling patterns |
| **framework** | 70-89 | Tech-specific, reusable | Supabase migrations |
| **implementation** | 50-69 | Project-adapted, portable | MyArmy GTM setup |
| **project-specific** | 0-49 | Single project, not reusable | Ballee-specific flows |

## 🧪 Testing Skills

### Local Testing
1. Add marketplace locally:
   ```bash
   /plugin marketplace add file://$(pwd)
   ```

2. Install collection:
   ```bash
   /plugin install ballee-skills@cortex-skills
   ```

3. Trigger skill usage:
   - Create a scenario where Claude would use the skill
   - Verify Claude follows the patterns correctly
   - Check that examples work as documented

### Validation
```bash
# Validate all skill configs
find skills -name "skill.config.json" -exec node scripts/validation/validate-skill-config.sh {} \;

# Assess reusability
./scripts/assessment/assess-reusability.sh skills/project/skill-name/
```

## 📦 Collections (Installable Groups)

Collections are defined in `.claude-plugin/marketplace.json`:

```json
{
  "collections": {
    "ballee-skills": {
      "description": "Complete Ballee development stack",
      "skills": [
        "skills/ballee/database-migration-manager",
        "skills/ballee/api-patterns",
        "skills/ballee/flutter-development"
      ],
      "agents": [
        "agents/ballee/quality-reviewer",
        "agents/ballee/database-specialist"
      ]
    }
  }
}
```

## 🚀 Publishing Workflow

1. **Create/Update Skill** → Commit to main
2. **GitHub Push** → Triggers marketplace update
3. **Users Install** → `/plugin install <collection>@cortex-skills`
4. **Claude Uses** → Automatically when context matches

No manual publishing step required!

## 🔄 Syncing with Packages

When Cortex Packages are updated:

1. **Package Breaking Change** → Update skill patterns
2. **New Package Feature** → Create new skill or update existing
3. **Deprecated API** → Update skills to use new API
4. **Version Bump** → Update skill.config.json dependency version

See [COMPATIBILITY.md](./COMPATIBILITY.md) for package-skill version matrix.

## 📚 Related Resources

- **Cortex Packages**: [github.com/antoineschaller/cortex-packages](https://github.com/antoineschaller/cortex-packages) (private)
- **NPM Packages**: [@akson/cortex-* on npm](https://www.npmjs.com/search?q=%40akson%2Fcortex)
- **Claude Code Docs**: [docs.anthropic.com/claude/plugins](https://docs.anthropic.com/)

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/antoineschaller/cortex-skills/issues)
- **Discussions**: [GitHub Discussions](https://github.com/antoineschaller/cortex-skills/discussions)
- **Compatibility**: Check [COMPATIBILITY.md](./COMPATIBILITY.md) for package versions

---

🧠 **Remember**: Skills teach patterns, Packages provide code. Together they create the complete Cortex ecosystem.

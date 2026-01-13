# Skill Organization in Cortex-Skills

This document explains how skills are organized in the cortex-skills repository and provides guidelines for classifying new skills.

## Directory Structure

```
cortex-skills/
├── templates/skills/          # General-purpose, reusable skills
│   ├── database-migration-manager/
│   ├── flutter-development/
│   ├── rls-policy-generator/
│   └── ...
├── skills/ballee/            # Ballee-specific skills
│   ├── fever-sync-specialist/
│   ├── meteor-sync-specialist/
│   └── ...
├── skills/myarmy-skills/     # MyArmy-specific skills
├── skills/shopify/           # Shopify-specific skills
└── ...
```

## Skill Classification

### General-Purpose Skills (templates/skills/)

Skills that can be used across **any project** without modification. These are technology-specific but project-agnostic.

**Criteria:**
- No hardcoded project-specific values (database names, API endpoints, etc.)
- Applicable to any project using the same technology stack
- Focus on patterns, best practices, and workflows
- Can be used as templates for new projects

**Examples:**

#### Database & Supabase
- `database-migration-manager` - General Supabase migration patterns
- `rls-policy-generator` - General RLS policy generation for Supabase
- `db-performance-patterns` - General database performance optimization
- `supabase-realtime-specialist` - General Supabase Realtime patterns
- `supabase-email-templates` - General Supabase Auth email templates

#### Flutter Development
- `flutter-development` - Comprehensive Flutter patterns
- `flutter-accessibility` - Flutter accessibility (WCAG)
- `flutter-animations` - Flutter animation patterns
- `flutter-api-patterns` - Flutter API integration
- `flutter-code-quality` - Flutter code quality tooling
- `flutter-forms` - Flutter form patterns
- `flutter-offline` - Flutter offline-first patterns
- `flutter-performance` - Flutter performance optimization
- `flutter-query-testing` - Flutter + Supabase query testing
- `flutter-theming` - Flutter Material 3 theming
- `flutter-ui-components` - Flutter UI component patterns

#### CI/CD & DevOps
- `xcode-cloud-cicd` - Xcode Cloud CI/CD for iOS
- `codemagic-flutter-cicd` - Codemagic CI/CD for Flutter
- `cicd-pipeline` - GitHub Actions, Lefthook patterns

#### Code Quality & Performance
- `code-quality-tools` - Code quality automation
- `web-performance-metrics` - Core Web Vitals optimization

#### SEO (Next.js)
- `nextjs-seo-metadata` - Next.js SEO metadata
- `og-image-generation` - OG image generation (@vercel/og)
- `open-graph-twitter` - Open Graph & Twitter Cards
- `sitemap-canonical-seo` - Sitemaps & canonical URLs
- `structured-data-jsonld` - JSON-LD structured data
- `seo-testing` - SEO testing patterns

#### Error Monitoring & Testing
- `sentry-error-manager` - Sentry error management
- `visual-testing` - Visual regression testing (Puppeteer)

#### Project Management
- `user-stories-manager` - User story management
- `wip-lifecycle-manager` - WIP document lifecycle
- `ai-skill-manager` - Claude Code skill management

### Project-Specific Skills (skills/{project}/)

Skills that are tightly coupled to a **specific project's** business logic, integrations, or infrastructure.

**Criteria:**
- Contains hardcoded project-specific values
- Integrates with project-specific third-party services
- Uses project-specific database schemas or APIs
- Not reusable without significant modification

**Examples (skills/ballee/):**

#### Ballee-Specific Integrations
- `fever-sync-specialist` - Fever Partners API integration
- `tipalti-integration-specialist` - Tipalti payment processing
- `airtable-sync-specialist` - Airtable sync integration
- `meteor-sync-specialist` - MongoDB → Supabase migration from legacy Meteor app
- `bulk-support-message` - Ballee Support chat messaging

#### Ballee-Specific Development Tools
- `production-database-query` - Query Ballee Supabase with RLS context
- `mongodb-production-query` - Query Ballee production MongoDB
- `db-lint-manager` - Lint Ballee database functions against schema
- `flutter-query-lint` - Lint Flutter queries against Ballee schema
- `dev-environment-manager` - Manage Ballee local dev environment
- `document-patterns` - Document & PDF patterns using @kit/documents
- `i18n-translation-guide` - Ballee i18n implementation
- `mobile-deployment` - Ballee mobile app deployment
- `seo-validation-testing` - SEO validation for Ballee pages

## Classification Decision Tree

Use this flowchart to classify new skills:

```
Does the skill contain hardcoded project-specific values?
├─ YES → Project-Specific (skills/{project}/)
└─ NO
   └─ Can it be used in other projects without modification?
      ├─ YES → General-Purpose (templates/skills/)
      └─ NO → Project-Specific (skills/{project}/)
```

## Reorganization History

**January 13, 2026** - Major reorganization:
- Moved 32 general-purpose skills from `skills/ballee/` to `templates/skills/`
- Resolved 8 duplicate skills (kept template versions)
- Created `scripts/reorganize-ballee-skills.sh` for automation
- Documented classification criteria in this file

Skills moved:
- **Database/Supabase (5):** database-migration-manager, rls-policy-generator, db-performance-patterns, supabase-realtime-specialist, supabase-email-templates
- **Flutter (11):** flutter-development, flutter-accessibility, flutter-animations, flutter-api-patterns, flutter-code-quality, flutter-forms, flutter-offline, flutter-performance, flutter-query-testing, flutter-theming, flutter-ui-components
- **CI/CD (3):** xcode-cloud-cicd, codemagic-flutter-cicd, cicd-pipeline
- **SEO (5):** nextjs-seo-metadata, og-image-generation, open-graph-twitter, sitemap-canonical-seo, structured-data-jsonld, seo-testing
- **Code Quality (2):** code-quality-tools, web-performance-metrics
- **Error Monitoring (1):** sentry-error-manager
- **Testing (1):** visual-testing
- **Project Management (3):** user-stories-manager, wip-lifecycle-manager, ai-skill-manager

Skills remaining in `skills/ballee/` (14 Ballee-specific):
- airtable-sync-specialist, bulk-support-message, db-lint-manager, dev-environment-manager, document-patterns, fever-sync-specialist, flutter-query-lint, i18n-translation-guide, meteor-sync-specialist, mobile-deployment, mongodb-production-query, production-database-query, seo-validation-testing, tipalti-integration-specialist

## Best Practices

### When Creating New Skills

1. **Start with Classification**
   - Determine if the skill is general-purpose or project-specific
   - Choose the appropriate directory upfront

2. **Avoid Hardcoding**
   - Use environment variables for project-specific values
   - Use configuration files when possible
   - Document required configuration clearly

3. **Write for Reusability**
   - General-purpose skills should work out-of-the-box
   - Include comprehensive examples
   - Document assumptions and prerequisites

4. **Version Your Skills**
   - Use semantic versioning (MAJOR.MINOR.PATCH)
   - Update CHANGELOG.md for significant changes
   - Bump version when reorganizing or updating

### When Updating Existing Skills

1. **Review Classification**
   - If a project-specific skill becomes generic, move it to templates/
   - If a general-purpose skill becomes project-specific, move it to skills/{project}/

2. **Update Cross-References**
   - Check for references in other skills
   - Update sync configuration if needed
   - Document breaking changes

3. **Test in Multiple Contexts**
   - General-purpose skills should work across projects
   - Test with different configurations
   - Verify examples still work

## Sync Configuration

The sync scripts in `.claude/skills/ai-skill-manager/scripts/` automatically classify skills based on content analysis. To override classification:

```bash
# Force classification as template (general-purpose)
python scripts/sync-push.py my-skill --as-template

# Force classification as project-specific
python scripts/sync-push.py my-skill --as-project
```

See `scripts/README.md` for detailed sync documentation.

## Migration Guide

If you need to migrate a skill from one category to another:

### Moving Project-Specific → General-Purpose

1. **Remove hardcoded values**
   - Replace with environment variables
   - Use configuration files
   - Document required setup

2. **Update documentation**
   - Remove project-specific references
   - Add generic examples
   - Update skill description

3. **Move the skill**
   ```bash
   cd cortex-skills
   git mv skills/project/my-skill templates/skills/my-skill
   git commit -m "refactor(skills): make my-skill general-purpose"
   ```

4. **Update references**
   - Check other skills for references
   - Update sync configuration
   - Test in multiple projects

### Moving General-Purpose → Project-Specific

1. **Add project context**
   - Include project-specific documentation
   - Add hardcoded values where appropriate
   - Update examples with real project data

2. **Move the skill**
   ```bash
   cd cortex-skills
   git mv templates/skills/my-skill skills/project/my-skill
   git commit -m "refactor(skills): make my-skill project-specific for {project}"
   ```

3. **Update references**
   - Update skill description
   - Update sync configuration
   - Document project dependencies

## Maintenance

Regular maintenance tasks:

1. **Quarterly Review** - Review skill classifications
2. **Duplicate Detection** - Check for duplicate skills across categories
3. **Deprecation** - Archive unused skills to `skills/_archived/`
4. **Version Audits** - Ensure all skills have proper versioning

## Questions?

For questions about skill organization:
1. Review this document
2. Check existing skills in templates/ for examples
3. Refer to `scripts/reorganize-ballee-skills.sh` for automation
4. See `.claude/skills/ai-skill-manager/SKILL.md` for skill management patterns

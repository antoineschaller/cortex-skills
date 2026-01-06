# Cortex Skills

Reusable Claude Code skills for e-commerce, analytics, development, and project-specific workflows.

## Installation

### 1. Add the Marketplace

```bash
/plugin marketplace add https://github.com/antoineschaller/cortex-skills
```

### 2. Install Skill Collections

Install only the collections you need:

```bash
# Shopify development
/plugin install shopify-skills@cortex-skills

# Supabase database
/plugin install supabase-skills@cortex-skills

# Analytics & tracking
/plugin install analytics-skills@cortex-skills

# Lead generation
/plugin install lead-gen-skills@cortex-skills

# Ballee (dance production management)
/plugin install ballee-skills@cortex-skills
```

## Available Collections

### shopify-skills
Shopify development: translations, Liquid patterns, theme development.

| Skill | Description |
|-------|-------------|
| translations | Multi-language translation management (FR→DE/IT/EN) |
| liquid-patterns | Common Liquid code patterns |
| theme-dev | Theme development workflows |

### supabase-skills
Supabase database: migrations, RLS policies, patterns.

| Skill | Description |
|-------|-------------|
| migrations | Create and manage database migrations |
| rls-policies | Row Level Security implementation |

### analytics-skills
Analytics: GTM, GSC, conversion tracking.

| Skill | Description |
|-------|-------------|
| gtm-management | Google Tag Manager operations |
| gsc-analysis | Google Search Console analysis |

### lead-gen-skills
Lead generation: scoring, SLA tracking, funnel optimization.

| Skill | Description |
|-------|-------------|
| lead-scoring | Progressive lead scoring system |
| sla-tracking | Lead response SLA monitoring |

### ballee-skills
Ballee dance production management: database, Flutter mobile, web patterns, integrations.

**Database (7 skills)**
| Skill | Description |
|-------|-------------|
| database-migration-manager | Production-ready Supabase migrations |
| rls-policy-generator | Row Level Security policies with super admin bypass |
| production-database-query | Query production/staging databases safely |
| db-performance-patterns | Optimize queries, prevent connection pool exhaustion |
| db-anti-patterns | Detection rules for N+1, sequential queries |
| db-lint-manager | Lint PostgreSQL functions against schema |
| mongodb-production-query | Query Meteor MongoDB for migration/debugging |

**Web Patterns (6 skills)**
| Skill | Description |
|-------|-------------|
| api-patterns | Server actions with auth wrappers, Zod validation |
| service-patterns | Service layer with Result types, mappers |
| ui-patterns | MakerKit @kit/ui components, React Server Components |
| test-patterns | Vitest E2E tests with RLS validation |
| i18n-translation-guide | Internationalization with react-i18next |
| document-patterns | Document/PDF handling with @kit/documents |

**Mobile/Flutter (4 skills)**
| Skill | Description |
|-------|-------------|
| flutter-development | Architecture, Riverpod 3.x, Supabase, navigation |
| flutter-testing | Unit, widget, golden, integration tests |
| flutter-query-lint | Lint Supabase queries against schema |
| xcode-cloud-cicd | Xcode Cloud CI/CD, TestFlight, App Store |

**Infrastructure (4 skills)**
| Skill | Description |
|-------|-------------|
| cicd-pipeline | GitHub Actions, Lefthook, Dependabot |
| dev-environment-manager | Local dev, DB resets, prod data sync |
| sentry-error-manager | Fetch, analyze, resolve production errors |
| visual-testing | Puppeteer screenshots for UI verification |

**Integrations (5 skills)**
| Skill | Description |
|-------|-------------|
| airtable-sync-specialist | Airtable sync, cache, duplicate prevention |
| meteor-sync-specialist | Sync Meteor MongoDB to Supabase |
| supabase-realtime-specialist | Real-time subscriptions and presence |
| supabase-email-templates | Deploy Supabase Auth email templates |
| tipalti-integration-specialist | Tipalti payment integration |

**Workflow (4 skills)**
| Skill | Description |
|-------|-------------|
| code-quality-tools | Automated lint, type, format fixes |
| user-stories-manager | Create, track, validate user stories |
| wip-lifecycle-manager | WIP document lifecycle management |
| bulk-support-message | Send bulk messages via Ballee Support chat |

## Usage

Once installed, skills automatically activate when Claude detects relevant context:

- **"Help me translate the Shopify content"** → shopify-translations skill
- **"Create a migration to add a users table"** → supabase-migrations skill
- **"Set up GTM conversion tracking"** → gtm-management skill
- **"How should I score this lead?"** → lead-scoring skill
- **"Create a Supabase migration with RLS"** → ballee database-migration-manager skill
- **"Build a Flutter module with Riverpod"** → ballee flutter-development skill

## Structure

```
cortex-skills/
├── .claude-plugin/
│   └── marketplace.json
├── skills/
│   ├── shopify/
│   │   ├── translations/
│   │   ├── liquid-patterns/
│   │   └── theme-dev/
│   ├── supabase/
│   │   ├── migrations/
│   │   └── rls-policies/
│   ├── analytics/
│   │   ├── gtm-management/
│   │   └── gsc-analysis/
│   ├── lead-gen/
│   │   ├── lead-scoring/
│   │   └── sla-tracking/
│   └── ballee/
│       ├── database-migration-manager/
│       ├── flutter-development/
│       ├── api-patterns/
│       └── ... (30 skills)
└── README.md
```

## License

MIT

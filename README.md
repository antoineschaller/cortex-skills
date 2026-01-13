# Cortex Skills

Reusable Claude Code skills and agents for e-commerce, analytics, development, and project-specific workflows.

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

# Developer tools (skill/agent management)
/plugin install dev-tools-skills@cortex-skills

# Content creation automation
/plugin install content-creation-skills@cortex-skills

# Ballee (dance production management)
/plugin install ballee-skills@cortex-skills
```

## 🔗 Related Resources

### Cortex Ecosystem

Cortex Skills teaches AI **how** to use patterns. Cortex Packages provides the **code** that implements them.

- **📦 NPM Packages**: [Cortex Packages on GitHub](https://github.com/antoineschaller/cortex-packages) (private repo)
  - 28 published packages: [@akson/cortex-* on npm](https://www.npmjs.com/search?q=%40akson%2Fcortex)
  - Auto-publishing monorepo with Lerna
  - Supabase, Analytics, GTM, Landing Pages, Dev Tools, and more
  - **New:** [@akson/cortex-dev-tools](https://www.npmjs.com/package/@akson/cortex-dev-tools) - Shared ESLint, Prettier, and TypeScript configs

- **🤝 Compatibility**: [COMPATIBILITY.md](./COMPATIBILITY.md)
  - Shows which skills work with which package versions
  - Updated automatically via GitHub Actions
  - Tracks 14+ skill→package dependencies

### Using Skills + Packages Together

1. **Install Skills** (teaches Claude patterns):
   ```bash
   /plugin install ballee-skills@cortex-skills
   ```

2. **Install Packages** (provides implementation):
   ```bash
   npm install @akson/cortex-supabase @akson/cortex-gtm
   ```

3. **Develop**: Claude uses skill patterns + package APIs for consistent, high-quality code

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

### dev-tools-skills
Developer tools: skill management, agent management, development workflows.

| Skill | Description |
|-------|-------------|
| skill-manager | Create, edit, validate, and manage Claude Code skills and collections |

### content-creation-skills
Content creation automation: 2026 platform algorithms, A/B testing, video SEO, automation systems.

| Skill | Description |
|-------|-------------|
| 2026-content-strategy | YouTube, TikTok, Instagram algorithm insights for 2026 (CTR targets, hook strategies, engagement metrics) |
| ab-testing-framework | Systematic A/B testing for thumbnails, titles, hooks with statistical significance analysis |
| video-seo-2026 | Multi-platform SEO optimization (keyword placement, hashtag strategies, discoverability) |
| content-automation-system | End-to-end automation pipeline (script → video → distribution → analytics → optimization) |

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

**Integrations (6 skills)**
| Skill | Description |
|-------|-------------|
| airtable-sync-specialist | Airtable sync, cache, duplicate prevention |
| fever-sync-specialist | Fever Partners API sync for plans, reviews, venues |
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

## Agents

Agents are autonomous task executors that combine multiple skills for complex workflows.

### ballee-agents

| Agent | Model | Description |
|-------|-------|-------------|
| quality-reviewer | Sonnet | Comprehensive quality gate: automated checks (typecheck, lint, format, tests, build), pattern validation, accessibility, documentation, security audit |
| database-specialist | Haiku | Database schema design, migrations, RLS policies, query optimization |
| db-performance-agent | Haiku | Scan and fix N+1 queries, sequential queries, unbounded fetches |
| sentry-fixer-agent | Sonnet | Autonomous Sentry error investigation, root cause analysis, fixes |

**Quality Reviewer Checks:**
- Automated: format, lint, typecheck, tests, build
- Scripts: WIP validation, JSON keys, migration lint, RLS analysis, i18n, lockfile, DB types, dependency audit
- Patterns: Services, Actions, Components, Migrations, RLS, Tests, Flutter
- Required: Accessibility (jsx-a11y), Error Handling, Documentation, Sentry comments

## Usage

Once installed, skills automatically activate when Claude detects relevant context:

- **"Help me translate the Shopify content"** → shopify-translations skill
- **"Create a migration to add a users table"** → supabase-migrations skill
- **"Set up GTM conversion tracking"** → gtm-management skill
- **"How should I score this lead?"** → lead-scoring skill
- **"Optimize my YouTube video for 2026 algorithm"** → 2026-content-strategy skill
- **"Help me A/B test thumbnails"** → ab-testing-framework skill
- **"Optimize SEO for TikTok and Instagram"** → video-seo-2026 skill
- **"Build automated content pipeline"** → content-automation-system skill
- **"Create a Supabase migration with RLS"** → ballee database-migration-manager skill
- **"Build a Flutter module with Riverpod"** → ballee flutter-development skill
- **"Run quality review on my changes"** → ballee quality-reviewer agent

## Templates (Generic/Reusable)

The `templates/` folder contains **framework-agnostic** versions of skills and agents that any project can download and customize.

### How to Use Templates

1. **Copy** the template to your project's `.claude/` folder
2. **Customize** the patterns, commands, and checklists for your tech stack
3. **Rename** if needed to match your project conventions

### Available Templates

#### Agents (6 templates)

| Template | Model | Description |
|----------|-------|-------------|
| `quality-reviewer` | Sonnet | Comprehensive quality gate - customize commands, file patterns, checklists |
| `database-specialist` | Haiku | Database expert - customize for PostgreSQL, MySQL, or your ORM |
| `sentry-fixer` | Sonnet | Error investigation - customize for Sentry, Bugsnag, Rollbar, etc. |
| `db-performance` | Haiku | N+1 detection, sequential query optimization, unbounded fetch prevention |
| `code-reviewer` | Sonnet | PR review with architecture, security, performance, and quality checks |
| `security-auditor` | Sonnet | OWASP top 10, dependency scan, secret detection, RLS audit |

#### Skills (19 templates)

**Core Patterns**
| Template | Description |
|----------|-------------|
| `api-patterns` | Server actions with pagination, versioning, rate limiting, webhooks, bulk operations |
| `service-patterns` | Service layer with Result types - customize for your ORM |
| `test-patterns` | Testing patterns - customize for Vitest, Jest, Playwright |
| `ui-patterns` | Component architecture, accessibility, Server Components |
| `error-handling` | Error boundaries, global handlers, retry patterns, logging |

**Database & Security**
| Template | Description |
|----------|-------------|
| `db-anti-patterns` | N+1 detection rules, sequential queries, unbounded fetches |
| `rls-security` | Row-level security with bypass patterns, common bugs, debugging queries |
| `auth-patterns` | MFA/2FA, password reset, account lockout, device/session management |
| `data-management` | Zero-downtime migrations, GDPR/CCPA, soft delete, versioning, backups |

**Mobile/Flutter**
| Template | Description |
|----------|-------------|
| `flutter-patterns` | Offline-first, push notifications, biometrics, platform channels, flavors |
| `flutter-testing` | Unit, widget, golden, integration tests with mocking |
| `mobile-cicd` | Xcode Cloud, Fastlane, GitHub Actions, code signing, deployment |

**Observability & Operations**
| Template | Description |
|----------|-------------|
| `logging-patterns` | Structured logging, tracing, metrics, log aggregation |
| `caching-patterns` | In-memory, Redis, HTTP caching, invalidation strategies |
| `background-jobs` | BullMQ, Inngest, scheduled tasks, workers, retries |
| `production-readiness` | Health checks, graceful shutdown, feature flags, monitoring, runbooks |

**Infrastructure & State**
| Template | Description |
|----------|-------------|
| `cicd-patterns` | GitHub Actions, caching, preview deploys, rollback strategies |
| `i18n-patterns` | Complete pluralization, RTL with logical CSS, validation scripts |
| `state-management` | Server state (React Query), client state (Zustand), URL state |

### Template vs Project-Specific

| Folder | Purpose | Example |
|--------|---------|---------|
| `templates/` | Generic, framework-agnostic | `templates/agents/quality-reviewer.md` |
| `skills/ballee/` | Project-specific, ready to use | `skills/ballee/flutter-development/` |

## Structure

```
cortex-skills/
├── .claude-plugin/
│   └── marketplace.json
├── templates/                    # Generic templates for any project
│   ├── agents/
│   │   ├── quality-reviewer.md   # Quality gate template
│   │   ├── database-specialist.md # DB migrations/RLS template
│   │   ├── sentry-fixer.md       # Error tracking template
│   │   ├── db-performance.md     # Query optimization template
│   │   ├── code-reviewer.md      # PR review template
│   │   └── security-auditor.md   # Security audit template
│   └── skills/
│       ├── api-patterns/         # Server actions, pagination, webhooks
│       ├── service-patterns/     # Service layer patterns
│       ├── test-patterns/        # Testing strategies
│       ├── ui-patterns/          # Component architecture
│       ├── error-handling/       # Error management
│       ├── db-anti-patterns/     # N+1 detection rules
│       ├── rls-security/         # Row-level security
│       ├── auth-patterns/        # MFA, password reset, lockout
│       ├── data-management/      # Migrations, GDPR, soft delete
│       ├── cicd-patterns/        # CI/CD pipelines
│       ├── i18n-patterns/        # Internationalization, RTL
│       ├── state-management/     # State patterns
│       ├── flutter-patterns/     # Flutter offline, biometric
│       ├── flutter-testing/      # Flutter testing
│       ├── mobile-cicd/          # Mobile CI/CD
│       ├── logging-patterns/     # Observability
│       ├── caching-patterns/     # Cache strategies
│       ├── background-jobs/      # Queues & workers
│       └── production-readiness/ # Health, feature flags, runbooks
├── skills/                       # Project-specific skills
│   ├── shopify/
│   ├── supabase/
│   ├── analytics/
│   ├── lead-gen/
│   ├── content-creation/
│   └── ballee/
├── agents/                       # Project-specific agents
│   └── ballee/
└── README.md
```

## License

MIT

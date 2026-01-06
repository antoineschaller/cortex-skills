# Cortex Skills

Reusable Claude Code skills for e-commerce, analytics, and development.

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

## Usage

Once installed, skills automatically activate when Claude detects relevant context:

- **"Help me translate the Shopify content"** → shopify-translations skill
- **"Create a migration to add a users table"** → supabase-migrations skill
- **"Set up GTM conversion tracking"** → gtm-management skill
- **"How should I score this lead?"** → lead-scoring skill

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
│   └── lead-gen/
│       ├── lead-scoring/
│       └── sla-tracking/
└── README.md
```

## License

MIT

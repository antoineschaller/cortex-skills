# MyArmy Skills Collection

Project-specific implementations for MyArmy.ch - Swiss military custom badge manufacturing.

## Overview

This collection contains **implementations** that extend cortex-skills frameworks with MyArmy-specific configuration. These skills demonstrate the proper pattern for creating project-specific skills that remain maintainable and benefit from framework updates.

## Business Context

**MyArmy.ch** manufactures custom military badges for the Swiss Armed Forces:
- **Products**: Funktionsabzeichen, Truppenabzeichen, Rekrutenschule souvenirs
- **Market**: Switzerland (German, French, Italian speakers)
- **Audience**: B2B (unit commanders) + B2C (individual soldiers)
- **Average Order**: CHF 500-1200 (custom badges for entire units)
- **Sales Cycle**: 2-6 weeks (inquiry → quote → design → order)
- **Key Channel**: WhatsApp (85% of conversions)

## Skills

### gtm-myarmy
**Extends**: `analytics-framework/gtm-integration`

**Purpose**: GTM container management with MyArmy conversion tracking

**Configuration Highlights**:
- GTM Container: `GTM-T8WRBMWV`
- Google Ads: `8847935674`
- Conversion Labels: Form (`JIHLCN-r-IwbEP7BxboC`), WhatsApp (`o9ylCNyr-IwbEP7BxboC`)
- Dual event systems: Lead generation (score-based) + E-commerce (CHF values)

**Key Difference from Framework**: Hardcoded container IDs and conversion labels for MyArmy account

---

### lead-scoring-myarmy
**Extends**: `lead-generation-framework/lead-scoring-system`

**Purpose**: Lead qualification for Swiss military custom badge orders

**Configuration Highlights**:
- WhatsApp as primary conversion channel (+85 score)
- Military keyword bonuses (militär badge, funktionsabzeichen)
- Seasonal decay (4% during summer vs 2% during peak)
- Unit commander decision-making patterns
- Minimum order quantities (20-50 badges)

**Key Difference from Framework**: Swiss military market specifics, WhatsApp focus, seasonal patterns

---

## Architecture Pattern

### How MyArmy Skills Work

```
┌─────────────────────────────────────────┐
│  cortex-skills (generic frameworks)     │
│  ├── analytics-framework/               │
│  │   └── gtm-integration                │
│  └── lead-generation-framework/         │
│      └── lead-scoring-system            │
└─────────────────────────────────────────┘
              ↑ extends
              │
┌─────────────────────────────────────────┐
│  myarmy-skills (implementations)        │
│  ├── gtm-myarmy ←──────────────────┐    │
│  │   └── skill.config.json         │    │
│  │       (GTM-T8WRBMWV, 8847935674)│    │
│  └── lead-scoring-myarmy ←─────────┤    │
│      └── skill.config.json         │    │
│          (WhatsApp, military)      │    │
└────────────────────────────────────┼────┘
                                     │
                            Project-specific
                            values in config
```

### Benefits of This Pattern

1. **Framework Updates Propagate**: When `analytics-framework/gtm-integration` improves, `gtm-myarmy` automatically benefits
2. **Clear Separation**: Generic patterns vs project values
3. **Reusable Patterns**: Other projects can copy patterns, substitute values
4. **Single Source of Truth**: skill.config.json contains all project-specific configuration
5. **Maintainable**: Update values without touching framework code

## Configuration Pattern

### skill.config.json Structure

Every MyArmy skill has a `skill.config.json` that:
1. **Extends framework**: `"extends": "analytics-framework/gtm-integration"`
2. **Declares dependencies**: Packages, env vars, APIs, files
3. **Provides configuration**: Project-specific values
4. **Tags for discovery**: Swiss market, B2B, WhatsApp, etc.
5. **Reusability score**: Self-assessment (0-100)

**Example**:
```json
{
  "skill": "gtm-myarmy",
  "extends": "analytics-framework/gtm-integration",
  "configuration": {
    "gtm": {
      "container_id": "${GTM_CONTAINER_ID}"
    },
    "google_ads": {
      "customer_id": "${GOOGLE_ADS_CUSTOMER_ID}",
      "conversion_labels": {
        "form_submission": "${CONVERSION_LABEL_FORM}"
      }
    }
  },
  "tags": ["gtm", "swiss-market", "myarmy"]
}
```

### Environment Variables Pattern

All project-specific values use environment variables:
```bash
# GTM Configuration
GTM_CONTAINER_ID="GTM-T8WRBMWV"
GOOGLE_ADS_CUSTOMER_ID="8847935674"
CONVERSION_LABEL_FORM="JIHLCN-r-IwbEP7BxboC"

# Lead Scoring
WHATSAPP_BUSINESS_NUMBER="+41791234567"
SUPABASE_URL="https://project.supabase.co"
```

This allows:
- Different values per environment (dev, staging, prod)
- No hardcoded secrets in code
- Easy project cloning (copy .env.example)

## Swiss Military Market Specifics

### Key Differences from Generic Patterns

1. **WhatsApp is primary**: 85% of conversions happen via WhatsApp (not email/forms)
2. **B2B2C model**: Unit commanders order for their teams (B2B decision, B2C experience)
3. **High-value orders**: CHF 500-5000 per order (not single-item purchases)
4. **Long sales cycle**: 2-6 weeks (not instant e-commerce)
5. **Seasonal demand**: Peak Sept-Nov (new recruits), low June-Aug (summer)
6. **Language**: Swiss German preferred, High German acceptable
7. **Military keywords**: funktionsabzeichen, truppenabzeichen (niche terminology)

### Scoring Event Adjustments

Standard e-commerce scoring vs MyArmy:
```
Standard:              MyArmy:
Page view: +5          Page view: +5
Add to cart: +30       Custom design inquiry: +50
Checkout: +60          WhatsApp contact: +85
Purchase: +100         Order placed: +100
```

WhatsApp gets higher score because it signals **serious intent** in Swiss B2B context.

## Integration with Landing Project

These skills should eventually be **moved to myarmy/landing/.claude/skills/** because:
1. They reference landing project scripts and configuration
2. They use landing project environment variables
3. They're unusable outside MyArmy context

**Migration Path**:
```bash
# Move to landing project
mv cortex-skills/skills/myarmy-skills/ myarmy/landing/.claude/skills/

# Update marketplace.json in landing
# Add myarmy-skills collection

# Remove from cortex-skills marketplace.json
```

**Keep in cortex-skills for now** to demonstrate implementation pattern to other projects.

## Using MyArmy Skills

### From MyArmy Landing Project

```bash
cd /Users/antoineschaller/GitHub/myarmy/landing

# Skills are auto-discovered from .claude/skills/
# (once moved from cortex-skills)

# Or reference cortex-skills directly
export CLAUDE_SKILLS_PATH="/Users/antoineschaller/GitHub/myarmy/cortex-skills"
```

### From Other Projects (as Template)

```bash
# Copy skill structure (not values!)
cp -r cortex-skills/skills/myarmy-skills/gtm-myarmy your-project/skills/gtm-yourproject

# Edit skill.config.json
# Replace MyArmy values with your project values
# Change GTM container ID, conversion labels, etc.

# Update SKILL.md
# Replace Swiss military context with your market
```

## Development Workflow

### Adding New MyArmy Skill

1. **Choose framework to extend**:
   ```bash
   ls cortex-skills/skills/*-framework/
   ```

2. **Create implementation directory**:
   ```bash
   mkdir -p myarmy-skills/new-skill-myarmy
   ```

3. **Create skill.config.json**:
   ```bash
   cp skill-config.schema.json myarmy-skills/new-skill-myarmy/skill.config.json
   # Edit with MyArmy values
   ```

4. **Create SKILL.md**:
   ```markdown
   ---
   name: new-skill-myarmy
   extends: framework-name/skill-name
   ---

   # MyArmy Implementation

   Extends `framework-name/skill-name` with Swiss military market specifics.

   ## Configuration
   (MyArmy-specific values)
   ```

5. **Add to marketplace.json**:
   ```json
   {
     "plugins": [{
       "name": "myarmy-skills",
       "skills": [
         "./gtm-myarmy",
         "./lead-scoring-myarmy",
         "./new-skill-myarmy"
       ]
     }]
   }
   ```

## Key Rules

### DO:
- Extend framework skills (don't reinvent)
- Use skill.config.json for all project values
- Use environment variables for secrets/IDs
- Document Swiss military market context
- Tag with "myarmy", "swiss-market", etc.
- Include reusability score

### DON'T:
- Hardcode values in SKILL.md
- Copy-paste framework code (extends instead)
- Mix generic and project-specific in same skill
- Forget to update marketplace.json
- Skip documentation of why values differ from framework

## Resources

- **Framework Skills**: `/cortex-skills/skills/*-framework/`
- **Schema**: `/cortex-skills/skill-config.schema.json`
- **Landing Project**: `/myarmy/landing/`
- **Business Context**: `/myarmy/landing/docs/business/`
- **Analytics Docs**: `/myarmy/landing/docs/03-analytics/`

## Support

- **MyArmy Business Questions**: See `/landing/docs/business/`
- **Framework Questions**: See individual framework READMEs
- **Technical Issues**: https://github.com/your-org/cortex-skills

# Analytics Framework

Generic analytics patterns and integration guides for any project.

## Collection Overview

Framework skills providing reusable patterns for analytics implementation. These are **NOT project-specific** - they serve as templates for creating project-specific implementations.

## Skills

### gtm-integration
**Purpose:** Generic GTM setup and management patterns

**Use Cases:**
- Setting up GTM from scratch
- Managing tags, triggers, and variables
- Implementing conversion tracking
- Multi-platform event tracking

**Key Features:**
- @akson package integration
- Event standardization patterns
- Service account setup guide
- Testing and debugging workflows

### gsc-optimization
**Purpose:** Generic SEO and keyword optimization patterns

**Use Cases:**
- Keyword ranking analysis
- Search performance monitoring
- SEO opportunity identification
- Content optimization strategies

**Key Features:**
- @akson GSC package integration
- Keyword research workflows
- Automated reporting patterns
- Alert threshold strategies

## How to Use Framework Skills

### 1. Create Project-Specific Implementation

```bash
# Example: MyArmy GTM implementation
mkdir -p myarmy-skills/gtm-myarmy
cd myarmy-skills/gtm-myarmy
```

### 2. Reference Framework in skill.config.json

```json
{
  "skill": "gtm-myarmy",
  "version": "1.0.0",
  "extends": "analytics-framework/gtm-integration",
  "dependencies": {
    "env_vars": {
      "GTM_CONTAINER_ID": {
        "required": true,
        "description": "MyArmy GTM container ID",
        "example": "GTM-T8WRBMWV"
      }
    }
  },
  "configuration": {
    "gtm_container_id": "${GTM_CONTAINER_ID}",
    "google_ads_account": "${GOOGLE_ADS_CUSTOMER_ID}",
    "conversion_labels": {
      "form_submission": "${CONVERSION_LABEL_FORM}",
      "whatsapp_contact": "${CONVERSION_LABEL_WHATSAPP}"
    }
  }
}
```

### 3. Create Implementation-Specific Documentation

```markdown
---
name: gtm-myarmy
extends: analytics-framework/gtm-integration
---

# MyArmy GTM Implementation

Extends `analytics-framework/gtm-integration` with MyArmy-specific configuration.

## Configuration

- GTM Container: GTM-T8WRBMWV
- Google Ads: 8847935674
- Conversion Labels:
  - Form: JIHLCN-r-IwbEP7BxboC
  - WhatsApp: o9ylCNyr-IwbEP7BxboC

## MyArmy-Specific Events

(Document project-specific events here)
```

## Benefits of Framework Pattern

### ✅ Reusability
- Generic patterns work across any project
- No hardcoded values in framework
- Easy to adapt for different use cases

### ✅ Maintainability
- Update framework → all implementations benefit
- Clear separation: patterns vs configuration
- Single source of truth for best practices

### ✅ Consistency
- All projects follow same patterns
- Standardized event naming
- Common debugging approaches

## Dependencies

All framework skills use:
- **@akson/cortex-analytics** - Unified CLI
- **@akson/cortex-gtm** - GTM management
- **@akson/cortex-gsc** - GSC analysis
- **@akson/cortex-utilities** - Event constants

Install globally or per-project:
```bash
npm install -g @akson/cortex-analytics
# or
npm install @akson/cortex-analytics @akson/cortex-gtm @akson/cortex-gsc
```

## Example Implementations

### Real-World Examples
- `myarmy-skills/gtm-myarmy` - MyArmy landing page GTM
- `myarmy-skills/seo-myarmy` - Swiss military keyword optimization

### Your Implementation Here!
Follow the pattern above to create your own implementations.

## Support

- **Package Issues**: https://github.com/your-org/cortex-packages
- **Skill Issues**: https://github.com/your-org/cortex-skills
- **Documentation**: See individual skill README files

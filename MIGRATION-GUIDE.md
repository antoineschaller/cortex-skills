# Cortex Skills - Reusability Migration Guide

**Date**: 2026-01-12
**Version**: 2.0.0
**Status**: Complete

## Overview

This guide documents the transformation of cortex-skills from a mix of generic and project-specific skills into a properly structured framework + implementation pattern.

## Problem Statement (Before)

**Issue**: 47% of cortex-skills were project-specific but lived in a generic repository

- `marketing-intelligence-skills` (9 skills): Hardcoded MyArmy paths, GTM container IDs
- `analytics-skills` (2 skills): Hardcoded Google Ads accounts, conversion labels
- `ballee-skills` (34 skills): Heavily coupled to Ballee project
- Mixed generic patterns with project-specific values

**Impact**:
- Skills broke when cortex-skills was cloned without specific projects
- Relative paths like `../../../landing/scripts/` assumed directory structure
- No clear separation between reusable patterns and project configuration
- Difficult to maintain and update

## Solution (After)

### New Architecture

```
cortex-skills/
├── skills/
│   ├── *-framework/          ← GENERIC patterns (reusable)
│   │   ├── analytics-framework/
│   │   ├── lead-generation-framework/
│   │   └── marketing-intelligence-framework/
│   ├── *-skills/             ← EXAMPLE implementations
│   │   └── myarmy-skills/
│   └── [existing skills]     ← Unchanged generic skills
├── scripts/                  ← Reusable utility scripts
├── skill-config.schema.json  ← Configuration schema
└── MIGRATION-GUIDE.md        ← This file

myarmy/landing/
└── .claude/skills/
    └── marketing-intelligence/  ← PROJECT-SPECIFIC skills (moved)
```

### Key Changes

1. **Framework Skills**: Generic patterns with no hardcoded values
2. **Implementation Skills**: Project-specific, extend frameworks via `skill.config.json`
3. **Project Skills Moved**: `marketing-intelligence` moved to `myarmy/landing/.claude/skills/`
4. **Configuration Layer**: All project values in `skill.config.json`
5. **Reusable Scripts**: Extracted to `scripts/` directory

## What Was Created

### 1. Framework Collections (Generic)

#### analytics-framework/
- **gtm-integration**: Generic GTM setup patterns (@akson packages, event tracking)
- **gsc-optimization**: Generic SEO and keyword analysis patterns

#### lead-generation-framework/
- **lead-scoring-system**: Generic 1-100 lead scoring model (funnel stages, decay, routing)
- **sla-tracking**: Generic response time SLAs (urgent/high/normal/low tiers)

#### marketing-intelligence-framework/
- **campaign-analytics**: Generic ad performance tracking (Google Ads, Meta Ads, ROAS)

**Key Feature**: No hardcoded IDs, URLs, or project names. Pure patterns.

### 2. Example Implementation Collection

#### myarmy-skills/
- **gtm-myarmy**: MyArmy GTM implementation (extends `analytics-framework/gtm-integration`)
  - GTM: `GTM-T8WRBMWV`
  - Google Ads: `8847935674`
  - Conversion labels: `JIHLCN-r-IwbEP7BxboC`, `o9ylCNyr-IwbEP7BxboC`

- **lead-scoring-myarmy**: MyArmy lead scoring (extends `lead-generation-framework/lead-scoring-system`)
  - WhatsApp as primary channel (+85 score)
  - Swiss military keywords
  - Seasonal patterns (peak Sept-Nov)

**Key Feature**: All project values in `skill.config.json`, references framework

### 3. Configuration Infrastructure

#### skill-config.schema.json
JSON schema defining:
- `extends`: Framework reference
- `dependencies`: Packages, env vars, APIs, files, scripts
- `configuration`: Project-specific values (use `${ENV_VAR}` placeholders)
- `tags`: Categorization
- `reusability`: Self-assessment (score 0-100, level)

**Example**:
```json
{
  "skill": "gtm-myarmy",
  "extends": "analytics-framework/gtm-integration",
  "configuration": {
    "gtm_container_id": "${GTM_CONTAINER_ID}",
    "conversion_labels": {
      "form": "${CONVERSION_LABEL_FORM}"
    }
  }
}
```

### 4. Reusable Scripts

#### scripts/validation/
- `validate-wip.sh`: WIP document lifecycle validation
- `validate-json-keys.sh`: JSON duplicate key detection
- `validate-dependencies.sh`: Environment variable validation

#### scripts/quality/
- `code-quality-check.sh`: Universal quality gate (typecheck, lint, test)

#### scripts/assessment/
- `assess-reusability.sh`: Reusability analysis tool

**Key Feature**: All scripts are project-agnostic (use env vars for configuration)

## What Was Moved

### marketing-intelligence-skills → myarmy/landing

**Before** (cortex-skills):
```
cortex-skills/skills/marketing-intelligence/
├── google-ads-performance/
│   └── skill.json (script: "../../../landing/scripts/...")
└── [8 other skills with hardcoded landing/ paths]
```

**After** (myarmy/landing):
```
myarmy/landing/.claude/skills/marketing-intelligence/
├── google-ads-performance/
│   └── skill.json (script: "../../scripts/...")
└── [8 other skills with local paths]
```

**Why**: These skills are unusable outside MyArmy project (hardcoded paths, scripts, configs)

## How to Use New Pattern

### For Users: Creating Project-Specific Skills

1. **Choose framework to extend**:
   ```bash
   ls cortex-skills/skills/*-framework/
   ```

2. **Create implementation in your project**:
   ```bash
   mkdir -p your-project/.claude/skills/your-skill
   cd your-project/.claude/skills/your-skill
   ```

3. **Create skill.config.json**:
   ```json
   {
     "$schema": "https://path/to/skill-config.schema.json",
     "skill": "your-skill",
     "extends": "analytics-framework/gtm-integration",
     "configuration": {
       "gtm_container_id": "${GTM_CONTAINER_ID}",
       "google_ads_account": "${GOOGLE_ADS_CUSTOMER_ID}"
     }
   }
   ```

4. **Create SKILL.md**:
   ```markdown
   ---
   name: your-skill
   extends: analytics-framework/gtm-integration
   ---

   # Your Skill

   Extends `analytics-framework/gtm-integration` with your project specifics.

   ## Configuration
   (Document your project-specific values)
   ```

5. **Add to marketplace.json**:
   ```json
   {
     "plugins": [{
       "name": "your-skills",
       "skills": ["./your-skill"]
     }]
   }
   ```

### For Maintainers: Creating Framework Skills

1. **Identify reusable pattern** (e.g., "lead scoring is useful for many businesses")

2. **Create framework skill**:
   ```bash
   mkdir -p skills/your-framework/your-pattern
   cd skills/your-framework/your-pattern
   ```

3. **Write generic SKILL.md**:
   - NO hardcoded values (URLs, IDs, project names)
   - Use placeholders: `${VARIABLE_NAME}`
   - Document configuration points
   - Provide usage examples

4. **Add README.md** to framework collection:
   - Explain framework purpose
   - List all skills in collection
   - Show how to create implementations

5. **Update marketplace.json**:
   ```json
   {
     "name": "your-framework",
     "category": "framework",
     "skills": ["./your-pattern"]
   }
   ```

## Migration Checklist

### For Existing Project-Specific Skills

- [ ] Identify framework pattern to extend (or create new framework)
- [ ] Move skill to project repository (`your-project/.claude/skills/`)
- [ ] Create `skill.config.json` with `extends` field
- [ ] Replace hardcoded values with `${ENV_VAR}` references
- [ ] Update paths (e.g., `../../../landing/` → `../../`)
- [ ] Add to project's marketplace.json
- [ ] Remove from cortex-skills marketplace.json
- [ ] Test skill still works from new location

### For Generic Skills

- [ ] Verify no hardcoded project values
- [ ] Add `skill.config.json` (even if minimal)
- [ ] Tag appropriately in marketplace.json
- [ ] Keep in cortex-skills (already generic)

## Reusability Assessment

Run the assessment script to analyze your skills:

```bash
cd cortex-skills
./scripts/assessment/assess-reusability.sh

# Or generate JSON report
./scripts/assessment/assess-reusability.sh --json > reusability-report.json
```

**Output** shows:
- **Generic**: Fully reusable (no project references)
- **Framework**: Reusable patterns for implementations
- **Implementation**: Project-specific, extends framework
- **Project-Specific**: Hardcoded to project (should move)

## Benefits of New Architecture

### ✅ Reusability
- Frameworks work across any project
- Clear patterns for common tasks
- Easy to adapt to new contexts

### ✅ Maintainability
- Update framework → all implementations benefit
- Project values in one place (skill.config.json)
- Clear separation of concerns

### ✅ Discoverability
- Framework category in marketplace
- Implementation examples (myarmy-skills)
- Consistent naming conventions

### ✅ Correctness
- Skills work when cortex-skills is cloned standalone
- No broken relative paths
- Project skills live with their projects

## Examples

### Example 1: MyArmy GTM Implementation

**Framework**: `analytics-framework/gtm-integration`
**Implementation**: `myarmy-skills/gtm-myarmy`

**What framework provides**:
- @akson package integration patterns
- Event tracking workflows
- Service account setup guide
- Debugging techniques

**What implementation adds**:
- Specific GTM container (`GTM-T8WRBMWV`)
- Specific conversion labels
- Swiss military keyword context
- MyArmy funnel documentation

### Example 2: Lead Scoring for Any Business

**Framework**: `lead-generation-framework/lead-scoring-system`

**Can be implemented for**:
- Swiss military badges (MyArmy) → WhatsApp-heavy
- SaaS product (YourCo) → Email-heavy, demo requests
- E-commerce (Fashion) → Add-to-cart, abandoned cart recovery

**Framework provides** 1-100 scoring model, decay patterns, routing logic
**Each implementation** defines its own scoring events and thresholds

## Backward Compatibility

### Deprecated Skills (Still Work, But Use Frameworks Instead)

- `analytics-skills` → Use `analytics-framework`
- `lead-gen-skills` → Use `lead-generation-framework`

**Marked as DEPRECATED** in marketplace.json

### Migration Path

1. Existing projects using deprecated skills: **No immediate action needed**
2. New projects: **Use framework + implementation pattern**
3. Over time: **Migrate deprecated skills to framework pattern**

## Support

- **Questions about frameworks**: See individual framework README files
- **Questions about implementations**: See myarmy-skills examples
- **Issues**: https://github.com/your-org/cortex-skills
- **Schema Reference**: `skill-config.schema.json`

## Next Steps

### Immediate (Done ✅)
- [x] Create framework collections
- [x] Move marketing-intelligence to myarmy/landing
- [x] Create example implementations (myarmy-skills)
- [x] Update marketplace.json
- [x] Create migration guide

### Short-term (Recommended)
- [ ] Migrate deprecated analytics-skills to framework pattern
- [ ] Migrate deprecated lead-gen-skills to framework pattern
- [ ] Create more framework skills (database, mobile, etc.)
- [ ] Document framework contribution guidelines

### Long-term (Optional)
- [ ] Build skill-manager support for `extends` field
- [ ] Auto-validate skill.config.json against schema
- [ ] Generate dependency documentation automatically
- [ ] Create skill marketplace website

## Summary

**What we achieved**:
1. ✅ Separated generic patterns (frameworks) from project values (implementations)
2. ✅ Moved project-specific skills to their projects (marketing-intelligence → landing)
3. ✅ Created configuration layer (skill.config.json)
4. ✅ Extracted reusable scripts (scripts/ directory)
5. ✅ Provided clear examples (myarmy-skills)

**Result**: Cortex-skills is now truly reusable, maintainable, and scalable.

---

**Questions?** See framework README files or myarmy-skills examples.

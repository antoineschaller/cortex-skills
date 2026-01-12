# Project-Specific Skills Analysis

**Date:** 2026-01-12
**Issue:** Skills in cortex-skills reference myarmy/landing project, creating tight coupling

## Problem Statement

Cortex-skills is meant to be a **generic, reusable skill library**, but 47% of skills (36/76) are project-specific. The most problematic collection is **marketing-intelligence-skills** with hardcoded paths to the myarmy/landing project.

## Skill Coupling Analysis

### 🔴 TIGHT Coupling (Must Move or Restructure)

#### marketing-intelligence-skills (9 skills)
**Coupling Level:** EXTREME - 34 hardcoded references to myarmy/landing

**Evidence:**
- All skill.json files: `"script": "../../../landing/scripts/fetch-google-ads-spend.mjs"`
- All skill.json files: `"workingDirectory": "../../../landing"`
- All skill.json files: `"outputs": ["../../../landing/docs/wip/..."]`
- README.md: References to `/landing/docs/wip/` documentation

**Skills:**
1. revenue-analysis
2. airtable-orders
3. google-ads-performance
4. lead-funnel-analysis
5. budget-calculator
6. seasonal-budget-advisor
7. marketing-health-check
8. seo-performance
9. event-tracking-health

**Why This is a Problem:**
- Skills break if cortex-skills is cloned without myarmy/landing
- Relative paths `../../../landing/` assume specific directory structure
- Scripts, config files, and output directories live in landing project
- Collection is unusable by anyone except MyArmy project

---

### 🟡 MODERATE Coupling (Needs Configuration Abstraction)

#### analytics-skills (2 skills)

**gtm-management:**
- Hardcoded IDs: `GTM-T8WRBMWV` (MyArmy container)
- Hardcoded IDs: `8847935674` (Google Ads account)
- Hardcoded IDs: `659644670` (conversion ID)
- Hardcoded labels: `JIHLCN-r-IwbEP7BxboC` (form submission)
- BUT: Also has generic GTM patterns that are reusable

**gsc-analysis:**
- References `GSC_SITE_URL` but no hardcoded URLs
- Generic patterns for any GSC site

#### lead-gen-skills (2 skills)

**lead-scoring:**
- Generic 1-100 scoring framework
- WhatsApp funnel (MyArmy-specific conversion path)
- But patterns work for any lead generation

**sla-tracking:**
- Generic SLA patterns
- Swiss market response times (1h/4h/24h/48h)
- Can work for any region with configuration

#### shopify-skills (3 skills)

**translations:**
- References `npm run translations:myarmy:*` commands
- French→German/Italian/English (Swiss market)
- But dual-system architecture is generic

---

### 🟢 LOW Coupling (Generic and Reusable)

#### supabase-skills (2 skills)
- migrations: Generic Supabase patterns
- rls-policies: Generic RLS patterns

#### ballee-skills (34 skills)
- Project-specific but for **different project** (Ballee)
- Clear namespace separation

#### content-creation-skills (4 skills)
- 2026-content-strategy: Generic platform algorithms
- ab-testing-framework: Generic A/B testing
- video-seo-2026: Generic video SEO
- content-automation-system: Generic automation

#### dev-tools-skills (1 skill)
- skill-manager: Fully generic skill management

---

## Summary Statistics

| Coupling Level | Count | Percentage | Collections |
|---------------|-------|------------|-------------|
| 🔴 TIGHT | 9 | 12% | marketing-intelligence |
| 🟡 MODERATE | 7 | 9% | analytics, lead-gen, shopify |
| 🟢 LOW | 44 | 58% | supabase, content-creation, dev-tools |
| 🔵 OTHER PROJECT | 34 | 45% | ballee |

**Critical Issue:** 9 skills (marketing-intelligence) are completely unusable outside MyArmy project

---

## Options for Resolution

### Option A: Move Tightly Coupled Skills to MyArmy Project ⭐ RECOMMENDED

**Action:**
```bash
# Move marketing-intelligence-skills to myarmy/landing
mv skills/marketing-intelligence/ ~/GitHub/myarmy/landing/.claude/skills/

# Update myarmy landing marketplace.json
# Remove marketing-intelligence from cortex-skills marketplace.json
```

**Pros:**
- ✅ Clear separation: Project-specific skills live with project
- ✅ No broken paths: Scripts and configs are local
- ✅ Easy maintenance: Update skills when updating project
- ✅ Correct architecture: Generic library only has generic skills

**Cons:**
- ❌ Duplication if other projects need similar skills
- ❌ Must copy patterns, not share

**Best For:** Skills with extreme coupling (marketing-intelligence)

---

### Option B: Create Framework/Implementation Pattern

**Action:**
1. Create generic framework skills in cortex-skills:
   - `analytics-framework/gtm-integration` - Generic GTM patterns
   - `lead-generation-framework/lead-scoring-system` - Generic scoring
   - `marketing-intelligence-framework/revenue-analysis-patterns` - Generic patterns

2. Create myarmy-skills collection in cortex-skills:
   - `myarmy-skills/gtm-myarmy` - MyArmy GTM implementation
   - `myarmy-skills/marketing-intelligence-myarmy` - MyArmy implementations

3. Add skill.config.json to all implementations:
```json
{
  "skill": "gtm-myarmy",
  "extends": "analytics-framework/gtm-integration",
  "configuration": {
    "gtm_container_id": "${GTM_CONTAINER_ID}",
    "google_ads_account": "${GOOGLE_ADS_CUSTOMER_ID}"
  }
}
```

**Pros:**
- ✅ Reusable patterns for all projects
- ✅ Configuration abstraction
- ✅ Clear framework vs implementation

**Cons:**
- ❌ Complex structure
- ❌ More migration effort
- ❌ Still doesn't solve hardcoded path issue for marketing-intelligence

**Best For:** Skills with moderate coupling (analytics, lead-gen)

---

### Option C: Hybrid Approach ⭐⭐ BEST COMPROMISE

**Action:**

1. **Move TIGHT coupling to myarmy/landing:**
   - marketing-intelligence-skills (9 skills) → `landing/.claude/skills/marketing-intelligence/`
   - Remove from cortex-skills marketplace.json

2. **Add configuration to MODERATE coupling:**
   - Create skill.config.json for analytics/gtm-management
   - Create skill.config.json for lead-gen skills
   - Create skill.config.json for shopify/translations
   - Replace hardcoded values with `${VAR_NAME}`

3. **Keep LOW coupling as-is:**
   - supabase-skills stay generic
   - content-creation-skills stay generic
   - dev-tools-skills stay generic

4. **Namespace OTHER projects:**
   - Keep ballee-skills separate (already namespaced)

**Pros:**
- ✅ Pragmatic: Solves immediate problem
- ✅ Less effort than full framework restructure
- ✅ Clear decision criteria
- ✅ Each skill gets right treatment

**Cons:**
- ❌ Less systematic than pure framework approach

---

## Recommended Action Plan

### Phase 1: Move Tightly Coupled Skills (Immediate)

```bash
cd /Users/antoineschaller/GitHub/myarmy

# 1. Create skills directory in landing
mkdir -p landing/.claude/skills

# 2. Move marketing-intelligence
mv cortex-skills/skills/marketing-intelligence landing/.claude/skills/

# 3. Update landing marketplace.json
# Add marketing-intelligence-skills collection

# 4. Update cortex-skills marketplace.json
# Remove marketing-intelligence-skills

# 5. Test skills still work from new location
cd landing
# Skills now use ./scripts/ instead of ../../../landing/scripts/
```

**Time:** 30 minutes
**Impact:** Fixes 12% of skills (9/76)

---

### Phase 2: Add Configuration to Moderate Coupling

```bash
cd /Users/antoineschaller/GitHub/myarmy/cortex-skills

# 1. Create skill.config.json for analytics/gtm-management
cat > skills/analytics/gtm-management/skill.config.json <<EOF
{
  "skill": "gtm-management",
  "dependencies": {
    "env_vars": {
      "GTM_CONTAINER_ID": {
        "required": true,
        "description": "GTM container ID",
        "example": "GTM-T8WRBMWV"
      }
    }
  }
}
EOF

# 2. Replace hardcoded IDs with ${GTM_CONTAINER_ID} in SKILL.md
# 3. Repeat for lead-gen and shopify skills
```

**Time:** 2-3 hours
**Impact:** Makes 9% of skills (7/76) configurable

---

### Phase 3: Document Patterns (Optional)

Create framework skill documentation showing generic patterns:
- `/docs/patterns/gtm-integration-patterns.md`
- `/docs/patterns/lead-scoring-patterns.md`
- `/docs/patterns/revenue-analysis-patterns.md`

**Time:** 2 hours
**Impact:** Educational value for future skills

---

## File Changes Required

### Cortex-Skills Changes

**Remove (move to myarmy/landing):**
- `skills/marketing-intelligence/` (entire directory)

**Modify:**
- `.claude-plugin/marketplace.json` (remove marketing-intelligence-skills)

**Add:**
- `skills/analytics/gtm-management/skill.config.json`
- `skills/lead-gen/lead-scoring/skill.config.json`
- `skills/lead-gen/sla-tracking/skill.config.json`
- `skills/shopify/translations/skill.config.json`

**Update (replace hardcoded values):**
- `skills/analytics/gtm-management/SKILL.md`
- `skills/lead-gen/lead-scoring/SKILL.md`

---

### MyArmy Landing Changes

**Add:**
- `.claude/skills/marketing-intelligence/` (moved from cortex-skills)
- `.claude-plugin/marketplace.json` (if doesn't exist)

**Update paths in moved skills:**
- Change `../../../landing/scripts/` → `../../scripts/`
- Change `../../../landing/docs/wip/` → `../../docs/wip/`
- Change `../../../landing/config/` → `../../config/`

---

## Decision Matrix

| Criterion | Option A (Move) | Option B (Framework) | Option C (Hybrid) |
|-----------|-----------------|----------------------|-------------------|
| Solves immediate problem | ✅ Yes | ⚠️ Partial | ✅ Yes |
| Implementation time | 🟢 30 min | 🔴 12-16 hrs | 🟡 3-4 hrs |
| Future reusability | ❌ No | ✅ Yes | ⚠️ Moderate |
| Complexity | 🟢 Low | 🔴 High | 🟡 Medium |
| Maintenance burden | 🟡 Medium | 🔴 High | 🟢 Low |
| Architectural purity | 🟢 Clean | ✅ Perfect | 🟡 Good enough |

**Recommendation:** **Option C (Hybrid)** - Move tightly coupled, configure moderately coupled

---

## Next Steps

**User Decision Required:**

1. **Do you want to move marketing-intelligence-skills to myarmy/landing?**
   - This solves the immediate problem
   - Skills remain functional, just in correct location

2. **Do you want to add skill.config.json to moderately coupled skills?**
   - Makes them configurable for other projects
   - Takes a few hours but improves reusability

3. **Do you want to continue with the full reusability plan?**
   - Creates framework skills + configuration layer
   - Takes 12-16 hours but maximizes reusability

**My Recommendation:** Start with Option C Phase 1 (move marketing-intelligence), then decide if Phase 2 (configuration) is worth the effort.

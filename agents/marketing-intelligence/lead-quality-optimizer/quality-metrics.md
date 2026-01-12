# Lead Quality Metrics - Definitions & Calculations

Comprehensive definitions for lead quality analysis and funnel optimization.

---

## Core Metrics

### 1. Conversion Rate

**Definition:** Percentage of leads that become paying customers

**Formula:**
```javascript
conversionRate = (paidCustomers / totalLeads) * 100
```

**Targets:**
- ✅ **Target:** ≥20% (1 in 5 leads converts)
- ⚠️ **Warning:** 15-19% (acceptable but suboptimal)
- ⚠️ **Critical:** 10-14% (needs immediate attention)
- 🚨 **Critical:** <10% (funnel broken)

**Example Calculations:**
```javascript
// Week 1: 150 leads → 28 customers = 18.7% (warning)
// Week 2: 165 leads → 35 customers = 21.2% (target met)
// Week 3: 140 leads → 12 customers = 8.6% (critical)
```

**Actionable Thresholds:**
- Auto-report if ≥20% (success metric)
- Notify team if 15-19% (monitor closely)
- Alert immediately if <15% (requires intervention)

---

### 2. Lead Score (1-100)

**Definition:** Weighted engagement score based on funnel progression

**Scoring System:**
| Stage | Event | Score | Weight |
|-------|-------|-------|--------|
| Page View | `lead_page_view` | 5 | Low engagement |
| Content View | `lead_content_view` | 15 | Initial interest |
| Inquiry Started | `lead_inquiry_started` | 40 | High intent |
| Contact Info | `lead_contact_info` | 60 | Qualified lead |
| WhatsApp Contact | `lead_whatsapp_contact` | 85 | Very high intent |
| Form Submitted | `lead_form_submitted` | 100 | Maximum engagement |

**Calculation:**
```javascript
// Lead A: Page View (5) + Content View (15) = Score: 15
// Lead B: Page View (5) + Inquiry Started (40) + Contact Info (60) = Score: 60
// Lead C: Full journey = Score: 100

averageLeadScore = totalScoreAllLeads / numberOfLeads
```

**Targets:**
- ✅ **Target:** ≥70 (high-quality leads)
- ⚠️ **Warning:** 50-69 (moderate engagement)
- 🚨 **Critical:** <50 (low-quality traffic)

**Interpretation:**
- **70-100:** High-intent traffic, likely to convert
- **40-69:** Interested but needs nurturing
- **1-39:** Tire kickers, low conversion probability

---

### 3. Funnel Drop-off Rate

**Definition:** Percentage of leads lost between consecutive funnel stages

**Formula:**
```javascript
dropoffRate = 1 - (nextStageCount / currentStageCount)
```

**Example:**
```javascript
// Stage: Content View → Inquiry Started
// Content View: 442 leads
// Inquiry Started: 186 leads
// Drop-off: 1 - (186 / 442) = 58% loss
```

**Acceptable Drop-offs:**
| Transition | Normal | Warning | Critical |
|------------|--------|---------|----------|
| Page → Content | 40-50% | 50-60% | >60% |
| Content → Inquiry | 30-40% | 40-50% | >50% |
| Inquiry → Contact | 20-30% | 30-40% | >40% |
| Contact → Submission | 10-20% | 20-30% | >30% |

**Alert Thresholds:**
- ⚠️ **Warning:** >40% drop at any single stage
- 🚨 **Critical:** >60% drop at any single stage

**Bottleneck Identification:**
```javascript
// Identify stage with highest drop-off
bottlenecks = stages.filter(stage => stage.dropoffRate > 0.40)
  .sort((a, b) => b.dropoffRate - a.dropoffRate);
```

---

### 4. Time to Conversion

**Definition:** Average days from first lead capture to paid order

**Formula:**
```javascript
timeToConversion = (orderDate - leadCreatedDate) / (1000 * 60 * 60 * 24)
```

**Targets:**
- ✅ **Target:** ≤7 days (fast conversion cycle)
- ⚠️ **Warning:** 8-14 days (needs nurturing optimization)
- ⚠️ **Critical:** 15-21 days (long sales cycle)
- 🚨 **Critical:** >21 days (review entire funnel)

**Distribution Analysis:**
```javascript
// Ideal distribution:
// 0-3 days: 30% of conversions
// 4-7 days: 40% of conversions
// 8-14 days: 20% of conversions
// 15+ days: 10% of conversions
```

**Action Triggers:**
- Median >14 days → Implement lead nurturing sequence
- Median >21 days → Review qualification criteria
- 50%+ conversions >14 days → Add remarketing campaigns

---

### 5. Form Completion Rate

**Definition:** Percentage of users who complete the form after starting it

**Formula:**
```javascript
formCompletionRate = (formSubmitted / inquiryStarted) * 100
```

**Targets:**
- ✅ **Target:** ≥60% (good form UX)
- ⚠️ **Warning:** 45-59% (form friction present)
- 🚨 **Critical:** <45% (major form issues)

**Example:**
```javascript
// Inquiry Started: 186 users
// Form Submitted: 112 users
// Completion Rate: 112 / 186 = 60.2% (target met)
```

**Form Field Analysis:**
```javascript
// Track drop-off by field:
// Name: 5% drop
// Email: 10% drop
// Phone: 25% drop (BOTTLENECK)
// Product Details: 15% drop
// Message: 5% drop
```

**Optimization Triggers:**
- <60% → Reduce form fields
- <50% → Add progress indicator
- <40% → Consider split forms or wizard

---

## Advanced Metrics

### 6. Stage Velocity

**Definition:** Average time spent at each funnel stage

**Calculation:**
```javascript
stageVelocity = {
  pageView: "45 seconds",
  contentView: "3.5 minutes",
  inquiryStarted: "1.2 minutes",
  contactInfo: "2.5 hours",
  whatsappContact: "4.2 hours",
  formSubmitted: "3.8 days"
}
```

**Targets:**
- Page View → Content View: <2 minutes (fast engagement)
- Inquiry Started → Contact Info: <5 minutes (low friction)
- Contact Info → WhatsApp: <6 hours (prompt follow-up)
- Form Submitted → Order: <7 days (nurturing effectiveness)

---

### 7. Lead Source Quality

**Definition:** Conversion rate segmented by traffic source

**Formula:**
```javascript
sourceQuality = {
  googleAds: {
    leads: 85,
    conversions: 18,
    rate: 21.2%,
    cac: 14.50
  },
  organic: {
    leads: 52,
    conversions: 12,
    rate: 23.1%,
    cac: 0
  },
  referral: {
    leads: 28,
    conversions: 5,
    rate: 17.9%,
    cac: 8.20
  }
}
```

**Analysis:**
- Identify highest converting sources
- Optimize budget allocation
- Pause low-quality sources

---

### 8. Lead Engagement Cohort

**Definition:** Group leads by engagement level

**Cohorts:**
```javascript
cohorts = {
  highIntent: {
    criteria: "leadScore >= 70",
    count: 25,
    conversionRate: 0.40
  },
  moderate: {
    criteria: "leadScore 40-69",
    count: 68,
    conversionRate: 0.18
  },
  lowQuality: {
    criteria: "leadScore < 40",
    count: 72,
    conversionRate: 0.05
  }
}
```

**Strategy:**
- High Intent: Fast follow-up, personalized outreach
- Moderate: Nurture sequence, educational content
- Low Quality: Review targeting, consider filtering

---

## Calculation Examples

### Weekly Report Calculation

```javascript
// Sample data: 7 days, 165 leads, 28 conversions
const weeklyMetrics = {
  totalLeads: 165,
  paidCustomers: 28,
  conversionRate: (28 / 165) * 100, // 16.97%

  leadScores: [5, 15, 40, 60, 85, 100, ...], // 165 values
  averageScore: leadScores.reduce((a, b) => a + b) / 165, // 62.3

  funnelStages: {
    pageView: 850,
    contentView: 442, // 48% drop from page view
    inquiryStarted: 186, // 58% drop from content view (BOTTLENECK)
    contactInfo: 140, // 25% drop from inquiry
    whatsappContact: 67, // 52% drop from contact info (WARNING)
    formSubmitted: 55 // 18% drop from WhatsApp
  },

  timeToConversion: [3, 5, 7, 12, 14, ...], // days array
  medianTTC: 7.5, // median value

  formCompletionRate: (55 / 186) * 100 // 29.6% (CRITICAL)
};
```

### Bottleneck Identification

```javascript
const bottlenecks = [
  {
    stage: "content_view → inquiry_started",
    dropoffRate: 0.58, // 58% loss
    severity: "critical",
    impact: "Losing 256 potential leads per week",
    recommendation: "Improve CTA visibility, test new copy"
  },
  {
    stage: "contact_info → whatsapp_contact",
    dropoffRate: 0.52, // 52% loss
    severity: "warning",
    impact: "Losing 73 WhatsApp conversations per week",
    recommendation: "Add prominent WhatsApp CTA after email capture"
  }
];
```

---

## Alert Logic

### Conversion Rate Alerts

```javascript
if (conversionRate < 0.10) {
  alert = {
    level: "🚨 CRITICAL",
    message: "Conversion rate below minimum threshold (10%)",
    action: "Immediate review required"
  };
} else if (conversionRate < 0.15) {
  alert = {
    level: "⚠️ WARNING",
    message: "Conversion rate below target (15-20%)",
    action: "Optimize funnel bottlenecks"
  };
} else if (conversionRate >= 0.20) {
  alert = {
    level: "ℹ️ INFO",
    message: "Conversion rate meets target",
    action: "Continue monitoring"
  };
}
```

### Lead Score Alerts

```javascript
if (averageLeadScore < 50) {
  alert = {
    level: "🚨 CRITICAL",
    message: "Low-quality traffic (avg score: " + averageLeadScore + ")",
    action: "Review ad targeting and landing page relevance"
  };
} else if (averageLeadScore < 70) {
  alert = {
    level: "⚠️ WARNING",
    message: "Moderate engagement (avg score: " + averageLeadScore + ")",
    action: "Test engagement improvements"
  };
}
```

### Funnel Bottleneck Alerts

```javascript
stages.forEach(stage => {
  if (stage.dropoffRate > 0.60) {
    alert = {
      level: "🚨 CRITICAL",
      stage: stage.name,
      message: "Critical drop-off: " + (stage.dropoffRate * 100) + "%",
      action: "Immediate A/B testing required"
    };
  } else if (stage.dropoffRate > 0.40) {
    alert = {
      level: "⚠️ WARNING",
      stage: stage.name,
      message: "High drop-off: " + (stage.dropoffRate * 100) + "%",
      action: "Optimize this stage"
    };
  }
});
```

---

## References

**Related Documentation:**
- Agent README: `README.md`
- Agent Configuration: `agent.json`
- Skills Used: `/lead-funnel-analysis`, `/google-ads-performance`
- Event Tracking: LEAD_GENERATION_EVENTS (@akson/cortex-utilities)

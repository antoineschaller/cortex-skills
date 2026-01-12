# lead-quality-optimizer

Weekly lead quality analysis and conversion funnel optimization agent.

## Purpose

Optimize lead generation effectiveness through data-driven funnel analysis:
- **Weekly analysis (Monday 9am CET)**: Review previous week's lead quality
- **Funnel optimization**: Identify conversion bottlenecks
- **Lead scoring**: Track engagement quality (1-100 scale)
- **Conversion tracking**: Monitor lead→customer conversion rates
- **Recommendations**: Actionable improvements for each funnel stage

## Triggers

**Weekly Analysis (Monday 9am CET):**
- Review last 7 days of leads
- Calculate conversion rates per stage
- Identify bottlenecks and drop-off points
- Generate optimization recommendations

**Manual (On-Demand):**
```bash
node agents/marketing-intelligence/lead-quality-optimizer/run.js
```

**Custom Date Range:**
```bash
node run.js --days=14  # Analyze last 14 days
node run.js --from=2026-01-01 --to=2026-01-15
```

## Lead Quality Metrics

### 1. Conversion Rate

**Definition:** Percentage of leads that become paying customers

**Targets:**
- ✅ Target: ≥20% (1 in 5 leads converts)
- ⚠️ Warning: 15-19% (acceptable but suboptimal)
- ⚠️ Critical: 10-14% (needs immediate attention)
- 🚨 Critical: <10% (funnel broken)

**Calculation:**
```javascript
conversionRate = (paidCustomers / totalLeads) * 100
// Example: 25 customers / 150 leads = 16.7%
```

### 2. Lead Score (1-100)

**Definition:** Average engagement score across all leads

**Scoring System:**
- Page View: 5 points
- Content View: 15 points
- Inquiry Started: 40 points
- Contact Info: 60 points
- WhatsApp Contact: 85 points
- Form Submitted: 100 points

**Targets:**
- ✅ Target: ≥70 (high-quality leads)
- ⚠️ Warning: 50-69 (moderate engagement)
- 🚨 Critical: <50 (low-quality traffic)

### 3. Funnel Drop-off Rate

**Definition:** Percentage of leads lost at each funnel stage

**Acceptable Drop-offs:**
- Page View → Content View: 40-50% (normal)
- Content View → Inquiry Started: 30-40% (acceptable)
- Inquiry Started → Contact Info: 20-30% (needs optimization if higher)
- Contact Info → Submission: 10-20% (critical if higher)

**Alert Thresholds:**
- ⚠️ Warning: >40% drop at any single stage
- 🚨 Critical: >60% drop at any single stage

### 4. Time to Conversion

**Definition:** Days from first lead capture to paid order

**Targets:**
- ✅ Target: ≤7 days (fast conversion)
- ⚠️ Warning: 8-14 days (needs nurturing optimization)
- ⚠️ Critical: 15-21 days (long sales cycle)
- 🚨 Critical: >21 days (review entire funnel)

### 5. Form Completion Rate

**Definition:** Percentage completing full contact form after starting

**Targets:**
- ✅ Target: ≥60% (good form UX)
- ⚠️ Warning: 45-59% (form friction present)
- 🚨 Critical: <45% (major form issues)

## Funnel Stages

### Stage 1: Page View (Score: 5)
**Event:** `lead_page_view`
**Description:** User lands on product/inquiry page

**Optimization Focus:**
- SEO for military keywords
- Ad copy relevance
- Landing page speed

### Stage 2: Content View (Score: 15)
**Event:** `lead_content_view`
**Description:** User engages with product content

**Optimization Focus:**
- Product image quality
- Compelling copy
- Social proof (reviews, testimonials)

### Stage 3: Inquiry Started (Score: 40)
**Event:** `lead_inquiry_started`
**Description:** User opens contact form

**Optimization Focus:**
- Clear CTA placement
- Value proposition clarity
- Trust signals (security, privacy)

### Stage 4: Contact Info (Score: 60)
**Event:** `lead_contact_info`
**Description:** User provides email/phone

**Optimization Focus:**
- Form field reduction
- Progress indicators
- Mobile UX

### Stage 5: WhatsApp Contact (Score: 85)
**Event:** `lead_whatsapp_contact`
**Description:** User initiates WhatsApp conversation

**Optimization Focus:**
- WhatsApp CTA prominence
- Response time expectations
- Conversation templates

### Stage 6: Form Submitted (Score: 100)
**Event:** `lead_form_submitted`
**Description:** Complete inquiry submitted

**Optimization Focus:**
- Follow-up speed (target: <2 hours)
- Personalized responses
- Conversion nurturing

## Tools Used

**Skills Executed:**
1. `/lead-funnel-analysis` - Extract lead journey data from Supabase
2. `/google-ads-performance` - Compare paid vs organic lead quality
3. `/marketing-health-check` - Verify tracking system health
4. `@akson/cortex-analytics posthog` - Event tracking validation

## Configuration

**Target Metrics:**
```json
{
  "targetConversionRate": 0.20,
  "minConversionRate": 0.10,
  "targetLeadScore": 70,
  "analysisWindowDays": 7,
  "minimumSampleSize": 50
}
```

**Analysis Window:**
- Default: Last 7 days
- Minimum sample size: 50 leads (alert if below)
- Compares to previous period for trend analysis

## Output

**Weekly Reports:**
- File: `landing/docs/wip/optimizer-weekly-{YYYY-MM-DD}.json`
- Contains: Conversion metrics, funnel analysis, recommendations

**Funnel Analysis:**
- File: `landing/docs/wip/funnel-analysis-{YYYY-MM-DD}.json`
- Contains: Stage-by-stage breakdown, drop-off points, heat map data

**Slack Notifications:**
- Channel: `#marketing-alerts`
- Priority-coded: 🚨 Critical, ⚠️ Warning, ℹ️ Info

## Example Weekly Report

```json
{
  "date": "2026-01-12",
  "type": "weekly",
  "period": {
    "from": "2026-01-05",
    "to": "2026-01-12",
    "days": 7
  },
  "overview": {
    "totalLeads": 165,
    "paidCustomers": 28,
    "conversionRate": 0.17,
    "averageLeadScore": 62,
    "status": "warning"
  },
  "funnelBreakdown": [
    {
      "stage": "page_view",
      "count": 850,
      "percentage": 100.0,
      "nextStageConversion": 0.52,
      "avgTimeToNext": "45 seconds"
    },
    {
      "stage": "content_view",
      "count": 442,
      "percentage": 52.0,
      "nextStageConversion": 0.42,
      "avgTimeToNext": "3.5 minutes"
    },
    {
      "stage": "inquiry_started",
      "count": 186,
      "percentage": 21.9,
      "nextStageConversion": 0.75,
      "avgTimeToNext": "1.2 minutes"
    },
    {
      "stage": "contact_info",
      "count": 140,
      "percentage": 16.5,
      "nextStageConversion": 0.48,
      "avgTimeToNext": "2.5 hours"
    },
    {
      "stage": "whatsapp_contact",
      "count": 67,
      "percentage": 7.9,
      "nextStageConversion": 0.82,
      "avgTimeToNext": "4.2 hours"
    },
    {
      "stage": "form_submitted",
      "count": 55,
      "percentage": 6.5,
      "nextStageConversion": 0.51,
      "avgTimeToNext": "3.8 days"
    }
  ],
  "bottlenecks": [
    {
      "stage": "content_view → inquiry_started",
      "dropoffRate": 0.58,
      "severity": "critical",
      "reason": "High drop-off between content view and inquiry (58%)"
    },
    {
      "stage": "contact_info → whatsapp_contact",
      "dropoffRate": 0.52,
      "severity": "warning",
      "reason": "Half of leads don't proceed to WhatsApp after providing contact info"
    }
  ],
  "recommendations": [
    {
      "priority": "critical",
      "stage": "content_view",
      "action": "Improve CTA visibility and value proposition",
      "expectedImpact": "+10% inquiry starts → +18 leads/week"
    },
    {
      "priority": "warning",
      "stage": "contact_info",
      "action": "Add WhatsApp CTA immediately after email capture",
      "expectedImpact": "+15% WhatsApp contacts → +11 leads/week"
    },
    {
      "priority": "info",
      "stage": "form_submitted",
      "action": "Reduce response time to <2 hours",
      "expectedImpact": "+5% conversion rate"
    }
  ],
  "trends": {
    "vsLastWeek": {
      "conversionRate": -0.03,
      "leadScore": -5,
      "direction": "declining"
    }
  }
}
```

## Alert Scenarios

### Scenario 1: Low Conversion Rate

```
⚠️ Conversion Rate Below Target

Current: 12% (Target: 20%)
Trend: -3% vs last week

📉 Funnel Performance:
- Page View → Content: 52% (acceptable)
- Content → Inquiry: 42% (BOTTLENECK)
- Inquiry → Contact Info: 75% (good)
- Contact → WhatsApp: 48% (needs work)
- WhatsApp → Submission: 82% (excellent)
- Submission → Paid: 51% (acceptable)

🎯 Recommendations:
1. Critical: Improve content engagement (add video demos)
2. Warning: Optimize WhatsApp CTA placement
3. Info: Test shorter contact forms

Expected Impact: +5-8% conversion rate improvement
```

### Scenario 2: Funnel Bottleneck Detected

```
🚨 CRITICAL: Major Funnel Bottleneck

Stage: Contact Info → WhatsApp Contact
Drop-off: 68% (Critical threshold: 60%)
Impact: Losing 95 potential leads/week

📊 Analysis:
- Users provide email/phone but don't click WhatsApp
- Average time at stage: 2.5 hours
- Hypothesis: CTA not prominent enough after form submission

🛑 Immediate Actions:
1. Add pop-up WhatsApp CTA after email capture
2. Include WhatsApp in confirmation email
3. Test auto-redirect to WhatsApp after form submit

Expected Recovery: 68% → 45% drop-off (+32 leads/week)
```

### Scenario 3: Low Lead Quality

```
⚠️ Lead Quality Warning

Average Lead Score: 45 (Target: 70)
Quality: Low engagement, high bounce

📊 Breakdown:
- 80% of leads: Score ≤40 (page view only)
- 15% of leads: Score 40-60 (some engagement)
- 5% of leads: Score >60 (high quality)

Root Causes:
1. Broad targeting bringing unqualified traffic
2. Generic ad copy attracting wrong audience
3. Landing page mismatch with ad promises

🔧 Recommended Actions:
1. Narrow Google Ads targeting to military keywords only
2. Update ad copy to highlight Swiss military focus
3. Add qualification questions early in funnel
4. Consider lead magnets for qualified visitors

Expected Impact: Lead score 45 → 65, conversion rate +5%
```

## Slack Alert Examples

**Weekly Summary (Info):**
```
ℹ️ Weekly Lead Quality Report - Week of Jan 5

📊 Overview:
   Leads: 165
   Conversion: 17% (Target: 20%)
   Lead Score: 62 (Target: 70)

🎯 Top Bottleneck:
   Content View → Inquiry: 58% drop-off
   Impact: -30 leads/week

💡 Key Recommendation:
   Improve CTA visibility on product pages
   Expected: +10% inquiry starts

Full report: optimizer-weekly-2026-01-12.json
```

**Critical Alert:**
```
🚨 CRITICAL: Conversion Rate 9%

Current: 9% (Target: 20%, Minimum: 10%)
Status: Below minimum threshold
Trend: Declining for 3 weeks

📉 Funnel Health:
   Major bottleneck: Content → Inquiry (72% drop)
   Lead quality: Low (avg score: 42)

🛑 IMMEDIATE ACTIONS REQUIRED:
1. Review ad targeting - likely attracting wrong audience
2. Test new landing page layouts
3. Add qualification questions to filter leads
4. Consider pausing lowest-quality campaigns

⏰ Review and implement within 48 hours
```

## Troubleshooting

**"Conversion rate seems incorrect"**
- Verify Supabase lead data is current (run /lead-funnel-analysis)
- Check if orders are properly linked to leads
- Validate lead scoring events in PostHog
- Ensure minimum sample size met (50+ leads)

**"Funnel stages not tracking"**
- Run /marketing-health-check to verify PostHog integration
- Check GTM tag firing for lead events
- Validate event names match LEAD_GENERATION_EVENTS constants
- Review browser console for tracking errors

**"WhatsApp conversions not captured"**
- Verify lead_whatsapp_contact event is firing
- Check if phone numbers are being captured correctly
- Validate WhatsApp CTA click tracking
- Test on mobile devices (primary WhatsApp usage)

**"Lead scores all showing 5"**
- Indicates only page views are tracked
- Check if content_view, inquiry_started events are firing
- Validate GTM triggers for form interactions
- Test user journey from landing to submission

## Best Practices

1. **First Analysis**: Review last 30 days to establish baseline
2. **Weekly Rhythm**: Run Monday morning, implement changes by Friday
3. **Minimum Sample**: Wait for 50+ leads before drawing conclusions
4. **A/B Testing**: Test one optimization at a time to measure impact
5. **Trend Tracking**: Compare week-over-week for meaningful insights

## Related Agents

- **marketing-strategist**: Uses lead quality data for budget allocation
- **budget-guardian**: Alerts when CAC increases (may indicate quality issues)

## Underlying Implementation

Agent execution flow:
1. Fetch lead data from Supabase (last 7 days)
2. Calculate conversion rates per funnel stage
3. Identify bottlenecks (>40% drop-off)
4. Calculate average lead scores
5. Generate optimization recommendations
6. Compare to previous period for trends
7. Save funnel analysis JSON
8. Send Slack notification if thresholds breached

See `quality-metrics.md` for detailed metric definitions.

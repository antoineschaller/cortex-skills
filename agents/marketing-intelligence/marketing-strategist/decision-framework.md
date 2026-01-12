# marketing-strategist Decision Framework

Detailed decision logic for autonomous marketing budget optimization.

---

## Decision Tiers Overview

Three-tier system based on risk and impact:

1. **Auto-Execute**: Low-risk, routine optimizations
2. **Request Approval**: Medium-risk, significant changes
3. **Alert Immediately**: Critical issues requiring urgent action

---

## Tier 1: Auto-Execute

**Philosophy**: Routine optimizations within safe thresholds, proven to work.

### Conditions (ALL must be met):

```javascript
{
  cacDeviation: Math.abs((actualCAC - targetCAC) / targetCAC) < 0.10,  // Within 10%
  roasWithinRange: actualROAS >= 2.0,                                    // At least 2x
  budgetCompliance: actualSpend >= budgetedSpend * 0.90 &&              // 90-110%
                    actualSpend <= budgetedSpend * 1.10
}
```

### Example Scenarios:

**Scenario A: Healthy Performance**
```
Current Metrics:
- Actual CAC: CHF 14.85
- Target CAC: CHF 15.00
- Deviation: -1% (within 10%)
- ROAS: 3.2x (above 2.0x minimum)
- Budget: CHF 2,450 spent / CHF 2,500 budgeted (98%)

Decision: AUTO-EXECUTE
Actions:
1. Generate weekly performance report
2. Update seasonal multipliers if needed
3. Create next week's recommendations
4. Send ℹ️ INFO Slack notification
```

**Scenario B: Slight Over-Budget but High ROI**
```
Current Metrics:
- Actual CAC: CHF 14.20
- Target CAC: CHF 15.00
- Deviation: -5.3% (within 10%)
- ROAS: 4.1x (strong performance)
- Budget: CHF 2,720 spent / CHF 2,500 budgeted (109%)

Decision: AUTO-EXECUTE
Actions:
1. Document over-budget with justification (high ROAS)
2. Recommend continued strategy
3. Note: May need approval next week if trend continues
```

### Skills Executed (Auto-Execute Flow):

```bash
# 1. Fetch current data
/revenue-analysis
/google-ads-performance
/lead-funnel-analysis

# 2. Generate recommendations
/seasonal-budget-advisor

# 3. Validate health
/marketing-health-check

# 4. Calculate next period
/budget-calculator --scenario=moderate
```

---

## Tier 2: Request Approval

**Philosophy**: Significant changes with measurable impact, requires human review.

### Conditions (ANY can trigger):

```javascript
{
  budgetReallocation: Math.abs(proposedShift) > 0.15,     // >15% shift
  cacSpike: (actualCAC - baselineCAC) / baselineCAC > 0.20,  // >20% increase
  newCampaigns: proposing new campaign launches
}
```

### Example Scenarios:

**Scenario C: Budget Reallocation Recommendation**
```
Current Performance:
- Google Ads CAC: CHF 18.50 (target: CHF 15.00) - 23% over
- Email Nurturing CAC: CHF 8.20 (target: CHF 15.00) - strong
- Proposed Action: Shift 20% from Google Ads → Email

Analysis:
- budgetReallocation = 0.20 (20% shift) > 0.15 threshold

Decision: REQUEST APPROVAL
Slack Message:
⚠️ Budget Reallocation Recommendation

Current Performance:
• Google Ads CAC: CHF 18.50 (Target: CHF 15)
• Email CAC: CHF 8.20

Recommendation:
• Shift 20% budget from Google Ads → Email
• Expected CAC improvement: CHF 18.50 → CHF 15.80
• Impact: +12 leads/month

⏰ Approval Required - React ✅ to approve, ❌ to reject

Cost-Benefit Analysis:
- Current: 100 leads at CHF 18.50 = CHF 1,850
- Proposed: 112 leads at CHF 15.80 = CHF 1,770
- Savings: CHF 80/month + 12 more leads
```

**Scenario D: CAC Spike Detection**
```
Current Metrics:
- Baseline CAC (7-day avg): CHF 14.80
- Today's CAC: CHF 18.50
- Spike: 25% increase (>20% threshold)

Analysis:
- cacSpike = 0.25 (25%) > 0.20 threshold

Decision: REQUEST APPROVAL
Slack Message:
⚠️ CAC Spike Detected - Action Needed

CAC increased from CHF 14.80 → CHF 18.50 (+25%)

Possible Causes:
1. Increased competition on key keywords
2. Seasonal demand changes
3. Ad creative fatigue

Recommendations:
1. Pause underperforming campaigns (CAC >CHF 20)
2. Test new ad creative variants
3. Increase budget for retargeting (lower CAC)

Expected Impact: CAC reduction to CHF 15-16 within 3 days

⏰ Approval Required - Select action to take
```

**Scenario E: New Campaign Proposal**
```
Opportunity Identified:
- Swiss Army recruitment season starting in March
- Historical data shows 2.3x higher conversion rates
- Competitor ads decreasing (low competition window)

Proposal:
- Launch "Rekrutenschule Souvenir" campaign
- Budget: CHF 500 (10% of monthly budget)
- Target: 35 leads at CHF 14.29 CAC

Analysis:
- newCampaigns = true

Decision: REQUEST APPROVAL
Slack Message:
⚠️ New Campaign Proposal - March Peak Season

Opportunity:
• Swiss Army recruitment season (March-April)
• 2.3x higher conversion rate historically
• Low competitor activity detected

Proposed Campaign:
• Name: "Rekrutenschule Souvenir 2026"
• Budget: CHF 500 (10% of monthly)
• Expected: 35 leads at CHF 14.29
• Duration: 4 weeks

ROI Forecast:
- Conservative: 28 leads at CHF 17.86 = -CHF 100
- Moderate: 35 leads at CHF 14.29 = +CHF 25
- Aggressive: 45 leads at CHF 11.11 = +CHF 190

⏰ Approval Required - Budget allocation needed
```

### Skills Executed (Request Approval Flow):

```bash
# 1. Fetch comprehensive data
/revenue-analysis
/google-ads-performance
/lead-funnel-analysis
/seo-performance

# 2. Generate detailed recommendations
/seasonal-budget-advisor --month=03
/budget-calculator --scenario=moderate

# 3. Cost-benefit analysis
/budget-calculator --scenario=conservative
/budget-calculator --scenario=aggressive

# 4. Wait for Slack approval
# (Human responds with ✅ or ❌)

# 5. If approved, execute changes
# (Not implemented yet - manual execution for now)
```

---

## Tier 3: Alert Immediately

**Philosophy**: Critical issues threatening profitability, requires immediate action.

### Conditions (ANY can trigger):

```javascript
{
  cacExceeds: actualCAC > 20.0,                           // Above CHF 20
  roasBelow: actualROAS < 2.0,                            // Below 2x (unsustainable)
  budgetOverrun: (actualSpend - budgetedSpend) / budgetedSpend > 0.50  // >50% over
}
```

### Example Scenarios:

**Scenario F: Critical CAC Threshold**
```
Current Metrics:
- Actual CAC: CHF 22.50
- Target CAC: CHF 15.00
- Deviation: +50% above target
- Trend: Increasing for 3 consecutive days

Analysis:
- cacExceeds = 22.50 > 20.0 threshold

Decision: ALERT IMMEDIATELY
Slack Message:
🚨 CRITICAL: CAC Exceeded Threshold

Current CAC: CHF 22.50 (Target: CHF 15.00)
Deviation: +50% above target
Trend: Increasing for 3 consecutive days

🛑 Immediate Actions Recommended:
1. Pause underperforming campaigns immediately
2. Reduce Google Ads daily cap by 40% (CHF 120 → CHF 72)
3. Shift budget to retargeting (CAC: CHF 9.80)

Expected Impact:
- CAC reduction to CHF 16-17 within 48h
- Spend reduction: CHF 480/week
- Lead volume: -15% short-term, recover in 1 week

⏰ IMMEDIATE RESPONSE REQUIRED
Campaign pause recommended within 2 hours
```

**Scenario G: ROAS Below Minimum**
```
Current Metrics:
- Actual ROAS: 1.7x
- Target ROAS: 3.0x
- Minimum ROAS: 2.0x
- Status: Below minimum (unsustainable)

Analysis:
- roasBelow = 1.7 < 2.0 threshold

Decision: ALERT IMMEDIATELY
Slack Message:
🚨 CRITICAL: ROAS Below Minimum Threshold

Current ROAS: 1.7x (Minimum: 2.0x)
For every CHF 1 spent, earning CHF 1.70
This is UNSUSTAINABLE - losing money after overhead

Root Cause Analysis:
1. High CAC (CHF 19.20) + Low conversion rate (12%)
2. Targeting too broad (wasting budget)
3. Ad creative underperforming

🛑 Emergency Actions:
1. Pause all campaigns with ROAS <1.5x immediately
2. Narrow targeting to high-intent keywords only
3. Activate retargeting campaigns (ROAS: 3.8x)
4. Reduce daily budget by 50% until ROAS recovers

Expected Recovery:
- Week 1: ROAS improves to 2.2x
- Week 2: ROAS stabilizes at 2.8x
- Week 3: Resume normal budget levels

⏰ CAMPAIGN PAUSE REQUIRED WITHIN 1 HOUR
```

**Scenario H: Budget Overrun**
```
Current Status:
- Budgeted: CHF 2,500 for the month
- Actual Spend: CHF 4,200 (with 10 days remaining)
- Overrun: 68% over budget

Analysis:
- budgetOverrun = (4200 - 2500) / 2500 = 0.68 (68%) > 0.50 threshold

Decision: ALERT IMMEDIATELY
Slack Message:
🚨 CRITICAL: Budget Overrun 68%

Month: January 2026 (10 days remaining)
Budgeted: CHF 2,500
Actual Spend: CHF 4,200
Overrun: CHF 1,700 (68% over)

Projection:
At current rate, will spend CHF 6,800 total (172% over)

Root Cause:
1. Daily cap not enforced (spending CHF 140/day vs CHF 83 planned)
2. Multiple campaigns activated simultaneously
3. No budget alerts configured in Google Ads

🛑 Immediate Actions:
1. Set hard daily cap: CHF 83/day immediately
2. Pause 3 lowest-performing campaigns
3. Implement daily budget monitoring

Expected Impact:
- Remaining 10 days: CHF 830 spend (vs CHF 1,400 at current rate)
- Total month: CHF 5,030 (101% of budget) - acceptable
- Leads: -20% for remainder of month

⏰ DAILY CAP MUST BE SET WITHIN 30 MINUTES
Financial risk if not addressed immediately
```

### Skills Executed (Alert Immediately Flow):

```bash
# 1. Fetch real-time data
/google-ads-performance
/lead-funnel-analysis
/marketing-health-check

# 2. Root cause analysis
/seasonal-budget-advisor
/seo-performance  # Check if organic is affected

# 3. Generate emergency plan
/budget-calculator --scenario=conservative

# 4. Send CRITICAL alert
# (Slack with 🚨 prefix)

# 5. Monitor recovery
# (Re-run checks every 4 hours until resolved)
```

---

## Integration with Skills

**Weekly Performance Review (Friday 5pm):**

```bash
# Step 1: Data Collection (5 skills)
/revenue-analysis              # Load historical patterns
/google-ads-performance        # Last 7 days spend + CAC
/lead-funnel-analysis          # Conversion rates
/seo-performance               # Organic traffic check
/event-tracking-health         # GTM/PostHog validation

# Step 2: Analysis (2 skills)
/seasonal-budget-advisor       # Current vs target performance
/marketing-health-check        # System health validation

# Step 3: Decision Logic
if (allConditionsMet(autoExecute)) {
  generateWeeklyReport();
  updateSeasonalMultipliers();
  createNextWeekRecommendations();
  sendSlackInfo();
}
else if (anyConditionMet(requestApproval)) {
  generateDetailedAnalysis();
  createCostBenefitBreakdown();
  sendSlackWarning();
  waitForApproval();
}
else if (anyConditionMet(alertImmediately)) {
  identifyRootCause();
  generateEmergencyPlan();
  sendSlackCritical();
  executeImmediateActions();
}

# Step 4: Output
# - JSON report saved to: docs/wip/strategist-weekly-YYYY-MM-DD.json
# - Slack notification sent to: #marketing-alerts
```

**Monthly Budget Planning (1st at 9am):**

```bash
# Step 1: Previous Month Analysis
/revenue-analysis              # Last month revenue
/google-ads-performance        # Last 30 days spend
/lead-funnel-analysis          # Last month conversions
/airtable-orders               # Order data validation

# Step 2: Next Month Planning
/budget-calculator --scenario=moderate  # Base allocation
/seasonal-budget-advisor --month=02     # Seasonal adjustments

# Step 3: Generate Monthly Plan
# - Next month budget allocation
# - Channel reallocation recommendations
# - Expected results (leads, CAC, ROAS)
# - Optimization opportunities

# Step 4: Output
# - JSON report saved to: docs/wip/strategist-monthly-YYYY-MM.json
# - Slack notification with monthly plan
```

---

## Thresholds Summary

| Metric | Auto-Execute | Request Approval | Alert Immediately |
|--------|--------------|------------------|-------------------|
| CAC Deviation | <10% | 10-33% | >33% (>CHF 20) |
| ROAS | ≥2.0x | 2.0-2.5x | <2.0x |
| Budget Compliance | 90-110% | 110-150% | >150% |
| Budget Reallocation | <15% | 15-25% | >25% |
| CAC Spike | <20% | 20-33% | >33% |

---

## False Positive Prevention

**Monthly Threshold Review:**
- Track decision accuracy (was alert justified?)
- Adjust thresholds if false positive rate >5%
- Document threshold changes with reasoning

**Seasonal Adjustments:**
- Q4 peak season (Oct-Dec): Increase CAC threshold to CHF 17
- Q1 low season (Jan-Mar): Decrease budget overrun threshold to 40%
- Recruitment season (Mar-Apr, Sep): Adjust conversion rate expectations

**First Month Calibration:**
- Run in alert-only mode (no auto-execute)
- Review all decisions manually
- Fine-tune thresholds based on real data
- Enable auto-execute after 4 weeks of validation

---

## Audit Trail

Every decision creates JSON record:

```json
{
  "timestamp": "2026-01-12T17:00:00Z",
  "decisionTier": "requestApproval",
  "trigger": "budgetReallocation",
  "conditions": {
    "budgetReallocation": 0.20,
    "threshold": 0.15,
    "exceeded": true
  },
  "recommendation": {
    "action": "Shift 20% from Google Ads to Email",
    "expectedImpact": "+12 leads/month, -CHF 80 CAC",
    "costBenefit": "positive"
  },
  "humanDecision": "approved",
  "executedAt": "2026-01-12T18:30:00Z",
  "outcome": {
    "actualImpact": "+14 leads/month, -CHF 95 CAC",
    "accuracyScore": 0.95
  }
}
```

This enables continuous improvement of decision thresholds.

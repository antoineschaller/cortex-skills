# marketing-strategist

Autonomous marketing budget optimization agent with weekly performance reviews and monthly planning.

## Purpose

Continuously monitors marketing performance and optimizes budget allocation:
- Weekly performance analysis (every Friday 5pm)
- Monthly budget planning (1st of month at 9am)
- Automatic budget reallocation recommendations
- Channel performance optimization
- CAC and ROAS monitoring

## Triggers

**Weekly Review (Friday 5pm CET):**
- Analyzes last 7 days performance
- Compares to weekly targets
- Recommends adjustments for next week
- Identifies underperforming channels

**Monthly Planning (1st at 9am CET):**
- Reviews previous month performance
- Generates next month's budget allocation
- Updates seasonal multipliers if patterns changed
- Plans major optimizations

**Manual (On-Demand):**
```bash
node agents/marketing-intelligence/marketing-strategist/run.js
```

## Decision Framework

### Auto-Execute (No Approval Needed)

**Conditions:**
- CAC deviation <10% from CHF 15 target
- ROAS ≥2x (minimum acceptable)
- Budget utilization 90-110%

**Actions:**
- Generate performance reports
- Update seasonal multipliers
- Create recommendations for next period

### Request Approval (Medium Risk)

**Conditions:**
- Budget reallocation >15%
- CAC spike >20% from baseline
- New campaign proposals

**Actions:**
- Send Slack notification with detailed analysis
- Wait for user approval
- Provide cost-benefit breakdown

### Alert Immediately (Critical)

**Conditions:**
- CAC >CHF 20 (critical threshold)
- ROAS <2x (unsustainable)
- Budget overrun >50%

**Actions:**
- 🚨 CRITICAL Slack alert
- Recommend immediate campaign pause
- Suggest emergency reallocation

## Tools Used

**Skills Executed:**
1. `/google-ads-performance` - Fetch last 30 days spend/CAC
2. `/lead-funnel-analysis` - Analyze conversion rates
3. `/seasonal-budget-advisor` - Generate recommendations
4. `/revenue-analysis` - Load historical patterns
5. `/budget-calculator` - Calculate expected results

## Configuration

**Target Metrics:**
```json
{
  "targetCAC": 15.0,          // CHF per lead
  "targetROAS": 3.0,          // 3x return on ad spend
  "minROAS": 2.0,             // Minimum acceptable
  "targetConversionRate": 0.20, // 20% leads → customers
  "budgetDeviationThreshold": 0.15,  // 15% before approval
  "cacDeviationThreshold": 0.10      // 10% before alert
}
```

## Output

**Weekly Reports:**
- File: `landing/docs/wip/strategist-weekly-{YYYY-MM-DD}.json`
- Contains: Performance summary, channel breakdown, recommendations

**Monthly Plans:**
- File: `landing/docs/wip/strategist-monthly-{YYYY-MM}.json`
- Contains: Next month budget, expected results, optimization plan

**Slack Notifications:**
- Channel: `#marketing-alerts`
- Priority-coded messages (🚨 Critical, ⚠️ Warning, ℹ️ Info)

## Example Weekly Report

```json
{
  "date": "2026-01-12",
  "type": "weekly",
  "period": {
    "from": "2026-01-05",
    "to": "2026-01-12"
  },
  "performance": {
    "spend": 2450.75,
    "leads": 165,
    "cac": 14.85,
    "cacTarget": 15.00,
    "cacDeviation": -0.01,
    "roas": 3.2
  },
  "status": "healthy",
  "decision": "auto_execute",
  "recommendations": [
    {
      "priority": "success",
      "action": "Continue current strategy",
      "reason": "CAC within target, ROAS exceeds 3x"
    },
    {
      "priority": "info",
      "action": "Increase Google Ads budget by 5%",
      "reason": "Strong performance, room for growth"
    }
  ],
  "nextSteps": [
    "Monitor CAC daily next week",
    "Test new ad creative variants",
    "Prepare for March peak season"
  ]
}
```

## Example Monthly Plan

```json
{
  "date": "2026-02-01",
  "type": "monthly",
  "month": "February",
  "previousMonth": {
    "budgeted": 5271.0,
    "actual": 5180.50,
    "variance": -1.7,
    "leads": 345,
    "avgCAC": 15.01
  },
  "nextMonth": {
    "budgeted": 5271.0,
    "strategy": "steady",
    "expectedLeads": 351,
    "targetCAC": 15.00,
    "channelAllocation": {
      "googleAds": 3426.15,      // 65%
      "emailNurturing": 1054.20,  // 20%
      "growthChannels": 790.65    // 15%
    }
  },
  "optimizations": [
    {
      "channel": "Google Ads",
      "action": "Increase daily cap to CHF 120",
      "expectedImpact": "+8% leads"
    },
    {
      "channel": "Email",
      "action": "Launch nurture sequence for January leads",
      "expectedImpact": "+5% conversion rate"
    }
  ]
}
```

## Slack Alert Examples

**Weekly Summary (Info):**
```
ℹ️ Weekly Performance Summary - Week of Jan 5

✅ CAC: CHF 14.85 (Target: CHF 15.00) - On track
✅ ROAS: 3.2x (Target: 3.0x) - Exceeding target
✅ Leads: 165 (Expected: 160) - Above plan

💡 Recommendation: Continue current strategy
🎯 Next Week: Monitor daily, prepare March campaigns
```

**Budget Reallocation (Warning):**
```
⚠️ Budget Reallocation Recommendation

Current Performance:
• Google Ads CAC: CHF 18.50 (Target: CHF 15)
• Email CAC: CHF 8.20

Recommendation:
• Shift 15% budget from Google Ads → Email
• Expected CAC improvement: CHF 18.50 → CHF 15.80

⏰ Approval Required - React to approve/reject
```

**Critical Alert:**
```
🚨 CRITICAL: CAC Exceeded Threshold

Current CAC: CHF 22.50 (Target: CHF 15.00)
Deviation: +50% above target
Trend: Increasing for 3 consecutive days

🛑 Immediate Actions Recommended:
1. Pause underperforming campaigns
2. Reduce Google Ads daily cap by 40%
3. Shift budget to retargeting (lower CAC)

Expected Impact: CAC reduction to CHF 16-17 within 48h

⏰ Immediate Response Required
```

## Troubleshooting

**"Agent not triggering on schedule"**
- Check cron configuration
- Verify timezone setting (Europe/Zurich)
- Test manual run first: `node run.js --test-mode`

**"Slack notifications not sent"**
- Verify SLACK_WEBHOOK_URL in .env
- Test webhook: `curl -X POST $SLACK_WEBHOOK_URL -d '{"text":"Test"}'`
- Check webhook permissions for #marketing-alerts channel

**"Recommendations seem incorrect"**
- Verify input data freshness (run /marketing-health-check)
- Check decision framework thresholds in agent.json
- Review last 7 days of data for anomalies

**"Auto-execute not working"**
- Confirm all conditions met (CAC <10%, ROAS >2x, budget 90-110%)
- Check decision logic in decision-framework.md
- Review logs for threshold violations

## Best Practices

1. **First Month**: Run in alert-only mode (disable auto-execute)
2. **Review Decisions**: Check weekly reports for first 4 weeks
3. **Adjust Thresholds**: Fine-tune based on real performance
4. **Monitor False Positives**: Target <5% false alert rate
5. **Seasonal Adjustments**: Update thresholds for peak seasons

## Related Agents

- **budget-guardian**: Monitors same data, different frequency (daily vs weekly)
- **lead-quality-optimizer**: Focuses on lead quality, not budget

## Underlying Implementation

Agent execution flow:
1. Run all configured skills to gather data
2. Apply decision framework to data
3. Determine action level (auto/approval/alert)
4. Generate recommendations
5. Save JSON report
6. Send Slack notification (if configured)
7. Execute auto-approved actions (if applicable)

See `decision-framework.md` for detailed decision logic.

# budget-guardian

Daily budget monitoring agent with real-time threshold alerts and spend tracking.

## Purpose

Continuous budget monitoring and early warning system:
- **Daily checks (8am CET)**: Review previous day's spend
- **Budget tracking**: Monitor monthly spend vs allocation
- **Threshold alerts**: Immediate notifications when limits approached
- **CAC monitoring**: Daily cost per acquisition tracking
- **Real-time insights**: 4-hour check intervals during business hours

## Triggers

**Daily Check (8am CET):**
- Review previous day performance
- Calculate month-to-date spend
- Compare to budget allocation
- Send daily digest

**Manual (On-Demand):**
```bash
node agents/marketing-intelligence/budget-guardian/run.js
```

**Real-Time Mode:**
```bash
node agents/marketing-intelligence/budget-guardian/run.js --real-time
# Checks every 4 hours until stopped
```

## Alert Rules

### Budget Thresholds

**⚠️ WARNING (80% of monthly budget):**
- Notification sent to Slack
- Budget status: "approaching limit"
- Recommended action: Monitor closely, prepare for slowdown

**🚨 CRITICAL (90% of monthly budget):**
- Urgent Slack alert
- Budget status: "critical"
- Recommended action: Reduce daily caps immediately

**🛑 EXCEEDED (100% of monthly budget):**
- Emergency alert
- Budget status: "exceeded"
- Recommended action: Pause non-essential campaigns

### CAC Thresholds

**⚠️ WARNING (CHF 17-20):**
- CAC above target but manageable
- 3+ consecutive days triggers alert
- Recommended action: Review targeting and creative

**🚨 CRITICAL (CHF 20+):**
- CAC unsustainable
- Immediate alert on first occurrence
- Recommended action: Pause underperforming campaigns

### Daily Spend Thresholds

**Expected Daily Rate:** Monthly Budget / Days in Month

**⚠️ WARNING (120% of expected):**
- Spending faster than planned
- Will exhaust budget before month-end
- Recommended action: Reduce daily caps by 10-15%

**🚨 CRITICAL (150% of expected):**
- Severe overspending
- Budget will be exhausted within days
- Recommended action: Immediate 30% budget cut

### ROAS Thresholds

**⚠️ WARNING (2.0x - 2.5x):**
- Below target ROAS of 3x
- Still profitable but suboptimal
- Recommended action: Optimize campaigns, test new creative

**🚨 CRITICAL (Below 2.0x):**
- Minimum ROAS threshold breached
- Unsustainable performance
- Recommended action: Pause lowest-performing campaigns

## Tools Used

**Skills Executed:**
1. `/google-ads-performance` - Current spend and CAC data
2. `/budget-calculator` - Monthly budget allocations
3. `/marketing-health-check` - System connectivity validation

## Configuration

**Target Metrics:**
```json
{
  "targetCAC": 15.0,
  "targetROAS": 3.0,
  "minROAS": 2.0,
  "checkIntervalHours": 4,
  "alertCooldownMinutes": 60
}
```

**Alert Cooldown:**
- Prevents alert spam
- Same alert type suppressed for 60 minutes
- Critical alerts override cooldown

## Output

**Daily Reports:**
- File: `landing/docs/wip/guardian-daily-{YYYY-MM-DD}.json`
- Contains: Spend summary, threshold status, alerts triggered

**Alert Log:**
- File: `landing/docs/wip/guardian-alerts.log`
- Contains: Timestamped alert history, actions taken

**Slack Notifications:**
- Channel: `#marketing-alerts`
- Priority-coded: 🚨 Critical, ⚠️ Warning, ℹ️ Info

## Example Daily Report

```json
{
  "date": "2026-01-12",
  "type": "daily",
  "monthToDate": {
    "daysElapsed": 12,
    "daysRemaining": 19,
    "budgeted": 5271.0,
    "spent": 3845.50,
    "percentage": 72.9,
    "status": "on_track"
  },
  "yesterday": {
    "date": "2026-01-11",
    "spent": 142.30,
    "expectedDailyRate": 170.03,
    "variance": -16.3,
    "cac": 15.80,
    "roas": 3.1
  },
  "alerts": [
    {
      "level": "info",
      "type": "budget",
      "message": "Budget on track: 73% spent with 61% of month elapsed"
    }
  ],
  "recommendations": [
    "Continue current spend rate",
    "Monitor CAC daily - currently CHF 15.80"
  ]
}
```

## Example Alert Scenarios

### Scenario 1: Budget Warning (80%)

```
⚠️ Budget Alert: 80% Spent

Monthly Budget: CHF 5,271.00
Spent to Date: CHF 4,216.80 (80%)
Days Elapsed: 12 / 31 (39%)

⚠️ Spending ahead of schedule!
Expected spend at day 12: CHF 2,044.50 (39%)
Actual spend: CHF 4,216.80 (80%)
Overspend: CHF 2,172.30 (+106%)

📊 Daily Rate Analysis:
Expected: CHF 170.03/day
Actual (last 7 days): CHF 280.50/day
Variance: +65%

⏰ At current rate:
- Budget exhausted by: Jan 19 (12 days early)
- Recommended daily cap: CHF 80/day

🔧 Recommended Actions:
1. Reduce daily budget to CHF 80 immediately
2. Pause 2-3 lowest-performing campaigns
3. Review targeting to reduce wasted spend
```

### Scenario 2: CAC Critical Alert

```
🚨 CRITICAL: CAC Exceeded CHF 20

Current CAC: CHF 22.40
Target CAC: CHF 15.00
Deviation: +49%

📈 Trend:
- 3 days ago: CHF 18.50
- 2 days ago: CHF 20.10
- Yesterday: CHF 22.40
- Status: WORSENING

💰 Impact:
- Spending CHF 22.40 to acquire leads worth CHF 45-60
- ROAS: 2.0x (minimum threshold)
- At target CAC (CHF 15), same budget would yield 49% more leads

🛑 Immediate Actions Required:
1. Pause campaigns with CAC >CHF 25 immediately
2. Reduce Google Ads daily cap by 30%
3. Activate retargeting campaigns (CAC: CHF 9.80)
4. Review ad creative performance (likely fatigued)

Expected Recovery: 2-3 days to CHF 16-18 range
```

### Scenario 3: Budget Exceeded

```
🚨 CRITICAL: Monthly Budget Exceeded

Monthly Budget: CHF 5,271.00
Current Spend: CHF 5,450.20
Overspend: CHF 179.20 (+3.4%)
Days Remaining: 8

🚨 BUDGET EXHAUSTED - CAMPAIGNS MAY PAUSE

At current rate (CHF 165/day):
- Will spend additional: CHF 1,320
- Total month: CHF 6,770.20 (29% over budget)

🛑 EMERGENCY ACTIONS (Execute within 2 hours):
1. Set hard daily cap: CHF 0 (pause all spend)
2. Review with leadership: extend budget or accept reduced leads
3. If budget extended: Set daily cap to approved amount
4. If not extended: Pause all campaigns until next month

Alternative: Reduced Spend Mode
- Daily cap: CHF 50/day (vs CHF 165 current)
- Expected additional spend: CHF 400
- Total month: CHF 5,850 (11% over budget)
- Lead reduction: -70% for remainder of month
```

## Slack Alert Examples

**Daily Digest (Info):**
```
ℹ️ Daily Budget Status - Jan 12

💰 Budget: CHF 3,846 / CHF 5,271 (73%)
   Status: ✅ On track

📊 Yesterday:
   Spend: CHF 142.30 (expected: CHF 170)
   CAC: CHF 15.80
   ROAS: 3.1x

🎯 Recommendations:
   Continue current strategy
   Budget remaining: CHF 1,425 (8 leads at current CAC)
```

**Warning Alert:**
```
⚠️ Budget Alert: Approaching 80%

Budget: CHF 4,217 / CHF 5,271 (80%)
Days elapsed: 12 / 31 (39%)

⚠️ Spending ahead of schedule (+41%)

Recommended actions:
• Reduce daily cap to CHF 80
• Pause 2-3 lowest-performing campaigns

Estimated exhaustion: Jan 19 (12 days early)
```

**Critical Alert:**
```
🚨 CRITICAL: Budget 90% Spent

Budget: CHF 4,744 / CHF 5,271 (90%)
Remaining: CHF 527 (3 days at current rate)

🛑 IMMEDIATE ACTION REQUIRED

1. Reduce daily cap to CHF 50 NOW
2. Pause non-essential campaigns
3. Monitor hourly until month-end

Days remaining: 19
Budget remaining: CHF 527 (35 leads at target CAC)
```

## Troubleshooting

**"Agent not detecting overspend"**
- Check Google Ads API connectivity
- Verify budget data is current (run /budget-calculator)
- Check alert threshold configuration in agent.json

**"Too many false alerts"**
- Adjust alertCooldownMinutes in configuration
- Review threshold percentages (may be too aggressive)
- Check if weekend spend is skewing daily averages

**"Slack alerts not received"**
- Verify SLACK_WEBHOOK_URL in .env
- Test webhook: `curl -X POST $SLACK_WEBHOOK_URL -d '{"text":"Test"}'`
- Check alert log: `docs/wip/guardian-alerts.log`

**"Daily rate calculation incorrect"**
- Ensure budget-calculator has latest monthly allocations
- Check if budget was adjusted mid-month
- Verify current day calculation (timezone issues)

## Best Practices

1. **First Week**: Run daily manual checks to validate alert accuracy
2. **Review Logs**: Check `guardian-alerts.log` weekly for false positives
3. **Adjust Thresholds**: Fine-tune based on actual spend patterns
4. **Alert Response**: Document actions taken for each alert type
5. **Weekend Handling**: Expect lower spend Sat-Sun, adjust thresholds accordingly

## Related Agents

- **marketing-strategist**: Uses budget-guardian data for weekly reviews
- **lead-quality-optimizer**: Focuses on lead quality, not budget

## Underlying Implementation

Agent execution flow:
1. Fetch current spend data (Google Ads API)
2. Load monthly budget allocation
3. Calculate thresholds and compare actuals
4. Determine alert level (none, warning, critical)
5. Generate daily report JSON
6. Send Slack alert if threshold exceeded
7. Log all alerts to guardian-alerts.log

See `alert-rules.md` for detailed threshold logic.

# budget-guardian Alert Rules

Detailed threshold logic for daily budget monitoring and alerting.

---

## Alert Level Overview

Three-tier alert system based on severity:

1. **ℹ️ INFO**: Normal operations, no action required
2. **⚠️ WARNING**: Attention needed, prepare for action
3. **🚨 CRITICAL**: Immediate action required

---

## Budget Threshold Rules

### Calculation Method

```javascript
const budgetPercentage = (monthToDateSpend / monthlyBudget) * 100;
const timePercentage = (daysElapsed / totalDaysInMonth) * 100;
const spendRate = budgetPercentage - timePercentage;

// Example: Day 12 of 31-day month
// If spent CHF 4,217 of CHF 5,271 budget:
// budgetPercentage = (4217 / 5271) * 100 = 80%
// timePercentage = (12 / 31) * 100 = 39%
// spendRate = 80% - 39% = +41% (spending ahead)
```

### Alert Thresholds

**ℹ️ INFO (Budget < 80%):**
- Normal operations
- Daily digest only
- No action required

**⚠️ WARNING (Budget 80-89%):**
- Budget approaching limit
- Send Slack warning
- Recommended actions:
  - Reduce daily budget by 10-15%
  - Prepare to pause campaigns
  - Monitor daily

**🚨 CRITICAL (Budget ≥ 90%):**
- Budget near exhaustion
- Send urgent Slack alert
- Immediate actions:
  - Reduce daily budget by 30-50%
  - Pause 2-3 lowest-performing campaigns
  - Check hourly until resolved

**🛑 EXCEEDED (Budget > 100%):**
- Budget limit breached
- Emergency Slack alert
- Emergency actions:
  - Set daily cap to CHF 0 (pause all)
  - Escalate to leadership
  - Decide: extend budget or accept no leads until month-end

---

## CAC (Cost Per Acquisition) Rules

### Calculation Method

```javascript
const currentCAC = totalSpend / totalLeads;
const targetCAC = 15.0; // CHF
const cacDeviation = ((currentCAC - targetCAC) / targetCAC) * 100;

// Example:
// Spent CHF 2,500, acquired 125 leads
// currentCAC = 2500 / 125 = CHF 20.00
// cacDeviation = ((20 - 15) / 15) * 100 = +33%
```

### Alert Thresholds

**ℹ️ INFO (CAC ≤ CHF 15):**
- At or below target
- No action required
- Continue current strategy

**⚠️ WARNING (CAC CHF 15-17):**
- Above target but manageable
- Alert after 3 consecutive days
- Recommended actions:
  - Review ad creative performance
  - Check targeting settings
  - Test new ad variants

**⚠️ WARNING (CAC CHF 17-20):**
- Significantly above target
- Alert on first occurrence
- Recommended actions:
  - Pause campaigns with CAC >CHF 20
  - Reduce daily budget by 20%
  - Activate retargeting (lower CAC)

**🚨 CRITICAL (CAC > CHF 20):**
- Unsustainable level
- Immediate alert
- Critical actions:
  - Pause all campaigns with CAC >CHF 25
  - Reduce Google Ads daily cap by 40%
  - Emergency creative refresh
  - Review targeting for wasted spend

### Consecutive Day Tracking

```javascript
// Track CAC for last 3 days
const cacHistory = [
  { date: '2026-01-10', cac: 15.80 },
  { date: '2026-01-11', cac: 16.20 },
  { date: '2026-01-12', cac: 16.50 }
];

// Check if all 3 days are in warning range (CHF 15-17)
const consecutiveWarnings = cacHistory.every(day =>
  day.cac >= 15.0 && day.cac <= 17.0
);

if (consecutiveWarnings) {
  triggerAlert('WARNING', 'CAC above target for 3 consecutive days');
}
```

---

## Daily Spend Rate Rules

### Calculation Method

```javascript
const daysInMonth = new Date(year, month, 0).getDate();
const expectedDailyRate = monthlyBudget / daysInMonth;
const actualDailySpend = yesterdaySpend;
const dailyVariance = ((actualDailySpend - expectedDailyRate) / expectedDailyRate) * 100;

// Example: January (31 days), CHF 5,271 budget
// expectedDailyRate = 5271 / 31 = CHF 170.03/day
// If yesterday spent CHF 250:
// dailyVariance = ((250 - 170.03) / 170.03) * 100 = +47%
```

### Alert Thresholds

**ℹ️ INFO (Daily spend 90-110% of expected):**
- Within normal variance
- No action required

**⚠️ WARNING (Daily spend 120-150% of expected):**
- Spending faster than planned
- Alert after 2 consecutive days
- Recommended actions:
  - Reduce daily cap by 15%
  - Review campaign pacing
  - Check for bid changes

**🚨 CRITICAL (Daily spend > 150% of expected):**
- Severe overspending
- Immediate alert
- Critical actions:
  - Reduce daily cap by 30% immediately
  - Check for system errors or unauthorized changes
  - Review Google Ads settings for bid increases

### Projected Exhaustion Date

```javascript
const remainingBudget = monthlyBudget - monthToDateSpend;
const averageDailySpend = monthToDateSpend / daysElapsed;
const daysUntilExhaustion = remainingBudget / averageDailySpend;
const exhaustionDate = new Date();
exhaustionDate.setDate(exhaustionDate.getDate() + daysUntilExhaustion);

// Example:
// Remaining: CHF 1,054
// Average daily: CHF 320
// Days until exhaustion: 1054 / 320 = 3.3 days
// Will exhaust on: Jan 15 (16 days before month-end)
```

If exhaustion date is before month-end:
- **⚠️ WARNING**: Exhaustion 5-10 days early
- **🚨 CRITICAL**: Exhaustion more than 10 days early

---

## ROAS (Return on Ad Spend) Rules

### Calculation Method

```javascript
const revenue = leadsGenerated * averageLeadValue;
const roas = revenue / totalSpend;

// Example:
// 150 leads generated
// Average lead value: CHF 45 (conversion rate 20%, AOV CHF 225)
// Revenue: 150 * 45 = CHF 6,750
// Spend: CHF 2,250
// ROAS: 6750 / 2250 = 3.0x
```

### Alert Thresholds

**ℹ️ INFO (ROAS ≥ 3.0x):**
- Meeting or exceeding target
- Strong performance
- Consider scaling budget

**⚠️ WARNING (ROAS 2.5-3.0x):**
- Below target but acceptable
- Alert after 3 consecutive days
- Recommended actions:
  - Optimize landing pages
  - Test new ad creative
  - Review conversion funnel

**⚠️ WARNING (ROAS 2.0-2.5x):**
- Below target, approaching minimum
- Alert after 2 consecutive days
- Recommended actions:
  - Pause lowest-performing campaigns
  - Shift budget to high-ROAS channels
  - Review targeting quality

**🚨 CRITICAL (ROAS < 2.0x):**
- Below minimum threshold
- Immediate alert
- Unsustainable performance
- Critical actions:
  - Pause all campaigns with ROAS <1.5x
  - Emergency budget reduction (50%)
  - Review entire marketing strategy

---

## Combined Threshold Logic

### Scenario Matrix

| Budget Status | CAC Status | ROAS Status | Alert Level | Actions |
|---------------|------------|-------------|-------------|---------|
| < 80% | ≤ CHF 15 | ≥ 3.0x | ℹ️ INFO | Continue strategy |
| < 80% | CHF 15-17 | 2.5-3.0x | ℹ️ INFO | Monitor closely |
| 80-89% | ≤ CHF 15 | ≥ 2.5x | ⚠️ WARNING | Prepare to reduce budget |
| 80-89% | CHF 17-20 | 2.0-2.5x | ⚠️ WARNING | Reduce budget 20% |
| ≥ 90% | Any | Any | 🚨 CRITICAL | Emergency reduction |
| Any | > CHF 20 | Any | 🚨 CRITICAL | Pause campaigns |
| Any | Any | < 2.0x | 🚨 CRITICAL | Emergency strategy review |

### Priority Override Rules

1. **Budget Exceeded (>100%)** overrides all other alerts
2. **CAC > CHF 20** triggers critical alert regardless of budget status
3. **ROAS < 2.0x** triggers critical alert regardless of budget status
4. Multiple warnings can combine into critical alert

---

## Alert Cooldown Logic

### Purpose
Prevent alert spam while maintaining responsiveness.

### Implementation

```javascript
const alertHistory = {
  'budget_warning': { lastSent: '2026-01-12T08:00:00Z', count: 1 },
  'cac_critical': { lastSent: '2026-01-12T12:00:00Z', count: 1 }
};

function shouldSendAlert(alertType, alertLevel) {
  const cooldownMinutes = 60;
  const lastAlert = alertHistory[alertType];

  if (!lastAlert) {
    return true; // First occurrence
  }

  const minutesSinceLastAlert = (Date.now() - new Date(lastAlert.lastSent)) / 60000;

  // Critical alerts override cooldown after 15 minutes
  if (alertLevel === 'CRITICAL' && minutesSinceLastAlert > 15) {
    return true;
  }

  // Other alerts respect full cooldown
  if (minutesSinceLastAlert >= cooldownMinutes) {
    return true;
  }

  return false;
}
```

### Cooldown Periods

- **ℹ️ INFO**: 24 hours (daily digest only)
- **⚠️ WARNING**: 60 minutes
- **🚨 CRITICAL**: 15 minutes (shorter to ensure urgency)
- **🛑 EXCEEDED**: No cooldown (every check sends alert)

---

## Weekend and Holiday Handling

### Weekend Adjustments

```javascript
const isWeekend = [0, 6].includes(new Date().getDay()); // Sunday or Saturday

if (isWeekend) {
  // Expect 30% lower spend on weekends
  expectedDailyRate *= 0.70;
}
```

**Rationale:**
- B2B traffic typically drops 30-50% on weekends
- Swiss military personnel less active on weekends
- Adjust thresholds to prevent false alerts

### Swiss Holidays

```javascript
const swissHolidays2026 = [
  '2026-01-01', // New Year's Day
  '2026-04-03', // Good Friday
  '2026-04-06', // Easter Monday
  '2026-05-01', // Labour Day
  '2026-05-14', // Ascension Day
  '2026-05-25', // Whit Monday
  '2026-08-01', // National Day
  '2026-12-25', // Christmas Day
  '2026-12-26'  // Boxing Day
];

const today = new Date().toISOString().split('T')[0];
const isHoliday = swissHolidays2026.includes(today);

if (isHoliday) {
  // Expect 50% lower spend on holidays
  expectedDailyRate *= 0.50;
}
```

---

## Testing and Calibration

### First Month Setup

**Week 1-2:** Alert-only mode
- Send all alerts but don't recommend actions
- Collect baseline data
- Identify false positive patterns

**Week 3-4:** Calibration
- Adjust thresholds based on actual spend patterns
- Fine-tune cooldown periods
- Document weekend/holiday variations

**Month 2+:** Full operation
- Enable all alerts with tuned thresholds
- Monitor false positive rate (target: <5%)
- Continuous refinement

### Testing Commands

```bash
# Test with specific date
node run.js --test-date=2026-01-15

# Test alert levels
node run.js --simulate-warning
node run.js --simulate-critical

# Test Slack notification format
node run.js --test-mode --force-alert
```

---

## Alert Response Playbook

### ⚠️ WARNING: Budget 80%

**Immediate (< 2 hours):**
1. Check actual vs expected spend rate
2. Identify highest-spending campaigns
3. Reduce daily caps by 10%

**Within 24 hours:**
1. Review campaign performance
2. Pause 1-2 lowest-performing campaigns
3. Update monthly forecast

### 🚨 CRITICAL: Budget 90%

**Immediate (< 30 minutes):**
1. Reduce daily caps by 30%
2. Pause 2-3 lowest-performing campaigns
3. Alert leadership

**Within 4 hours:**
1. Calculate remaining budget
2. Set sustainable daily cap
3. Prepare for reduced lead volume

### 🚨 CRITICAL: CAC > CHF 20

**Immediate (< 1 hour):**
1. Pause all campaigns with CAC >CHF 25
2. Reduce Google Ads daily cap by 40%
3. Activate retargeting campaigns

**Within 24 hours:**
1. Review ad creative (likely fatigued)
2. Check targeting settings
3. Analyze competitor activity
4. Test new creative variants

---

## Audit Trail

Every alert creates log entry:

```json
{
  "timestamp": "2026-01-12T08:00:00Z",
  "alertType": "budget_warning",
  "alertLevel": "WARNING",
  "trigger": "budget_percentage",
  "values": {
    "budgetPercentage": 80.2,
    "daysElapsed": 12,
    "daysRemaining": 19,
    "spendRate": "+41%"
  },
  "notification": {
    "slack": true,
    "email": false,
    "sentAt": "2026-01-12T08:00:15Z"
  },
  "actionsTaken": [
    "Reduced daily cap to CHF 120",
    "Paused campaign: Display Retargeting Low"
  ],
  "outcome": {
    "resolved": true,
    "resolvedAt": "2026-01-14T16:00:00Z",
    "finalBudgetPercentage": 85.0
  }
}
```

This enables continuous improvement of alert accuracy.

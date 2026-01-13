# Marketing Intelligence Framework

Generic marketing analytics and optimization patterns for any business.

## Collection Overview

Framework skill providing reusable patterns for campaign performance analysis, budget optimization, and multi-channel attribution. This is **NOT project-specific** - it serves as a template for creating business-specific implementations.

## Skills

### advertising-performance
**Purpose:** Generic multi-channel advertising performance monitoring and analysis
**Reusability:** 90% (framework)

**Use Cases:**
- Monitor daily ad spend and conversions across platforms
- Calculate CAC (Customer Acquisition Cost) and ROAS (Return on Ad Spend)
- Compare performance between Google Ads and Meta Ads
- Generate performance alerts when metrics exceed thresholds
- Track campaign effectiveness over time

**Key Features:**
- Multi-platform performance tracking (Google Ads + Meta Ads)
- Automated CAC/ROAS calculations with division-by-zero safety
- Threshold-based alerting (CRITICAL/WARNING/SUCCESS)
- Currency normalization to CHF/USD/EUR
- Blended performance analysis across platforms
- Alert generation with actionable recommendations

**Key Metrics Tracked:**
```
- CAC (Customer Acquisition Cost)
- ROAS (Return on Ad Spend)
- CTR (Click-Through Rate)
- CPC (Cost Per Click)
- Spend (normalized currency)
- Conversions
- Impressions
```

### budget-optimization
**Purpose:** Generic budget allocation and optimization patterns
**Reusability:** 85% (framework)

**Use Cases:**
- Reallocate budget between underperforming and high-performing platforms
- Forecast seasonal budget needs based on historical data
- Optimize blended CAC across Google Ads + Meta Ads
- Calculate expected impact of budget changes
- Plan monthly/quarterly budget distribution

**Key Features:**
- Budget reallocation algorithms (platform A → platform B)
- Seasonal budget forecasting based on historical trends
- Marginal CAC prediction (diminishing returns curve)
- Expected impact calculation (CAC/ROAS improvements)
- Platform capacity utilization analysis

**Key Metrics Tracked:**
```
- Budget allocation percentages
- Seasonal multipliers
- Marginal CAC at different spend levels
- Expected blended CAC after reallocation
- Platform capacity utilization
```

### health-monitoring
**Purpose:** Generic health check and data freshness monitoring
**Reusability:** 75% (framework)

**Use Cases:**
- Validate connectivity to all marketing data sources
- Check data freshness (when was data last updated?)
- Monitor system health before critical operations
- Alert when data becomes stale
- Verify API credentials and permissions
- Detect silent failures in data pipelines

**Key Features:**
- Multi-source connectivity checks (Supabase, Airtable, APIs)
- Data freshness validation with configurable thresholds
- Overall health status aggregation (healthy/degraded/critical)
- Automated alerting on critical failures
- Historical health tracking and trend analysis

**Key Metrics Tracked:**
```
- System connectivity status (connected/failed/degraded)
- Data age in hours
- Data staleness flags
- Overall system health
- Failed system count
```

### campaign-analytics (legacy)
**Purpose:** Generic marketing campaign performance tracking and optimization

**Note:** This skill is now supplemented by the more focused advertising-performance, budget-optimization, and health-monitoring framework skills above.

## How to Use Framework Skills

### 1. Create Project-Specific Implementation

```bash
# Example: MyArmy marketing intelligence
mkdir -p myarmy-skills/campaign-analytics-myarmy
cd myarmy-skills/campaign-analytics-myarmy
```

### 2. Reference Framework in skill.config.json

```json
{
  "skill": "campaign-analytics-myarmy",
  "version": "1.0.0",
  "extends": "marketing-intelligence-framework/campaign-analytics",
  "dependencies": {
    "packages": [
      { "name": "google-ads-api", "version": "latest" },
      { "name": "facebook-nodejs-business-sdk", "version": "latest" }
    ],
    "env_vars": {
      "GOOGLE_ADS_CUSTOMER_ID": {
        "required": true,
        "description": "Google Ads customer ID",
        "example": "1234567890"
      },
      "META_ADS_ACCOUNT_ID": {
        "required": true,
        "description": "Facebook Ads account ID",
        "example": "act_1234567890"
      }
    },
    "files": [
      {
        "path": "config/google-ads-credentials.json",
        "description": "Google Ads API service account key"
      }
    ]
  },
  "configuration": {
    "platforms": {
      "google_ads": {
        "customer_id": "8847935674",
        "conversion_labels": {
          "form_submission": "JIHLCN-r-IwbEP7BxboC",
          "whatsapp_contact": "o9ylCNyr-IwbEP7BxboC"
        }
      },
      "meta_ads": {
        "account_id": "act_xxx",
        "pixel_id": "xxx"
      }
    },
    "targets": {
      "min_roas": 2.0,
      "max_cac": 150,
      "target_conversion_rate": 3.5
    },
    "currency": "CHF",
    "market": "switzerland"
  },
  "tags": ["marketing", "swiss-market", "b2b", "custom-manufacturing"]
}
```

### 3. Create Implementation Documentation

```markdown
---
name: campaign-analytics-myarmy
extends: marketing-intelligence-framework/campaign-analytics
---

# MyArmy Campaign Analytics

Extends `marketing-intelligence-framework/campaign-analytics` with Swiss military market specifics.

## Platforms

- **Google Ads**: Swiss German keywords (militär badge, funktionsabzeichen)
- **Facebook Ads**: Swiss military personnel targeting
- **Instagram Ads**: Visual content for custom badges

## Performance Targets

- Min ROAS: 2.0x (CHF 2 revenue per CHF 1 spend)
- Max CAC: CHF 150 per lead
- Target Conversion Rate: 3.5% (inquiry to quote)

## Budget Allocation (Monthly: CHF 3,000)

- Google Ads Search: 60% (CHF 1,800) - High intent keywords
- Facebook/Instagram: 30% (CHF 900) - Brand awareness
- Remarketing: 10% (CHF 300) - Re-engage visitors

## Conversion Tracking

- Form Submission: JIHLCN-r-IwbEP7BxboC
- WhatsApp Contact: o9ylCNyr-IwbEP7BxboC
```

## Integration Patterns

### Revenue Attribution

```typescript
// Connect ad platform conversions with actual revenue
async function attributeRevenue() {
  // 1. Get conversion data from ads platforms
  const googleConversions = await googleAds.getConversions();
  const metaConversions = await metaAds.getConversions();

  // 2. Get actual revenue from CRM/database
  const orders = await getOrders();

  // 3. Match conversions to orders (by email, phone, timestamp)
  const attributed = orders.map(order => {
    const conversion = findMatchingConversion(
      order,
      [...googleConversions, ...metaConversions]
    );

    return {
      order_id: order.id,
      revenue: order.total,
      platform: conversion?.platform,
      campaign: conversion?.campaign_name,
      ad_spend: conversion?.cost
    };
  });

  // 4. Calculate true ROAS per campaign
  const roasByCampaign = calculateROAS(attributed);
  return roasByCampaign;
}
```

### Budget Reallocation Workflow

```typescript
// Weekly budget optimization
export async function weeklyBudgetOptimization() {
  // 1. Get last 30 days performance
  const performance = await analytics.getConsolidatedPerformance(
    getDateDaysAgo(30),
    getDateToday()
  );

  // 2. Calculate recommended allocation
  const totalBudget = 3000; // Monthly budget
  const allocations = await optimizeBudgetAllocation(totalBudget, performance);

  // 3. Generate recommendations report
  const report = generateAllocationReport(allocations);

  // 4. Send for approval
  await sendToSlack(report, '#marketing');

  // 5. If approved, apply changes
  // (Requires human confirmation for budget changes)
}
```

## Database Schema

Track campaign performance locally:

```sql
-- Campaign performance history
CREATE TABLE campaign_performance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL,
  campaign_id TEXT NOT NULL,
  campaign_name TEXT NOT NULL,
  date DATE NOT NULL,
  impressions INTEGER DEFAULT 0,
  clicks INTEGER DEFAULT 0,
  spend DECIMAL(10,2) DEFAULT 0,
  conversions INTEGER DEFAULT 0,
  revenue DECIMAL(10,2) DEFAULT 0,
  ctr DECIMAL(5,2),
  cpc DECIMAL(10,2),
  cpa DECIMAL(10,2),
  roas DECIMAL(10,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(platform, campaign_id, date)
);

-- Budget allocations history
CREATE TABLE budget_allocations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  allocated_budget DECIMAL(10,2) NOT NULL,
  actual_spend DECIMAL(10,2) DEFAULT 0,
  roas DECIMAL(10,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_performance_platform_date ON campaign_performance(platform, date DESC);
CREATE INDEX idx_performance_roas ON campaign_performance(roas DESC);
```

## Automated Workflows

### Daily Performance Check

```bash
# Cron: Every day at 9am
0 9 * * * /path/to/daily-performance-check.sh
```

```typescript
// scripts/daily-performance-check.ts
export async function dailyPerformanceCheck() {
  const yesterday = getDateYesterday();

  // Fetch performance
  const performance = await analytics.getConsolidatedPerformance(
    yesterday,
    yesterday
  );

  // Check alerts
  const alerts = [];
  for (const [platform, metrics] of Object.entries(performance)) {
    // Alert if ROAS < 1.0 and spend > $100
    if (metrics.calculated.roas < 1.0 && metrics.metrics.spend > 100) {
      alerts.push({
        severity: 'high',
        platform,
        message: `Low ROAS: ${metrics.calculated.roas.toFixed(2)}x (spend: $${metrics.metrics.spend})`
      });
    }

    // Alert if no conversions and spend > $50
    if (metrics.metrics.conversions === 0 && metrics.metrics.spend > 50) {
      alerts.push({
        severity: 'medium',
        platform,
        message: `No conversions with $${metrics.metrics.spend} spend`
      });
    }
  }

  // Send alerts
  if (alerts.length > 0) {
    await sendAlertsToSlack(alerts);
  }

  // Store performance data
  await storePerformanceData(performance);
}
```

## Benefits of Framework Pattern

### ✅ Reusability
- Same patterns work across industries
- Platform integrations are generic
- Metrics calculations are universal

### ✅ Maintainability
- Update framework → all implementations benefit
- Centralized metric definitions
- Consistent reporting formats

### ✅ Scalability
- Easy to add new platforms (LinkedIn, TikTok, etc.)
- Multi-currency support
- Multi-market support

## Example Implementations

### Real-World Examples
- `myarmy-skills/campaign-analytics-myarmy` - Swiss military B2B campaigns
- Your implementation here!

## Testing

```typescript
describe('Campaign Analytics', () => {
  it('should calculate ROAS correctly', () => {
    const data: CampaignData = {
      platform: 'google_ads',
      campaign_id: 'test',
      campaign_name: 'Test Campaign',
      date: '2024-01-01',
      metrics: {
        impressions: 10000,
        clicks: 300,
        spend: 500,
        conversions: 15,
        revenue: 1500
      }
    };

    const aggregated = calculateMetrics(data);

    expect(aggregated.calculated.roas).toBe(3.0); // 1500 / 500
    expect(aggregated.calculated.ctr).toBe(3.0);  // (300 / 10000) * 100
    expect(aggregated.calculated.cpc).toBeCloseTo(1.67); // 500 / 300
    expect(aggregated.calculated.cpa).toBeCloseTo(33.33); // 500 / 15
  });
});
```

## Support

- **Issues**: https://github.com/your-org/cortex-skills
- **Documentation**: See campaign-analytics/SKILL.md
- **Examples**: Check myarmy-skills implementations

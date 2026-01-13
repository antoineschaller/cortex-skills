---
name: budget-optimization
description: Generic budget allocation and optimization patterns for multi-channel marketing. Use when reallocating budgets between platforms, forecasting seasonal spend, or optimizing CAC across channels. Framework for project-specific implementations.
---

# Budget Optimization Framework

Generic patterns for marketing budget allocation, optimization, and seasonal forecasting.

## When to Use

- Reallocate budget between underperforming and high-performing platforms
- Forecast seasonal budget needs based on historical data
- Optimize blended CAC across Google Ads + Meta Ads
- Calculate expected impact of budget changes
- Plan monthly/quarterly budget distribution

## NOT Project-Specific

This is a **framework skill** providing generic patterns. For project-specific implementations:
- Create implementation skill in your project (e.g., `/landing/.claude/skills/seasonal-budget-advisor`)
- Reference this framework with `extends: "marketing-intelligence-framework/budget-optimization"`
- Add project-specific data sources and constraints

## Core Concepts

### Budget Allocation Strategy

```
1. Measure current performance → CAC and ROAS per platform
2. Identify winner → Platform with lowest CAC or highest ROAS
3. Calculate reallocation → How much to shift from loser to winner
4. Project impact → Expected improvement in blended CAC
5. Implement gradually → Test with 10-20% shifts first
```

### Key Decision Metrics

| Metric | Purpose | Decision Rule |
|--------|---------|---------------|
| **CAC Ratio** | Compare platform efficiency | Shift budget to lower CAC platform |
| **ROAS Ratio** | Compare revenue efficiency | Shift budget to higher ROAS platform |
| **Marginal CAC** | Predict CAC at higher spend | Stop if marginal CAC > target |
| **Platform Capacity** | Audience size limit | Don't exceed platform's scalability |

## Implementation Patterns

### 1. Calculate Budget Reallocation

```typescript
interface BudgetReallocation {
  from_platform: 'google_ads' | 'meta_ads';
  to_platform: 'google_ads' | 'meta_ads';
  amount_chf: number;
  reason: string;
  expected_impact: {
    cac_improvement: number;
    roas_improvement: number;
  };
}

function calculateReallocation(
  googlePerf: { cac: number; roas: number; spend: number },
  metaPerf: { cac: number; roas: number; spend: number }
): BudgetReallocation | null {
  // Identify underperformer and winner
  const cacRatio = googlePerf.cac / metaPerf.cac;

  if (cacRatio > 1.5) {
    // Google Ads CAC is 50%+ higher - reallocate from Google to Meta
    const reallocationAmount = googlePerf.spend * 0.2; // 20% shift

    return {
      from_platform: 'google_ads',
      to_platform: 'meta_ads',
      amount_chf: reallocationAmount,
      reason: `Google Ads CAC (CHF ${googlePerf.cac.toFixed(2)}) is ${((cacRatio - 1) * 100).toFixed(0)}% higher than Meta Ads`,
      expected_impact: {
        cac_improvement: calculateExpectedCACImprovement(googlePerf, metaPerf, reallocationAmount),
        roas_improvement: 0 // Calculate if revenue data available
      }
    };
  } else if (cacRatio < 0.67) {
    // Meta Ads CAC is 50%+ higher - reallocate from Meta to Google
    const reallocationAmount = metaPerf.spend * 0.2;

    return {
      from_platform: 'meta_ads',
      to_platform: 'google_ads',
      amount_chf: reallocationAmount,
      reason: `Meta Ads CAC (CHF ${metaPerf.cac.toFixed(2)}) is ${((1/cacRatio - 1) * 100).toFixed(0)}% higher than Google Ads`,
      expected_impact: {
        cac_improvement: calculateExpectedCACImprovement(metaPerf, googlePerf, reallocationAmount),
        roas_improvement: 0
      }
    };
  }

  return null; // No reallocation needed
}

function calculateExpectedCACImprovement(
  fromPerf: { cac: number; spend: number; conversions: number },
  toPerf: { cac: number; spend: number; conversions: number },
  reallocAmount: number
): number {
  // Current blended CAC
  const totalSpend = fromPerf.spend + toPerf.spend;
  const totalConversions = fromPerf.conversions + toPerf.conversions;
  const currentBlendedCAC = totalSpend / totalConversions;

  // Projected blended CAC after reallocation
  const newFromSpend = fromPerf.spend - reallocAmount;
  const newToSpend = toPerf.spend + reallocAmount;

  // Assume conversions scale linearly with spend (conservative estimate)
  const newFromConversions = (newFromSpend / fromPerf.spend) * fromPerf.conversions;
  const newToConversions = (newToSpend / toPerf.spend) * toPerf.conversions;

  const newBlendedCAC = totalSpend / (newFromConversions + newToConversions);

  return currentBlendedCAC - newBlendedCAC; // Positive = improvement
}
```

### 2. Seasonal Budget Forecasting

```typescript
interface SeasonalBudget {
  month: string;
  recommended_budget_chf: number;
  expected_conversions: number;
  expected_cac: number;
  confidence: 'high' | 'medium' | 'low';
  factors: string[];
}

function forecastSeasonalBudget(
  historicalData: Array<{ month: string; spend: number; conversions: number }>,
  targetMonth: string
): SeasonalBudget {
  // Find same month in previous years
  const sameMonthHistory = historicalData.filter(d =>
    d.month.endsWith(targetMonth.slice(-2)) // Match month number
  );

  if (sameMonthHistory.length === 0) {
    // No historical data for this month
    const avgSpend = historicalData.reduce((sum, d) => sum + d.spend, 0) / historicalData.length;
    return {
      month: targetMonth,
      recommended_budget_chf: avgSpend,
      expected_conversions: 0,
      expected_cac: 0,
      confidence: 'low',
      factors: ['No historical data for this month', 'Using average monthly spend']
    };
  }

  // Calculate seasonal multiplier
  const avgMonthlySpend = historicalData.reduce((sum, d) => sum + d.spend, 0) / historicalData.length;
  const sameMonthAvgSpend = sameMonthHistory.reduce((sum, d) => sum + d.spend, 0) / sameMonthHistory.length;
  const seasonalMultiplier = sameMonthAvgSpend / avgMonthlySpend;

  // Apply to most recent month's spend
  const recentSpend = historicalData[historicalData.length - 1].spend;
  const recommendedBudget = recentSpend * seasonalMultiplier;

  // Calculate expected conversions
  const sameMonthAvgConversions = sameMonthHistory.reduce((sum, d) => sum + d.conversions, 0) / sameMonthHistory.length;
  const expectedCAC = recommendedBudget / sameMonthAvgConversions;

  return {
    month: targetMonth,
    recommended_budget_chf: recommendedBudget,
    expected_conversions: sameMonthAvgConversions,
    expected_cac: expectedCAC,
    confidence: sameMonthHistory.length >= 2 ? 'high' : 'medium',
    factors: [
      `Seasonal multiplier: ${seasonalMultiplier.toFixed(2)}x`,
      `Based on ${sameMonthHistory.length} years of historical data`,
      seasonalMultiplier > 1.2 ? 'High-season month' : seasonalMultiplier < 0.8 ? 'Low-season month' : 'Average month'
    ]
  };
}
```

### 3. Marginal CAC Analysis

```typescript
// Predict CAC at different spend levels (diminishing returns)
function calculateMarginalCAC(
  currentSpend: number,
  currentCAC: number,
  proposedSpend: number,
  platformCapacity: number // Max efficient spend
): number {
  const spendRatio = proposedSpend / currentSpend;
  const capacityUtilization = proposedSpend / platformCapacity;

  // Diminishing returns curve
  // CAC increases as spend approaches platform capacity
  const marginalMultiplier = 1 + (capacityUtilization ** 2) * 0.5;

  return currentCAC * marginalMultiplier;
}

// Example usage
const currentGoogleSpend = 500; // CHF/day
const currentGoogleCAC = 16.7;
const proposedSpend = 1000; // Double the spend
const googleCapacity = 2000; // Max before audience saturation

const marginalCAC = calculateMarginalCAC(
  currentGoogleSpend,
  currentGoogleCAC,
  proposedSpend,
  googleCapacity
);

if (marginalCAC > 20) {
  console.log('⚠️  Marginal CAC too high, don't increase spend');
} else {
  console.log('✅ Scaling spend is efficient');
}
```

### 4. Budget Allocation Dashboard

```typescript
interface BudgetAllocation {
  total_budget_chf: number;
  allocations: {
    google_ads: { amount: number; percentage: number };
    meta_ads: { amount: number; percentage: number };
  };
  rationale: string;
  expected_blended_cac: number;
}

function optimizeBudgetAllocation(
  totalBudget: number,
  googleCAC: number,
  metaCAC: number
): BudgetAllocation {
  // Allocate proportionally to inverse of CAC (more budget to lower CAC)
  const googleWeight = 1 / googleCAC;
  const metaWeight = 1 / metaCAC;
  const totalWeight = googleWeight + metaWeight;

  const googleAllocation = (googleWeight / totalWeight) * totalBudget;
  const metaAllocation = (metaWeight / totalWeight) * totalBudget;

  return {
    total_budget_chf: totalBudget,
    allocations: {
      google_ads: {
        amount: googleAllocation,
        percentage: (googleAllocation / totalBudget) * 100
      },
      meta_ads: {
        amount: metaAllocation,
        percentage: (metaAllocation / totalBudget) * 100
      }
    },
    rationale: `Budget allocated inversely proportional to CAC. Lower CAC = higher allocation.`,
    expected_blended_cac: totalBudget / (
      (googleAllocation / googleCAC) + (metaAllocation / metaCAC)
    )
  };
}
```

## Reusability Patterns

### Framework Level (85% reusable)
```typescript
// Generic allocation logic works for any 2+ platforms
export function optimizeBudgetAllocation(
  totalBudget: number,
  platforms: Array<{ name: string; cac: number }>
): BudgetAllocation {
  // Applies to any multi-channel setup
}
```

### Implementation Level (project-specific)
```typescript
// MyArmy-specific constraints
const CONSTRAINTS = {
  minGoogleBudget: 100, // Minimum daily spend for Google Ads
  maxMetaBudget: 500, // Cap Meta Ads to avoid saturation
  reallocationLimit: 0.3 // Max 30% shift per adjustment
};
```

## Decision Framework

### When to Reallocate Budget

✅ **DO reallocate when:**
- CAC difference > 30% between platforms
- Platform consistently underperforming for 7+ days
- ROAS difference > 50% between platforms
- One platform hitting diminishing returns

❌ **DON'T reallocate when:**
- Only 1-2 days of data (wait for trend)
- Seasonal factors explain difference
- Platform is testing new campaigns
- Budget is already at minimum threshold

### Budget Adjustment Cadence

| Frequency | Use Case |
|-----------|----------|
| **Daily** | Critical underperformance (CAC > 2x target) |
| **Weekly** | Normal optimization cycles |
| **Monthly** | Seasonal adjustments and forecasting |
| **Quarterly** | Strategic reallocation based on trends |

## Common Pitfalls

❌ **Over-optimization**: Changing budgets too frequently (wait for statistical significance)
❌ **Ignoring seasonality**: December performance ≠ February performance
❌ **Linear scaling assumption**: CAC often increases at higher spend (diminishing returns)
❌ **Platform capacity**: Don't exceed audience size limits
❌ **Missing constraints**: Always respect minimum daily budgets

## Related Frameworks

- **advertising-performance**: Monitor CAC/ROAS to inform budget decisions
- **health-monitoring**: Ensure data quality before budget optimization

## Example Project Implementation

See `/landing/.claude/skills/seasonal-budget-advisor/` for MyArmy-specific implementation using this framework.

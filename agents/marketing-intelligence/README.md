# Marketing Intelligence Agents

Autonomous decision-making agents for marketing optimization with real-time monitoring and alerts.

## Agent Overview

Three specialized agents for continuous marketing intelligence:

1. **marketing-strategist** - Weekly/monthly budget optimization
2. **budget-guardian** - Daily spend monitoring and threshold alerts
3. **lead-quality-optimizer** - Weekly funnel optimization

## How Agents Work

**Triggers:**
- Scheduled (cron-based): Weekly, daily, monthly
- Manual (on-demand): Run anytime for immediate analysis
- Event-driven: Respond to threshold violations (future)

**Decision Framework:**
- **Auto-Execute**: Low-risk decisions (CAC <10% deviation)
- **Request Approval**: Medium-risk changes (15%+ budget shifts)
- **Alert Immediately**: Critical issues (CAC >CHF 20, budget exhaustion)

**Tools Used:**
- All 9 marketing intelligence skills
- Slack notifications for alerts
- JSON reports for audit trail

## Agent Summary

| Agent | Triggers | Purpose | Auto-Execute Threshold |
|-------|----------|---------|------------------------|
| marketing-strategist | Weekly (Fri 5pm)<br>Monthly (1st 9am) | Budget optimization<br>Channel reallocation | CAC deviation <10% |
| budget-guardian | Daily (8am)<br>Real-time | Spend monitoring<br>Threshold alerts | Budget at 80% = alert |
| lead-quality-optimizer | Weekly (Mon 9am) | Lead quality analysis<br>Funnel optimization | Conversion <15% = alert |

## Quick Start

```bash
# Run agents manually (test mode)
cd /Users/antoineschaller/GitHub/myarmy/cortex-skills/agents/marketing-intelligence

# Test marketing strategist
node marketing-strategist/run.js --test-mode

# Test budget guardian
node budget-guardian/run.js --test-mode

# Test lead quality optimizer
node lead-quality-optimizer/run.js --test-mode
```

## Configuration

**Slack Alerts** (optional but recommended):
```bash
# Add to .env
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T.../B.../...
```

**Cron Schedules** (automated):
```bash
# Weekly: marketing-strategist (Friday 5pm)
0 17 * * 5 node agents/marketing-intelligence/marketing-strategist/run.js

# Monthly: marketing-strategist (1st at 9am)
0 9 1 * * node agents/marketing-intelligence/marketing-strategist/run.js

# Daily: budget-guardian (8am)
0 8 * * * node agents/marketing-intelligence/budget-guardian/run.js

# Weekly: lead-quality-optimizer (Monday 9am)
0 9 * * 1 node agents/marketing-intelligence/lead-quality-optimizer/run.js
```

## Alert Levels

**🚨 CRITICAL** (Immediate Slack notification):
- CAC exceeds CHF 20
- Budget spent >90% before month-end
- ROAS drops below 2x
- System failures (API errors)

**⚠️ WARNING** (Priority notification):
- CAC between CHF 15-20 for 3+ consecutive days
- Budget at 80% with >7 days remaining
- Conversion rate drops below 15%

**ℹ️ INFO** (Daily digest):
- Budget on track
- Performance summaries
- Weekly/monthly reports

## Integration with Skills

Agents use the 9 skills created in Phase 1-3:

**marketing-strategist uses:**
- /revenue-analysis
- /google-ads-performance
- /lead-funnel-analysis
- /seasonal-budget-advisor

**budget-guardian uses:**
- /google-ads-performance
- /budget-calculator
- /marketing-health-check

**lead-quality-optimizer uses:**
- /lead-funnel-analysis
- @akson/cortex-analytics posthog queries

## Output & Reports

**JSON Reports** (audit trail):
- `docs/wip/strategist-report-{date}.json`
- `docs/wip/guardian-alert-{date}.json`
- `docs/wip/optimizer-report-{date}.json`

**Slack Notifications:**
- Real-time alerts with priority levels
- Daily digest summaries
- Weekly/monthly performance reports

## Best Practices

1. **Test agents manually first** before enabling automation
2. **Start with alerts only** (no auto-execution) for first month
3. **Review decision logs** to validate agent recommendations
4. **Adjust thresholds** based on real-world performance
5. **Monitor false positive rate** (target: <5%)

## Documentation

Each agent includes:
- `agent.json` - Configuration and triggers
- `README.md` - Usage documentation
- Decision framework documentation (varies by agent)

## Support

- Agent issues: Check `logs/agents/` for error details
- Slack not working: Verify webhook URL in .env
- Triggers not firing: Check cron configuration
- Unexpected decisions: Review decision framework thresholds

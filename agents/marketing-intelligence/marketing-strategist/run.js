#!/usr/bin/env node

/**
 * marketing-strategist Agent - Autonomous Budget Optimization
 *
 * Executes weekly performance reviews and monthly budget planning
 * with autonomous decision-making based on thresholds.
 *
 * Usage:
 *   node run.js                    # Normal execution
 *   node run.js --test-mode        # Test without Slack notifications
 *   node run.js --weekly           # Force weekly review
 *   node run.js --monthly          # Force monthly planning
 */

import { execSync } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load agent configuration
const agentConfig = JSON.parse(
  await fs.readFile(path.join(__dirname, 'agent.json'), 'utf-8')
);

// Determine execution mode
const args = process.argv.slice(2);
const testMode = args.includes('--test-mode');
const forceWeekly = args.includes('--weekly');
const forceMonthly = args.includes('--monthly');

// Output paths
const REPORTS_DIR = path.join(__dirname, '../../../landing/docs/wip');

console.log('🟣 MyArmy Marketing Strategist Agent');
console.log('=====================================\n');

if (testMode) {
  console.log('⚠️  TEST MODE: Slack notifications disabled\n');
}

/**
 * Execute a skill and return its output
 */
async function executeSkill(skillName, args = []) {
  console.log(`📊 Executing skill: ${skillName}`);

  try {
    const scriptPath = path.join(__dirname, '../../../landing/scripts');

    // Map skill names to actual scripts
    const scriptMap = {
      'revenue-analysis': 'analyze-5-year-trends.mjs',
      'google-ads-performance': 'fetch-google-ads-spend.mjs',
      'meta-ads-performance': 'fetch-meta-ads-spend.mjs',
      'lead-funnel-analysis': 'fetch-real-lead-data.mjs',
      'seasonal-budget-advisor': 'seasonal-budget-advisor.mjs',
      'budget-calculator': 'project-2026-budget.mjs',
      'marketing-health-check': 'marketing-health-check.mjs',
    };

    const script = scriptMap[skillName];
    if (!script) {
      throw new Error(`Unknown skill: ${skillName}`);
    }

    const fullPath = path.join(scriptPath, script);
    const command = `node ${fullPath} ${args.join(' ')}`;

    const output = execSync(command, {
      cwd: path.join(__dirname, '../../../landing'),
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe']
    });

    console.log(`✅ ${skillName} completed\n`);
    return { success: true, output };

  } catch (error) {
    console.error(`❌ ${skillName} failed:`, error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Load data from a JSON file
 */
async function loadData(filename) {
  try {
    const filePath = path.join(REPORTS_DIR, filename);
    const content = await fs.readFile(filePath, 'utf-8');
    return JSON.parse(content);
  } catch (error) {
    console.warn(`⚠️  Could not load ${filename}: ${error.message}`);
    return null;
  }
}

/**
 * Merge Google Ads and Meta Ads data into unified structure
 */
function mergeAdChannels(googleAdsData, metaAdsData) {
  if (!googleAdsData && !metaAdsData) {
    return null;
  }

  // If only one channel has data, return it
  if (!metaAdsData) {
    return {
      ...googleAdsData,
      totals: googleAdsData?.totals || {},
      channels: { google: googleAdsData?.totals || {} }
    };
  }
  if (!googleAdsData) {
    return {
      ...metaAdsData,
      totals: metaAdsData?.totals || {},
      channels: { meta: metaAdsData?.totals || {} }
    };
  }

  // Calculate blended metrics (weighted average)
  const googleSpend = googleAdsData.totals?.totalSpend || 0;
  const metaSpend = metaAdsData.totals?.totalSpend || 0;
  const totalSpend = googleSpend + metaSpend;

  const googleWeight = totalSpend > 0 ? googleSpend / totalSpend : 0.5;
  const metaWeight = totalSpend > 0 ? metaSpend / totalSpend : 0.5;

  const blendedCAC =
    (googleAdsData.totals?.averageCAC || 0) * googleWeight +
    (metaAdsData.totals?.averageCAC || 0) * metaWeight;

  const blendedROAS =
    (googleAdsData.totals?.roas || 0) * googleWeight +
    (metaAdsData.totals?.roas || 0) * metaWeight;

  return {
    // Blended metrics for decision framework
    totals: {
      totalSpend: totalSpend,
      totalConversions:
        (googleAdsData.totals?.totalConversions || 0) +
        (metaAdsData.totals?.totalConversions || 0),
      averageCAC: blendedCAC,
      roas: blendedROAS,
    },
    // Per-channel metrics for optimization
    channels: {
      google: {
        spend: googleSpend,
        conversions: googleAdsData.totals?.totalConversions || 0,
        cac: googleAdsData.totals?.averageCAC || 0,
        roas: googleAdsData.totals?.roas || 0,
        weight: googleWeight,
      },
      meta: {
        spend: metaSpend,
        conversions: metaAdsData.totals?.totalConversions || 0,
        cac: metaAdsData.totals?.averageCAC || 0,
        roas: metaAdsData.totals?.roas || 0,
        weight: metaWeight,
      },
    },
    // Raw data for detailed analysis
    google: googleAdsData,
    meta: metaAdsData,
  };
}

/**
 * Calculate metrics for decision framework
 */
function calculateMetrics(data) {
  const { googleAdsData, metaAdsData, budgetData, revenueData } = data;

  // Merge ad channels for unified metrics
  const adData = mergeAdChannels(googleAdsData, metaAdsData);

  const metrics = {
    // Blended metrics for decision framework
    actualCAC: adData?.totals?.averageCAC || null,
    targetCAC: agentConfig.configuration.targetCAC,
    actualROAS: adData?.totals?.roas || null,
    targetROAS: agentConfig.configuration.targetROAS,
    minROAS: agentConfig.configuration.minROAS,
    actualSpend: adData?.totals?.totalSpend || 0,
    budgetedSpend: budgetData?.currentMonth?.budget || 0,

    // Per-channel metrics for optimization
    channels: adData?.channels || null,
  };

  // Calculate deviations
  if (metrics.actualCAC && metrics.targetCAC) {
    metrics.cacDeviation = Math.abs(
      (metrics.actualCAC - metrics.targetCAC) / metrics.targetCAC
    );
  }

  if (metrics.actualSpend && metrics.budgetedSpend) {
    metrics.budgetCompliance = metrics.actualSpend / metrics.budgetedSpend;
  }

  return metrics;
}

/**
 * Apply decision framework
 */
function applyDecisionFramework(metrics) {
  const { autoExecute, requestApproval, alertImmediately } = agentConfig.decisionFramework;

  // Check Alert Immediately conditions (highest priority)
  for (const condition of alertImmediately.conditions) {
    if (evaluateCondition(condition, metrics)) {
      return {
        tier: 'alertImmediately',
        trigger: condition.metric,
        priority: 'critical',
        actions: alertImmediately.actions
      };
    }
  }

  // Check Request Approval conditions
  for (const condition of requestApproval.conditions) {
    if (evaluateCondition(condition, metrics)) {
      return {
        tier: 'requestApproval',
        trigger: condition.metric,
        priority: 'warning',
        actions: requestApproval.actions
      };
    }
  }

  // Check Auto Execute conditions (all must be met)
  const autoExecuteConditionsMet = autoExecute.conditions.every(
    condition => evaluateCondition(condition, metrics)
  );

  if (autoExecuteConditionsMet) {
    return {
      tier: 'autoExecute',
      priority: 'info',
      actions: autoExecute.actions
    };
  }

  // Default to request approval if uncertain
  return {
    tier: 'requestApproval',
    trigger: 'uncertain',
    priority: 'warning',
    actions: ['Manual review required']
  };
}

/**
 * Evaluate a single condition
 */
function evaluateCondition(condition, metrics) {
  const value = metrics[condition.metric];

  if (value === null || value === undefined) {
    return false;
  }

  switch (condition.operator) {
    case '<':
      return value < condition.value;
    case '>':
      return value > condition.value;
    case '>=':
      return value >= condition.value;
    case '<=':
      return value <= condition.value;
    case '==':
      return value === condition.value;
    default:
      return false;
  }
}

/**
 * Generate weekly performance report
 */
function generateWeeklyReport(metrics, decision) {
  const now = new Date();
  const weekAgo = new Date(now);
  weekAgo.setDate(weekAgo.getDate() - 7);

  const report = {
    date: now.toISOString().split('T')[0],
    type: 'weekly',
    period: {
      from: weekAgo.toISOString().split('T')[0],
      to: now.toISOString().split('T')[0]
    },
    performance: {
      spend: metrics.actualSpend,
      cac: metrics.actualCAC,
      cacTarget: metrics.targetCAC,
      cacDeviation: metrics.cacDeviation ? (metrics.cacDeviation * 100).toFixed(1) + '%' : 'N/A',
      roas: metrics.actualROAS
    },
    status: decision.tier === 'autoExecute' ? 'healthy' :
            decision.tier === 'alertImmediately' ? 'critical' : 'warning',
    decision: decision.tier,
    priority: decision.priority,
    recommendations: generateRecommendations(metrics, decision),
    nextSteps: generateNextSteps(metrics, decision)
  };

  return report;
}

/**
 * Generate monthly planning report
 */
function generateMonthlyReport(metrics, decision, budgetData) {
  const now = new Date();
  const currentMonth = now.toLocaleString('en', { month: 'long' });
  const previousMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1)
    .toLocaleString('en', { month: 'long' });

  const report = {
    date: now.toISOString().split('T')[0],
    type: 'monthly',
    month: currentMonth,
    previousMonth: {
      name: previousMonth,
      budgeted: budgetData?.previousMonth?.budget || 0,
      actual: metrics.actualSpend,
      variance: budgetData?.previousMonth?.budget ?
        (((metrics.actualSpend - budgetData.previousMonth.budget) / budgetData.previousMonth.budget) * 100).toFixed(1) + '%' :
        'N/A'
    },
    nextMonth: {
      budgeted: budgetData?.currentMonth?.budget || 0,
      strategy: decision.tier === 'autoExecute' ? 'steady' : 'adjust',
      expectedLeads: Math.round((budgetData?.currentMonth?.budget || 0) / metrics.targetCAC),
      targetCAC: metrics.targetCAC
    },
    decision: decision.tier,
    priority: decision.priority,
    optimizations: generateOptimizations(metrics, decision)
  };

  return report;
}

/**
 * Generate actionable recommendations
 */
function generateRecommendations(metrics, decision) {
  const recommendations = [];

  if (decision.tier === 'autoExecute') {
    recommendations.push({
      priority: 'success',
      action: 'Continue current strategy',
      reason: `CAC: ${metrics.actualCAC?.toFixed(2)} (target: ${metrics.targetCAC}), ROAS: ${metrics.actualROAS?.toFixed(1)}x`
    });

    if (metrics.actualROAS > metrics.targetROAS) {
      recommendations.push({
        priority: 'info',
        action: 'Consider scaling budget by 5-10%',
        reason: `Strong ROAS of ${metrics.actualROAS?.toFixed(1)}x exceeds target`
      });
    }
  } else if (decision.tier === 'requestApproval') {
    if (metrics.cacDeviation > 0.15) {
      recommendations.push({
        priority: 'warning',
        action: 'Review campaign targeting and ad creative',
        reason: `CAC ${((metrics.cacDeviation || 0) * 100).toFixed(0)}% above target`
      });
    }

    if (metrics.budgetCompliance > 1.15) {
      recommendations.push({
        priority: 'warning',
        action: 'Reduce daily budget caps',
        reason: `Spending ${((metrics.budgetCompliance - 1) * 100).toFixed(0)}% over budget`
      });
    }
  } else if (decision.tier === 'alertImmediately') {
    recommendations.push({
      priority: 'critical',
      action: 'IMMEDIATE ACTION REQUIRED',
      reason: `Critical threshold exceeded: ${decision.trigger}`
    });

    if (metrics.actualCAC > 20) {
      recommendations.push({
        priority: 'critical',
        action: 'Pause underperforming campaigns',
        reason: `CAC at CHF ${metrics.actualCAC?.toFixed(2)} is unsustainable`
      });
    }
  }

  return recommendations;
}

/**
 * Generate next steps
 */
function generateNextSteps(metrics, decision) {
  const steps = [];

  if (decision.tier === 'autoExecute') {
    steps.push('Monitor CAC daily next week');
    steps.push('Continue A/B testing ad creative');
  } else if (decision.tier === 'requestApproval') {
    steps.push('Review detailed campaign analytics');
    steps.push('Prepare cost-benefit analysis for budget reallocation');
    steps.push('Await approval before implementing changes');
  } else {
    steps.push('Execute immediate actions within 2 hours');
    steps.push('Monitor recovery metrics every 4 hours');
    steps.push('Escalate to leadership if no improvement in 48h');
  }

  return steps;
}

/**
 * Generate optimization recommendations
 */
function generateOptimizations(metrics, decision) {
  const optimizations = [];

  if (metrics.actualCAC && metrics.actualCAC < metrics.targetCAC * 0.9) {
    optimizations.push({
      channel: 'Google Ads',
      action: 'Increase daily budget by 10%',
      expectedImpact: '+8% leads at current CAC'
    });
  }

  if (metrics.actualROAS && metrics.actualROAS > metrics.targetROAS) {
    optimizations.push({
      channel: 'Retargeting',
      action: 'Expand retargeting audience',
      expectedImpact: `ROAS ${metrics.actualROAS.toFixed(1)}x shows strong performance`
    });
  }

  return optimizations;
}

/**
 * Send Slack notification
 */
async function sendSlackNotification(report) {
  if (testMode) {
    console.log('\n📢 Slack notification (TEST MODE - not sent):');
    console.log(JSON.stringify(formatSlackMessage(report), null, 2));
    return;
  }

  const webhookUrl = process.env.SLACK_WEBHOOK_URL;
  if (!webhookUrl) {
    console.warn('⚠️  SLACK_WEBHOOK_URL not configured, skipping notification');
    return;
  }

  try {
    const message = formatSlackMessage(report);

    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(message)
    });

    if (response.ok) {
      console.log('✅ Slack notification sent');
    } else {
      console.error('❌ Slack notification failed:', response.statusText);
    }
  } catch (error) {
    console.error('❌ Slack notification error:', error.message);
  }
}

/**
 * Format Slack message
 */
function formatSlackMessage(report) {
  const emoji = {
    critical: '🚨',
    warning: '⚠️',
    info: 'ℹ️',
    success: '✅'
  };

  const icon = emoji[report.priority] || 'ℹ️';

  let text = '';

  if (report.type === 'weekly') {
    text = `${icon} Weekly Performance Summary - Week of ${report.period.from}\n\n`;
    text += `*Performance:*\n`;
    text += `• CAC: CHF ${report.performance.cac?.toFixed(2) || 'N/A'} (Target: CHF ${report.performance.cacTarget})\n`;
    text += `• ROAS: ${report.performance.roas?.toFixed(1) || 'N/A'}x\n`;
    text += `• Spend: CHF ${report.performance.spend?.toFixed(2) || 'N/A'}\n\n`;

    if (report.recommendations.length > 0) {
      text += `*Recommendations:*\n`;
      report.recommendations.forEach(rec => {
        text += `• ${rec.action}\n  _${rec.reason}_\n`;
      });
    }

    if (report.nextSteps.length > 0) {
      text += `\n*Next Steps:*\n`;
      report.nextSteps.forEach(step => {
        text += `• ${step}\n`;
      });
    }
  } else if (report.type === 'monthly') {
    text = `${icon} Monthly Budget Plan - ${report.month}\n\n`;
    text += `*Previous Month (${report.previousMonth.name}):*\n`;
    text += `• Budgeted: CHF ${report.previousMonth.budgeted?.toFixed(2) || 'N/A'}\n`;
    text += `• Actual: CHF ${report.previousMonth.actual?.toFixed(2) || 'N/A'}\n`;
    text += `• Variance: ${report.previousMonth.variance}\n\n`;

    text += `*Next Month Plan:*\n`;
    text += `• Budget: CHF ${report.nextMonth.budgeted?.toFixed(2) || 'N/A'}\n`;
    text += `• Expected Leads: ${report.nextMonth.expectedLeads}\n`;
    text += `• Strategy: ${report.nextMonth.strategy}\n`;

    if (report.optimizations && report.optimizations.length > 0) {
      text += `\n*Optimizations:*\n`;
      report.optimizations.forEach(opt => {
        text += `• ${opt.channel}: ${opt.action}\n  _${opt.expectedImpact}_\n`;
      });
    }
  }

  return { text };
}

/**
 * Save report to file
 */
async function saveReport(report) {
  const timestamp = new Date().toISOString().split('T')[0];
  const filename = `strategist-${report.type}-${timestamp}.json`;
  const filepath = path.join(REPORTS_DIR, filename);

  await fs.writeFile(filepath, JSON.stringify(report, null, 2));
  console.log(`\n💾 Report saved: ${filename}`);

  return filepath;
}

/**
 * Main execution
 */
async function main() {
  try {
    // Determine execution type
    const now = new Date();
    const isFirstOfMonth = now.getDate() === 1;
    const isFriday = now.getDay() === 5;

    const runWeekly = forceWeekly || (!forceMonthly && isFriday);
    const runMonthly = forceMonthly || isFirstOfMonth;

    console.log(`📅 Execution: ${runWeekly ? 'Weekly Review' : ''} ${runMonthly ? 'Monthly Planning' : ''}\n`);

    // Step 1: Execute skills to gather data
    console.log('🔄 Step 1: Data Collection\n');

    await executeSkill('marketing-health-check');
    await executeSkill('revenue-analysis');
    await executeSkill('google-ads-performance');
    await executeSkill('meta-ads-performance');
    await executeSkill('lead-funnel-analysis');

    // Step 2: Load collected data
    console.log('📖 Step 2: Loading Data\n');

    const googleAdsData = await loadData('google-ads-spend-data.json');
    const metaAdsData = await loadData('meta-ads-spend-data.json');
    const budgetData = await loadData('marketing-budget-2026.json');
    const revenueData = await loadData('5-year-revenue-analysis.json');

    // Step 3: Calculate metrics
    console.log('📊 Step 3: Calculating Metrics\n');

    const metrics = calculateMetrics({
      googleAdsData,
      metaAdsData,
      budgetData,
      revenueData
    });

    console.log('Current Metrics:');
    console.log(`  CAC: CHF ${metrics.actualCAC?.toFixed(2) || 'N/A'} (target: ${metrics.targetCAC})`);
    console.log(`  ROAS: ${metrics.actualROAS?.toFixed(1) || 'N/A'}x (target: ${metrics.targetROAS}x)`);
    console.log(`  Spend: CHF ${metrics.actualSpend?.toFixed(2) || 'N/A'}\n`);

    // Step 4: Apply decision framework
    console.log('🎯 Step 4: Applying Decision Framework\n');

    const decision = applyDecisionFramework(metrics);

    console.log(`Decision: ${decision.tier}`);
    console.log(`Priority: ${decision.priority}`);
    if (decision.trigger) {
      console.log(`Trigger: ${decision.trigger}`);
    }
    console.log('');

    // Step 5: Generate appropriate report
    console.log('📝 Step 5: Generating Report\n');

    let report;
    if (runMonthly) {
      report = generateMonthlyReport(metrics, decision, budgetData);
    } else {
      report = generateWeeklyReport(metrics, decision);
    }

    // Step 6: Save report
    await saveReport(report);

    // Step 7: Send Slack notification
    console.log('\n📢 Step 6: Sending Notification\n');
    await sendSlackNotification(report);

    // Summary
    console.log('\n✅ Agent execution completed successfully');
    console.log(`   Report type: ${report.type}`);
    console.log(`   Decision tier: ${decision.tier}`);
    console.log(`   Priority: ${decision.priority}`);

    process.exit(0);

  } catch (error) {
    console.error('\n❌ Agent execution failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the agent
main();

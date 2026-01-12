#!/usr/bin/env node

/**
 * budget-guardian Agent - Daily Budget Monitoring
 *
 * Monitors daily spend, budget thresholds, CAC, and ROAS with real-time alerts.
 *
 * Usage:
 *   node run.js                    # Normal daily check
 *   node run.js --test-mode        # Test without Slack notifications
 *   node run.js --real-time        # Run checks every 4 hours
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

// Execution mode
const args = process.argv.slice(2);
const testMode = args.includes('--test-mode');
const realTimeMode = args.includes('--real-time');

// Output paths
const REPORTS_DIR = path.join(__dirname, '../../../landing/docs/wip');
const ALERT_LOG = path.join(REPORTS_DIR, 'guardian-alerts.log');

console.log('🟣 MyArmy Budget Guardian Agent');
console.log('================================\n');

if (testMode) {
  console.log('⚠️  TEST MODE: Slack notifications disabled\n');
}

if (realTimeMode) {
  console.log('🔄 REAL-TIME MODE: Checking every 4 hours\n');
}

/**
 * Execute a skill and return its output
 */
async function executeSkill(skillName, args = []) {
  console.log(`📊 Executing skill: ${skillName}`);

  try {
    const scriptPath = path.join(__dirname, '../../../landing/scripts');

    const scriptMap = {
      'google-ads-performance': 'fetch-google-ads-spend.mjs',
      'meta-ads-performance': 'fetch-meta-ads-spend.mjs',
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
 * Load data from JSON file
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
 * Calculate current metrics
 */
function calculateMetrics(googleAdsData, metaAdsData, budgetData) {
  // Merge ad channels for blended metrics
  const adData = mergeAdChannels(googleAdsData, metaAdsData);
  const now = new Date();
  const currentMonth = now.getMonth() + 1;
  const daysInMonth = new Date(now.getFullYear(), currentMonth, 0).getDate();
  const daysElapsed = now.getDate();
  const daysRemaining = daysInMonth - daysElapsed;

  const monthlyBudget = budgetData?.months?.[currentMonth - 1]?.total || 0;
  const monthToDateSpend = adData?.totals?.totalSpend || 0;
  const yesterdaySpend = adData?.daily?.[adData.daily?.length - 1]?.spend_chf || 0;
  const currentCAC = adData?.totals?.averageCAC || null;
  const currentROAS = adData?.totals?.roas || null;
  const channels = adData?.channels || null;

  const expectedDailyRate = monthlyBudget / daysInMonth;
  const budgetPercentage = monthlyBudget > 0 ? (monthToDateSpend / monthlyBudget) * 100 : 0;
  const timePercentage = (daysElapsed / daysInMonth) * 100;
  const spendRate = budgetPercentage - timePercentage;

  return {
    monthlyBudget,
    monthToDateSpend,
    budgetPercentage,
    daysElapsed,
    daysRemaining,
    daysInMonth,
    timePercentage,
    spendRate,
    yesterdaySpend,
    expectedDailyRate,
    currentCAC,
    currentROAS,
    targetCAC: agentConfig.configuration.targetCAC,
    targetROAS: agentConfig.configuration.targetROAS,
    minROAS: agentConfig.configuration.minROAS
  };
}

/**
 * Check alert conditions
 */
function checkAlertConditions(metrics) {
  const alerts = [];

  // Budget threshold checks
  if (metrics.budgetPercentage >= 100) {
    alerts.push({
      level: 'CRITICAL',
      type: 'budget',
      priority: 'exceeded',
      message: `Budget exceeded: ${metrics.budgetPercentage.toFixed(1)}% spent`,
      value: metrics.budgetPercentage,
      threshold: 100
    });
  } else if (metrics.budgetPercentage >= 90) {
    alerts.push({
      level: 'CRITICAL',
      type: 'budget',
      priority: 'critical',
      message: `Budget critical: ${metrics.budgetPercentage.toFixed(1)}% spent`,
      value: metrics.budgetPercentage,
      threshold: 90
    });
  } else if (metrics.budgetPercentage >= 80) {
    alerts.push({
      level: 'WARNING',
      type: 'budget',
      priority: 'warning',
      message: `Budget approaching limit: ${metrics.budgetPercentage.toFixed(1)}% spent`,
      value: metrics.budgetPercentage,
      threshold: 80
    });
  }

  // CAC threshold checks
  if (metrics.currentCAC) {
    if (metrics.currentCAC > 20.0) {
      alerts.push({
        level: 'CRITICAL',
        type: 'cac',
        priority: 'critical',
        message: `CAC critical: CHF ${metrics.currentCAC.toFixed(2)} exceeds CHF 20`,
        value: metrics.currentCAC,
        threshold: 20.0
      });
    } else if (metrics.currentCAC > 17.0) {
      alerts.push({
        level: 'WARNING',
        type: 'cac',
        priority: 'warning',
        message: `CAC elevated: CHF ${metrics.currentCAC.toFixed(2)} above CHF 17`,
        value: metrics.currentCAC,
        threshold: 17.0
      });
    }
  }

  // Daily spend rate checks
  if (metrics.yesterdaySpend && metrics.expectedDailyRate) {
    const dailyVariance = ((metrics.yesterdaySpend - metrics.expectedDailyRate) / metrics.expectedDailyRate) * 100;

    if (dailyVariance > 50) {
      alerts.push({
        level: 'CRITICAL',
        type: 'daily_spend',
        priority: 'critical',
        message: `Daily spend critical: ${dailyVariance.toFixed(0)}% above expected`,
        value: metrics.yesterdaySpend,
        threshold: metrics.expectedDailyRate * 1.5
      });
    } else if (dailyVariance > 20) {
      alerts.push({
        level: 'WARNING',
        type: 'daily_spend',
        priority: 'warning',
        message: `Daily spend elevated: ${dailyVariance.toFixed(0)}% above expected`,
        value: metrics.yesterdaySpend,
        threshold: metrics.expectedDailyRate * 1.2
      });
    }
  }

  // ROAS threshold checks
  if (metrics.currentROAS) {
    if (metrics.currentROAS < 2.0) {
      alerts.push({
        level: 'CRITICAL',
        type: 'roas',
        priority: 'critical',
        message: `ROAS critical: ${metrics.currentROAS.toFixed(1)}x below minimum 2.0x`,
        value: metrics.currentROAS,
        threshold: 2.0
      });
    } else if (metrics.currentROAS < 2.5) {
      alerts.push({
        level: 'WARNING',
        type: 'roas',
        priority: 'warning',
        message: `ROAS below target: ${metrics.currentROAS.toFixed(1)}x (target: 3.0x)`,
        value: metrics.currentROAS,
        threshold: 2.5
      });
    }
  }

  // If no alerts, add info status
  if (alerts.length === 0) {
    alerts.push({
      level: 'INFO',
      type: 'status',
      priority: 'info',
      message: 'Budget on track, no issues detected'
    });
  }

  return alerts;
}

/**
 * Generate recommendations based on alerts
 */
function generateRecommendations(metrics, alerts) {
  const recommendations = [];

  const hasCritical = alerts.some(a => a.level === 'CRITICAL');
  const hasWarning = alerts.some(a => a.level === 'WARNING');

  if (!hasCritical && !hasWarning) {
    recommendations.push('Continue current strategy');
    recommendations.push(`Budget remaining: CHF ${(metrics.monthlyBudget - metrics.monthToDateSpend).toFixed(2)}`);
    return recommendations;
  }

  // Budget-specific recommendations
  const budgetAlert = alerts.find(a => a.type === 'budget');
  if (budgetAlert) {
    if (budgetAlert.level === 'CRITICAL') {
      if (metrics.budgetPercentage >= 100) {
        recommendations.push('🛑 Set daily cap to CHF 0 (pause all spend)');
        recommendations.push('Escalate to leadership for budget extension decision');
      } else {
        recommendations.push(`Reduce daily cap by 30-50% immediately`);
        recommendations.push(`Pause 2-3 lowest-performing campaigns`);
        recommendations.push(`Monitor hourly until resolved`);
      }
    } else {
      recommendations.push(`Reduce daily cap by 10-15%`);
      recommendations.push(`Prepare to pause campaigns if trend continues`);
    }
  }

  // CAC-specific recommendations
  const cacAlert = alerts.find(a => a.type === 'cac');
  if (cacAlert) {
    if (cacAlert.level === 'CRITICAL') {
      recommendations.push(`Pause campaigns with CAC >CHF 25`);
      recommendations.push(`Reduce Google Ads daily cap by 40%`);
      recommendations.push(`Activate retargeting campaigns (lower CAC)`);
    } else {
      recommendations.push(`Review ad creative performance`);
      recommendations.push(`Check targeting settings`);
      recommendations.push(`Test new ad variants`);
    }
  }

  // Daily spend recommendations
  const dailySpendAlert = alerts.find(a => a.type === 'daily_spend');
  if (dailySpendAlert && dailySpendAlert.level === 'CRITICAL') {
    recommendations.push(`Immediate: Reduce daily cap to CHF ${(metrics.expectedDailyRate * 0.8).toFixed(2)}`);
    recommendations.push(`Check for unauthorized bid changes`);
  }

  // ROAS recommendations
  const roasAlert = alerts.find(a => a.type === 'roas');
  if (roasAlert) {
    if (roasAlert.level === 'CRITICAL') {
      recommendations.push(`Pause all campaigns with ROAS <1.5x`);
      recommendations.push(`Emergency budget reduction (50%)`);
      recommendations.push(`Review entire marketing strategy`);
    } else {
      recommendations.push(`Optimize landing pages`);
      recommendations.push(`Shift budget to high-ROAS channels`);
    }
  }

  return recommendations;
}

/**
 * Generate daily report
 */
function generateDailyReport(metrics, alerts) {
  const now = new Date();
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);

  const highestAlertLevel = alerts.some(a => a.level === 'CRITICAL') ? 'critical' :
                             alerts.some(a => a.level === 'WARNING') ? 'warning' : 'healthy';

  const report = {
    date: now.toISOString().split('T')[0],
    type: 'daily',
    monthToDate: {
      daysElapsed: metrics.daysElapsed,
      daysRemaining: metrics.daysRemaining,
      budgeted: metrics.monthlyBudget,
      spent: metrics.monthToDateSpend,
      percentage: metrics.budgetPercentage,
      status: highestAlertLevel,
      spendRate: metrics.spendRate > 0 ? `+${metrics.spendRate.toFixed(1)}%` : `${metrics.spendRate.toFixed(1)}%`
    },
    yesterday: {
      date: yesterday.toISOString().split('T')[0],
      spent: metrics.yesterdaySpend,
      expectedDailyRate: metrics.expectedDailyRate,
      variance: metrics.yesterdaySpend && metrics.expectedDailyRate ?
        ((metrics.yesterdaySpend - metrics.expectedDailyRate) / metrics.expectedDailyRate * 100).toFixed(1) + '%' :
        'N/A',
      cac: metrics.currentCAC,
      roas: metrics.currentROAS
    },
    alerts: alerts.map(a => ({
      level: a.level,
      type: a.type,
      message: a.message
    })),
    recommendations: generateRecommendations(metrics, alerts)
  };

  return report;
}

/**
 * Log alert to file
 */
async function logAlert(alert, metrics) {
  const timestamp = new Date().toISOString();
  const logEntry = `[${timestamp}] ${alert.level}: ${alert.message} (Budget: ${metrics.budgetPercentage.toFixed(1)}%, CAC: CHF ${metrics.currentCAC?.toFixed(2) || 'N/A'})\n`;

  try {
    await fs.appendFile(ALERT_LOG, logEntry);
  } catch (error) {
    console.error('Failed to write to alert log:', error.message);
  }
}

/**
 * Send Slack notification
 */
async function sendSlackNotification(report, alerts) {
  if (testMode) {
    console.log('\n📢 Slack notification (TEST MODE - not sent):');
    console.log(JSON.stringify(formatSlackMessage(report, alerts), null, 2));
    return;
  }

  const webhookUrl = process.env.SLACK_WEBHOOK_URL;
  if (!webhookUrl) {
    console.warn('⚠️  SLACK_WEBHOOK_URL not configured, skipping notification');
    return;
  }

  // Only send Slack notifications for warnings and critical alerts
  const shouldNotify = alerts.some(a => a.level !== 'INFO');

  if (!shouldNotify) {
    console.log('ℹ️  No alerts to notify - skipping Slack notification');
    return;
  }

  try {
    const message = formatSlackMessage(report, alerts);

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
function formatSlackMessage(report, alerts) {
  const emoji = {
    CRITICAL: '🚨',
    WARNING: '⚠️',
    INFO: 'ℹ️'
  };

  const highestLevel = alerts.find(a => a.level === 'CRITICAL') ? 'CRITICAL' :
                       alerts.find(a => a.level === 'WARNING') ? 'WARNING' : 'INFO';

  const icon = emoji[highestLevel];

  let text = `${icon} Daily Budget Status - ${report.date}\n\n`;

  text += `💰 Budget: CHF ${report.monthToDate.spent.toFixed(2)} / CHF ${report.monthToDate.budgeted.toFixed(2)} (${report.monthToDate.percentage.toFixed(1)}%)\n`;
  text += `   Status: ${report.monthToDate.status === 'healthy' ? '✅ On track' : report.monthToDate.status === 'warning' ? '⚠️ Attention needed' : '🚨 Critical'}\n`;
  text += `   Days: ${report.monthToDate.daysElapsed} elapsed / ${report.monthToDate.daysRemaining} remaining\n`;
  text += `   Spend rate: ${report.monthToDate.spendRate}\n\n`;

  if (report.yesterday.spent) {
    text += `📊 Yesterday:\n`;
    text += `   Spend: CHF ${report.yesterday.spent.toFixed(2)} (expected: CHF ${report.yesterday.expectedDailyRate.toFixed(2)})\n`;
    if (report.yesterday.cac) {
      text += `   CAC: CHF ${report.yesterday.cac.toFixed(2)}\n`;
    }
    if (report.yesterday.roas) {
      text += `   ROAS: ${report.yesterday.roas.toFixed(1)}x\n`;
    }
    text += '\n';
  }

  if (alerts.some(a => a.level !== 'INFO')) {
    text += `🚨 Alerts:\n`;
    alerts.filter(a => a.level !== 'INFO').forEach(alert => {
      text += `   ${emoji[alert.level]} ${alert.message}\n`;
    });
    text += '\n';
  }

  if (report.recommendations.length > 0) {
    text += `🎯 Recommendations:\n`;
    report.recommendations.forEach(rec => {
      text += `   • ${rec}\n`;
    });
  }

  return { text };
}

/**
 * Save report to file
 */
async function saveReport(report) {
  const filename = `guardian-daily-${report.date}.json`;
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
    console.log('🔄 Step 1: Data Collection\n');

    await executeSkill('marketing-health-check');
    await executeSkill('google-ads-performance');
    await executeSkill('meta-ads-performance');
    await executeSkill('budget-calculator');

    console.log('📖 Step 2: Loading Data\n');

    const googleAdsData = await loadData('google-ads-spend-data.json');
    const metaAdsData = await loadData('meta-ads-spend-data.json');
    const budgetData = await loadData('marketing-budget-2026.json');

    console.log('📊 Step 3: Calculating Metrics\n');

    const metrics = calculateMetrics(googleAdsData, metaAdsData, budgetData);

    console.log('Current Status:');
    console.log(`  Budget: ${metrics.budgetPercentage.toFixed(1)}% (${metrics.daysElapsed}/${metrics.daysInMonth} days)`);
    console.log(`  Spend: CHF ${metrics.monthToDateSpend.toFixed(2)} / CHF ${metrics.monthlyBudget.toFixed(2)}`);
    console.log(`  CAC: CHF ${metrics.currentCAC?.toFixed(2) || 'N/A'}`);
    console.log(`  ROAS: ${metrics.currentROAS?.toFixed(1) || 'N/A'}x\n`);

    console.log('🚨 Step 4: Checking Alert Conditions\n');

    const alerts = checkAlertConditions(metrics);

    alerts.forEach(alert => {
      const icon = alert.level === 'CRITICAL' ? '🚨' :
                   alert.level === 'WARNING' ? '⚠️' : 'ℹ️';
      console.log(`${icon} ${alert.level}: ${alert.message}`);
    });
    console.log('');

    console.log('📝 Step 5: Generating Report\n');

    const report = generateDailyReport(metrics, alerts);

    await saveReport(report);

    console.log('\n📢 Step 6: Sending Notifications\n');

    // Log critical and warning alerts
    for (const alert of alerts.filter(a => a.level !== 'INFO')) {
      await logAlert(alert, metrics);
    }

    await sendSlackNotification(report, alerts);

    console.log('\n✅ Agent execution completed successfully');
    console.log(`   Status: ${report.monthToDate.status}`);
    console.log(`   Alerts: ${alerts.filter(a => a.level !== 'INFO').length}`);

    // Real-time mode: wait and run again
    if (realTimeMode) {
      const checkIntervalMs = agentConfig.configuration.checkIntervalHours * 60 * 60 * 1000;
      console.log(`\n🔄 Waiting ${agentConfig.configuration.checkIntervalHours} hours until next check...`);
      setTimeout(() => main(), checkIntervalMs);
    } else {
      process.exit(0);
    }

  } catch (error) {
    console.error('\n❌ Agent execution failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the agent
main();

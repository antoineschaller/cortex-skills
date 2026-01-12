#!/usr/bin/env node

/**
 * lead-quality-optimizer Agent - Weekly Lead Quality Analysis
 *
 * Executes weekly funnel analysis and lead quality optimization
 * with automated recommendations for conversion improvements.
 *
 * Usage:
 *   node run.js                    # Normal execution (last 7 days)
 *   node run.js --test-mode        # Test without Slack notifications
 *   node run.js --days=14          # Analyze last 14 days
 *   node run.js --from=2026-01-01 --to=2026-01-15  # Custom date range
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
const daysArg = args.find(arg => arg.startsWith('--days='));
const fromArg = args.find(arg => arg.startsWith('--from='));
const toArg = args.find(arg => arg.startsWith('--to='));

const analysisWindowDays = daysArg
  ? parseInt(daysArg.split('=')[1])
  : agentConfig.configuration.analysisWindowDays;

// Output paths
const REPORTS_DIR = path.join(__dirname, '../../../landing/docs/wip');

console.log('🟣 MyArmy Lead Quality Optimizer Agent');
console.log('======================================\n');

if (testMode) {
  console.log('⚠️  TEST MODE: Slack notifications disabled\n');
}

console.log(`📅 Analysis Window: Last ${analysisWindowDays} days\n`);

/**
 * Execute a skill and return its output
 */
async function executeSkill(skillName, args = []) {
  console.log(`📊 Executing skill: ${skillName}`);

  try {
    const scriptPath = path.join(__dirname, '../../../landing/scripts');

    // Map skill names to actual scripts
    const scriptMap = {
      'lead-funnel-analysis': 'fetch-real-lead-data.mjs',
      'google-ads-performance': 'fetch-google-ads-spend.mjs',
      'meta-ads-performance': 'fetch-meta-ads-spend.mjs',
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
 * Calculate lead quality metrics
 */
function calculateLeadMetrics(leadData, googleAdsData) {
  if (!leadData || !leadData.leads || leadData.leads.length === 0) {
    console.warn('⚠️  No lead data available for analysis');
    return null;
  }

  const leads = leadData.leads;
  const totalLeads = leads.length;

  // Check minimum sample size
  if (totalLeads < agentConfig.configuration.minimumSampleSize) {
    console.warn(`⚠️  Sample size (${totalLeads}) below minimum (${agentConfig.configuration.minimumSampleSize})`);
  }

  // Calculate conversion rate
  const paidCustomers = leads.filter(lead => lead.converted || lead.status === 'customer').length;
  const conversionRate = totalLeads > 0 ? paidCustomers / totalLeads : 0;

  // Calculate average lead score
  const leadScores = leads.map(lead => calculateLeadScore(lead));
  const averageLeadScore = leadScores.reduce((a, b) => a + b, 0) / leadScores.length;

  // Analyze funnel stages
  const funnelBreakdown = analyzeFunnelStages(leads);

  // Identify bottlenecks
  const bottlenecks = identifyBottlenecks(funnelBreakdown);

  // Calculate time to conversion
  const conversionTimes = leads
    .filter(lead => lead.converted && lead.created_at && lead.converted_at)
    .map(lead => {
      const created = new Date(lead.created_at);
      const converted = new Date(lead.converted_at);
      return (converted - created) / (1000 * 60 * 60 * 24); // days
    });

  const averageTimeToConversion = conversionTimes.length > 0
    ? conversionTimes.reduce((a, b) => a + b, 0) / conversionTimes.length
    : null;

  // Form completion rate
  const inquiryStarted = funnelBreakdown.find(stage => stage.stage === 'inquiry_started')?.count || 0;
  const formSubmitted = funnelBreakdown.find(stage => stage.stage === 'form_submitted')?.count || 0;
  const formCompletionRate = inquiryStarted > 0 ? formSubmitted / inquiryStarted : 0;

  return {
    totalLeads,
    paidCustomers,
    conversionRate,
    averageLeadScore,
    funnelBreakdown,
    bottlenecks,
    averageTimeToConversion,
    formCompletionRate,
    sampleSizeAdequate: totalLeads >= agentConfig.configuration.minimumSampleSize
  };
}

/**
 * Calculate lead score based on engagement events
 */
function calculateLeadScore(lead) {
  let score = 0;

  // Map events to scores from agent configuration
  const funnelStages = agentConfig.funnelStages;

  // Check which stages the lead has reached
  if (lead.page_viewed) score = Math.max(score, funnelStages.find(s => s.name === 'page_view')?.score || 0);
  if (lead.content_viewed) score = Math.max(score, funnelStages.find(s => s.name === 'content_view')?.score || 0);
  if (lead.inquiry_started) score = Math.max(score, funnelStages.find(s => s.name === 'inquiry_started')?.score || 0);
  if (lead.contact_info) score = Math.max(score, funnelStages.find(s => s.name === 'contact_info')?.score || 0);
  if (lead.whatsapp_contacted) score = Math.max(score, funnelStages.find(s => s.name === 'whatsapp_contact')?.score || 0);
  if (lead.form_submitted) score = Math.max(score, funnelStages.find(s => s.name === 'form_submitted')?.score || 0);

  return score;
}

/**
 * Analyze funnel stages and calculate drop-offs
 */
function analyzeFunnelStages(leads) {
  const stages = agentConfig.funnelStages.map(stage => ({
    stage: stage.name,
    event: stage.event,
    score: stage.score,
    count: 0,
    percentage: 0,
    nextStageConversion: 0
  }));

  // Count leads at each stage
  leads.forEach(lead => {
    if (lead.page_viewed) stages[0].count++;
    if (lead.content_viewed) stages[1].count++;
    if (lead.inquiry_started) stages[2].count++;
    if (lead.contact_info) stages[3].count++;
    if (lead.whatsapp_contacted) stages[4].count++;
    if (lead.form_submitted) stages[5].count++;
  });

  // Calculate percentages and conversion rates
  const totalLeads = stages[0].count || 1; // Avoid division by zero

  stages.forEach((stage, index) => {
    stage.percentage = (stage.count / totalLeads) * 100;

    if (index < stages.length - 1) {
      const nextStage = stages[index + 1];
      stage.nextStageConversion = stage.count > 0 ? nextStage.count / stage.count : 0;
    }
  });

  return stages;
}

/**
 * Identify funnel bottlenecks
 */
function identifyBottlenecks(funnelBreakdown) {
  const bottlenecks = [];
  const { warning, critical } = agentConfig.qualityMetrics.funnelDropoff;

  funnelBreakdown.forEach((stage, index) => {
    if (index < funnelBreakdown.length - 1) {
      const dropoffRate = 1 - stage.nextStageConversion;
      const nextStage = funnelBreakdown[index + 1];

      if (dropoffRate >= critical) {
        bottlenecks.push({
          stage: `${stage.stage} → ${nextStage.stage}`,
          dropoffRate: dropoffRate,
          severity: 'critical',
          reason: `Critical drop-off: ${(dropoffRate * 100).toFixed(0)}% of leads lost`
        });
      } else if (dropoffRate >= warning) {
        bottlenecks.push({
          stage: `${stage.stage} → ${nextStage.stage}`,
          dropoffRate: dropoffRate,
          severity: 'warning',
          reason: `High drop-off: ${(dropoffRate * 100).toFixed(0)}% of leads lost`
        });
      }
    }
  });

  return bottlenecks;
}

/**
 * Generate optimization recommendations
 */
function generateRecommendations(metrics) {
  const recommendations = [];
  const config = agentConfig.qualityMetrics;

  // Conversion rate recommendations
  if (metrics.conversionRate < config.conversionRate.critical) {
    recommendations.push({
      priority: 'critical',
      stage: 'overall',
      action: 'URGENT: Conversion rate critically low',
      expectedImpact: `Current: ${(metrics.conversionRate * 100).toFixed(1)}%, Target: ${(config.conversionRate.target * 100).toFixed(0)}%`
    });
  } else if (metrics.conversionRate < config.conversionRate.warning) {
    recommendations.push({
      priority: 'warning',
      stage: 'overall',
      action: 'Improve overall conversion rate',
      expectedImpact: `Gap: ${((config.conversionRate.target - metrics.conversionRate) * 100).toFixed(1)}%`
    });
  }

  // Lead score recommendations
  if (metrics.averageLeadScore < config.leadScore.critical) {
    recommendations.push({
      priority: 'critical',
      stage: 'targeting',
      action: 'Review ad targeting - attracting low-quality traffic',
      expectedImpact: `Avg score: ${metrics.averageLeadScore.toFixed(0)}, Target: ${config.leadScore.target}`
    });
  } else if (metrics.averageLeadScore < config.leadScore.warning) {
    recommendations.push({
      priority: 'warning',
      stage: 'engagement',
      action: 'Improve content engagement and CTAs',
      expectedImpact: `Increase avg score from ${metrics.averageLeadScore.toFixed(0)} to ${config.leadScore.target}`
    });
  }

  // Bottleneck-specific recommendations
  metrics.bottlenecks.forEach(bottleneck => {
    const [fromStage, toStage] = bottleneck.stage.split(' → ');

    let action = '';
    let expectedImpact = '';

    if (fromStage === 'content_view' && toStage === 'inquiry_started') {
      action = 'Improve CTA visibility and value proposition';
      expectedImpact = 'Increase inquiry starts by 10-15%';
    } else if (fromStage === 'inquiry_started' && toStage === 'contact_info') {
      action = 'Reduce form friction - minimize required fields';
      expectedImpact = 'Increase form starts by 15-20%';
    } else if (fromStage === 'contact_info' && toStage === 'whatsapp_contact') {
      action = 'Add prominent WhatsApp CTA after email capture';
      expectedImpact = 'Increase WhatsApp contacts by 20-30%';
    } else if (fromStage === 'whatsapp_contact' && toStage === 'form_submitted') {
      action = 'Improve WhatsApp response time and templates';
      expectedImpact = 'Increase submissions by 10-15%';
    } else {
      action = `Optimize ${fromStage} stage`;
      expectedImpact = `Reduce drop-off from ${(bottleneck.dropoffRate * 100).toFixed(0)}%`;
    }

    recommendations.push({
      priority: bottleneck.severity,
      stage: fromStage,
      action: action,
      expectedImpact: expectedImpact
    });
  });

  // Form completion recommendations
  if (metrics.formCompletionRate < config.formCompletionRate.critical) {
    recommendations.push({
      priority: 'critical',
      stage: 'form_completion',
      action: 'Critical form issues - review UX immediately',
      expectedImpact: `Only ${(metrics.formCompletionRate * 100).toFixed(0)}% completing form`
    });
  } else if (metrics.formCompletionRate < config.formCompletionRate.warning) {
    recommendations.push({
      priority: 'warning',
      stage: 'form_completion',
      action: 'Reduce form friction and add progress indicators',
      expectedImpact: `Increase from ${(metrics.formCompletionRate * 100).toFixed(0)}% to ${(config.formCompletionRate.target * 100).toFixed(0)}%`
    });
  }

  // Time to conversion recommendations
  if (metrics.averageTimeToConversion > config.timeToConversion.critical) {
    recommendations.push({
      priority: 'critical',
      stage: 'nurturing',
      action: 'Implement aggressive lead nurturing sequence',
      expectedImpact: `Reduce from ${metrics.averageTimeToConversion.toFixed(1)} to ${config.timeToConversion.target} days`
    });
  } else if (metrics.averageTimeToConversion > config.timeToConversion.warning) {
    recommendations.push({
      priority: 'warning',
      stage: 'nurturing',
      action: 'Improve follow-up speed and nurturing',
      expectedImpact: `Target: ${config.timeToConversion.target} days or less`
    });
  }

  return recommendations;
}

/**
 * Determine overall status
 */
function determineStatus(metrics) {
  const config = agentConfig.qualityMetrics;

  const criticalIssues = [
    metrics.conversionRate < config.conversionRate.critical,
    metrics.averageLeadScore < config.leadScore.critical,
    metrics.formCompletionRate < config.formCompletionRate.critical,
    metrics.bottlenecks.some(b => b.severity === 'critical')
  ].filter(Boolean).length;

  if (criticalIssues > 0) return 'critical';

  const warningIssues = [
    metrics.conversionRate < config.conversionRate.warning,
    metrics.averageLeadScore < config.leadScore.warning,
    metrics.formCompletionRate < config.formCompletionRate.warning,
    metrics.bottlenecks.some(b => b.severity === 'warning')
  ].filter(Boolean).length;

  if (warningIssues > 0) return 'warning';

  return 'healthy';
}

/**
 * Generate weekly report
 */
function generateWeeklyReport(metrics) {
  const now = new Date();
  const daysAgo = new Date(now);
  daysAgo.setDate(daysAgo.getDate() - analysisWindowDays);

  const status = determineStatus(metrics);

  const report = {
    date: now.toISOString().split('T')[0],
    type: 'weekly',
    period: {
      from: daysAgo.toISOString().split('T')[0],
      to: now.toISOString().split('T')[0],
      days: analysisWindowDays
    },
    overview: {
      totalLeads: metrics.totalLeads,
      paidCustomers: metrics.paidCustomers,
      conversionRate: parseFloat((metrics.conversionRate * 100).toFixed(1)) + '%',
      averageLeadScore: Math.round(metrics.averageLeadScore),
      status: status,
      sampleSizeAdequate: metrics.sampleSizeAdequate
    },
    funnelBreakdown: metrics.funnelBreakdown.map(stage => ({
      stage: stage.stage,
      count: stage.count,
      percentage: parseFloat(stage.percentage.toFixed(1)),
      nextStageConversion: parseFloat((stage.nextStageConversion * 100).toFixed(1)) + '%'
    })),
    bottlenecks: metrics.bottlenecks,
    recommendations: generateRecommendations(metrics),
    qualityMetrics: {
      formCompletionRate: parseFloat((metrics.formCompletionRate * 100).toFixed(1)) + '%',
      averageTimeToConversion: metrics.averageTimeToConversion
        ? parseFloat(metrics.averageTimeToConversion.toFixed(1)) + ' days'
        : 'N/A'
    }
  };

  return report;
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
    healthy: '✅',
    info: 'ℹ️'
  };

  const icon = emoji[report.overview.status] || 'ℹ️';

  let text = `${icon} Weekly Lead Quality Report - Week of ${report.period.from}\n\n`;

  text += `*Overview:*\n`;
  text += `• Leads: ${report.overview.totalLeads}`;
  if (!report.overview.sampleSizeAdequate) {
    text += ` ⚠️ (below minimum sample size)`;
  }
  text += `\n`;
  text += `• Conversion: ${report.overview.conversionRate}\n`;
  text += `• Lead Score: ${report.overview.averageLeadScore}\n`;
  text += `• Form Completion: ${report.qualityMetrics.formCompletionRate}\n\n`;

  if (report.bottlenecks.length > 0) {
    text += `*Bottlenecks:*\n`;
    report.bottlenecks.slice(0, 2).forEach(bottleneck => {
      const severityIcon = bottleneck.severity === 'critical' ? '🚨' : '⚠️';
      text += `${severityIcon} ${bottleneck.stage}: ${(bottleneck.dropoffRate * 100).toFixed(0)}% drop-off\n`;
    });
    text += `\n`;
  }

  if (report.recommendations.length > 0) {
    text += `*Top Recommendations:*\n`;
    report.recommendations.slice(0, 3).forEach(rec => {
      const recIcon = rec.priority === 'critical' ? '🚨' : rec.priority === 'warning' ? '⚠️' : 'ℹ️';
      text += `${recIcon} ${rec.action}\n  _${rec.expectedImpact}_\n`;
    });
  }

  text += `\nFull report: optimizer-weekly-${report.date}.json`;

  return { text };
}

/**
 * Save report to file
 */
async function saveReport(report) {
  const timestamp = new Date().toISOString().split('T')[0];
  const filename = `optimizer-weekly-${timestamp}.json`;
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
    // Step 1: Execute skills to gather data
    console.log('🔄 Step 1: Data Collection\n');

    await executeSkill('marketing-health-check');
    await executeSkill('lead-funnel-analysis');
    await executeSkill('google-ads-performance');
    await executeSkill('meta-ads-performance');

    // Step 2: Load collected data
    console.log('📖 Step 2: Loading Data\n');

    const leadData = await loadData('real-lead-data.json');
    const googleAdsData = await loadData('google-ads-spend-data.json');
    const metaAdsData = await loadData('meta-ads-spend-data.json');

    if (!leadData || !leadData.leads || leadData.leads.length === 0) {
      throw new Error('No lead data available for analysis');
    }

    // Step 3: Calculate metrics
    console.log('📊 Step 3: Calculating Lead Metrics\n');

    const metrics = calculateLeadMetrics(leadData, googleAdsData);

    if (!metrics) {
      throw new Error('Failed to calculate metrics');
    }

    console.log('Lead Quality Metrics:');
    console.log(`  Total Leads: ${metrics.totalLeads}`);
    console.log(`  Conversion Rate: ${(metrics.conversionRate * 100).toFixed(1)}%`);
    console.log(`  Avg Lead Score: ${metrics.averageLeadScore.toFixed(0)}`);
    console.log(`  Bottlenecks: ${metrics.bottlenecks.length}\n`);

    // Step 4: Generate report
    console.log('📝 Step 4: Generating Report\n');

    const report = generateWeeklyReport(metrics);

    // Step 5: Save report
    await saveReport(report);

    // Step 6: Send Slack notification
    console.log('\n📢 Step 5: Sending Notification\n');
    await sendSlackNotification(report);

    // Summary
    console.log('\n✅ Agent execution completed successfully');
    console.log(`   Report type: ${report.type}`);
    console.log(`   Status: ${report.overview.status}`);
    console.log(`   Leads analyzed: ${metrics.totalLeads}`);
    console.log(`   Recommendations: ${report.recommendations.length}`);

    process.exit(0);

  } catch (error) {
    console.error('\n❌ Agent execution failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the agent
main();

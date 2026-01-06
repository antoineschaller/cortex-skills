/**
 * Meteor Sync Status Diagnostic Script
 *
 * Checks overall sync health including:
 * - MongoDB connection status
 * - Recent sync runs and their status
 * - Entity mapping statistics
 * - Stale cache entries
 *
 * Usage (from apps/web directory):
 *   npx tsx ../../.claude/skills/meteor-sync-specialist/scripts/diagnose-sync-status.ts
 */

import * as fs from 'fs';
import * as path from 'path';
import { createClient } from '@supabase/supabase-js';

// Load environment variables from .env.local
function loadEnvFile(filePath: string) {
  if (fs.existsSync(filePath)) {
    const content = fs.readFileSync(filePath, 'utf-8');
    content.split('\n').forEach((line) => {
      const match = line.match(/^([^=]+)=(.*)$/);
      if (match) {
        const key = match[1].trim();
        const value = match[2].trim().replace(/^["']|["']$/g, '');
        process.env[key] = value;
      }
    });
  }
}

loadEnvFile(path.resolve(process.cwd(), '.env.local'));

async function main() {
  console.log('\n🔍 Meteor Sync Status Diagnostic\n');
  console.log('='.repeat(60));

  const SUPABASE_URL =
    process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const METEOR_MONGO_URL = process.env.METEOR_MONGO_URL;

  // 1. Check MongoDB connection
  console.log('\n📡 MongoDB Connection:');
  if (!METEOR_MONGO_URL) {
    console.log('   ⚠️  METEOR_MONGO_URL not set (sync unavailable)');
  } else {
    try {
      const { MongoClient } = await import('mongodb');
      const client = new MongoClient(METEOR_MONGO_URL, {
        serverSelectionTimeoutMS: 10000,
      });
      await client.connect();
      const db = client.db('meteor');
      const collections = await db.listCollections().toArray();
      console.log(`   ✅ Connected - ${collections.length} collections found`);
      await client.close();
    } catch (error) {
      console.log(
        `   ❌ Connection failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );
    }
  }

  // 2. Check Supabase connection
  console.log('\n📊 Supabase Connection:');
  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    console.log('   ❌ Supabase credentials not set');
    console.log(`   SUPABASE_URL: ${SUPABASE_URL ? 'Found' : 'Missing'}`);
    console.log(
      `   SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_KEY ? 'Found' : 'Missing'}`,
    );
    return;
  }

  console.log(`   🔗 ${SUPABASE_URL}`);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: {
      persistSession: false,
      detectSessionInUrl: false,
      autoRefreshToken: false,
    },
  });

  try {
    const { error } = await supabase
      .from('meteor_sync_runs')
      .select('id')
      .limit(1);
    if (error && error.code !== 'PGRST116') throw error;
    console.log('   ✅ Connected');
  } catch (error) {
    console.log(
      `   ❌ Connection failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
    );
    return;
  }

  // 3. Recent sync runs
  console.log('\n📋 Recent Sync Runs (last 5):');
  const { data: runs, error: runsError } = await supabase
    .from('meteor_sync_runs')
    .select('*')
    .order('started_at', { ascending: false })
    .limit(5);

  if (runsError) {
    console.log(`   ❌ Error fetching runs: ${runsError.message}`);
  } else if (!runs || runs.length === 0) {
    console.log('   ℹ️  No sync runs found');
  } else {
    console.log(
      '\n   ID                                   Type         Status      Duration',
    );
    console.log('   ' + '-'.repeat(76));
    for (const run of runs) {
      const status =
        run.status === 'completed'
          ? '✅ completed'
          : run.status === 'running'
            ? '🔄 running'
            : run.status === 'failed'
              ? '❌ failed'
              : `⚠️  ${run.status}`;
      const duration = run.duration_seconds
        ? `${run.duration_seconds}s`
        : run.status === 'running'
          ? 'in progress'
          : '-';
      console.log(
        `   ${run.id}  ${(run.sync_type || 'unknown').padEnd(12)} ${status.padEnd(12)} ${duration}`,
      );
    }
  }

  // 4. Entity mapping statistics
  console.log('\n📈 Entity Mapping Statistics:');
  const { data: mappings } = await supabase
    .from('meteor_entity_mapping')
    .select('entity_type, sync_status');

  if (mappings && mappings.length > 0) {
    const counts: Record<string, Record<string, number>> = {};
    for (const m of mappings) {
      if (!counts[m.entity_type]) {
        counts[m.entity_type] = { synced: 0, error: 0, pending: 0, skipped: 0 };
      }
      counts[m.entity_type][m.sync_status] =
        (counts[m.entity_type][m.sync_status] || 0) + 1;
    }

    console.log(
      '\n   Entity Type          Synced     Errors     Pending    Total',
    );
    console.log('   ' + '-'.repeat(64));
    for (const [entityType, statusCounts] of Object.entries(counts)) {
      const total =
        (statusCounts.synced || 0) +
        (statusCounts.error || 0) +
        (statusCounts.pending || 0) +
        (statusCounts.skipped || 0);
      console.log(
        `   ${entityType.padEnd(22)} ${String(statusCounts.synced || 0).padStart(6)}     ${String(statusCounts.error || 0).padStart(6)}     ${String(statusCounts.pending || 0).padStart(6)}    ${String(total).padStart(6)}`,
      );
    }
  } else {
    console.log('   ℹ️  No entity mappings found');
  }

  // 5. Check for stuck running syncs
  console.log('\n⚠️  Stuck Sync Runs (running > 30 min):');
  const { data: stuckRuns } = await supabase
    .from('meteor_sync_runs')
    .select('*')
    .eq('status', 'running')
    .lt('started_at', new Date(Date.now() - 30 * 60 * 1000).toISOString());

  if (!stuckRuns || stuckRuns.length === 0) {
    console.log('   ✅ None found');
  } else {
    for (const run of stuckRuns) {
      const duration = Math.floor(
        (Date.now() - new Date(run.started_at).getTime()) / 60000,
      );
      console.log(
        `   ❌ Run ${run.id} (${run.sync_type}) - running for ${duration} minutes`,
      );
    }
  }

  // 6. Check for entities with errors
  console.log('\n❌ Entities with Sync Errors (last 10):');
  const { data: errorMappings } = await supabase
    .from('meteor_entity_mapping')
    .select('meteor_id, entity_type, error_message, last_synced_at')
    .eq('sync_status', 'error')
    .order('last_synced_at', { ascending: false })
    .limit(10);

  if (!errorMappings || errorMappings.length === 0) {
    console.log('   ✅ None found');
  } else {
    for (const m of errorMappings) {
      console.log(`   • ${m.entity_type}: ${m.meteor_id}`);
      console.log(
        `     Error: ${m.error_message?.substring(0, 80) || 'Unknown'}...`,
      );
    }
  }

  // 7. Sync state (for incremental sync)
  console.log('\n📍 Sync State (for incremental sync):');
  const { data: syncState } = await supabase
    .from('meteor_sync_state')
    .select('*');

  if (!syncState || syncState.length === 0) {
    console.log('   ℹ️  No sync state found (no incremental syncs run yet)');
  } else {
    console.log('\n   Entity Type          Last Sync                Last ID');
    console.log('   ' + '-'.repeat(64));
    for (const state of syncState) {
      const lastSync = state.last_sync_at
        ? new Date(state.last_sync_at).toISOString().substring(0, 19)
        : 'Never';
      console.log(
        `   ${(state.entity_type || 'unknown').padEnd(22)} ${lastSync.padEnd(24)} ${state.last_meteor_id || '-'}`,
      );
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('Diagnostic complete.\n');
}

main().catch(console.error);

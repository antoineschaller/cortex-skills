#!/usr/bin/env tsx
/**
 * Cleanup Stale Airtable Sync Cache
 *
 * Purpose: Remove stale entries from airtable_entity_mapping where the
 * entity_id references a deleted entity in productions/venues/events tables.
 *
 * This script safely identifies and removes stale cache entries that cause
 * sync failures like "Production with ID X does not exist".
 *
 * Usage:
 *   # Dry run (shows what would be deleted)
 *   npx tsx scripts/cleanup-stale-cache.ts --dry-run
 *
 *   # Execute cleanup (production)
 *   npx tsx scripts/cleanup-stale-cache.ts
 *
 *   # Cleanup specific entity type only
 *   npx tsx scripts/cleanup-stale-cache.ts --type production
 *
 * Created: 2025-10-20
 * Related: WIP_airtable_sync_stale_cache_diagnosis_2025_10_20.md
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

type EntityType = 'production' | 'venue' | 'event';

interface StaleEntry {
  airtable_unique_id: string;
  entity_type: string;
  entity_id: string;
  airtable_data: Record<string, unknown>;
  sync_count: number;
  last_synced_at: string;
}

interface CleanupResult {
  entityType: EntityType;
  total: number;
  stale: number;
  deleted: number;
  staleEntries: StaleEntry[];
}

async function cleanupStaleCache(
  dryRun: boolean = true,
  entityTypes: EntityType[] = ['production', 'venue', 'event'],
): Promise<CleanupResult[]> {
  // Direct client creation for script usage
  const supabaseUrl =
    process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error('Missing required environment variables:');
    console.error(`SUPABASE_URL: ${supabaseUrl ? 'Found' : 'Missing'}`);
    console.error(
      `SUPABASE_SERVICE_ROLE_KEY: ${supabaseServiceKey ? 'Found' : 'Missing'}`,
    );
    throw new Error('Missing Supabase environment variables');
  }

  console.log(`🔗 Connecting to: ${supabaseUrl}`);

  const adminClient = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      persistSession: false,
      detectSessionInUrl: false,
      autoRefreshToken: false,
    },
  });

  console.log(
    `🧹 Cleaning up stale Airtable sync cache (${dryRun ? 'DRY RUN' : 'LIVE'})...\n`,
  );

  const results: CleanupResult[] = [];

  for (const entityType of entityTypes) {
    const tableName =
      entityType === 'production'
        ? 'productions'
        : entityType === 'venue'
          ? 'venues'
          : 'events';

    console.log(`\n📋 Processing ${entityType}s...\n`);

    // 1. Get all cached entities of this type
    const { data: cachedEntities, error: cacheError } = await adminClient
      .from('airtable_entity_mapping')
      .select('*')
      .eq('entity_type', entityType);

    if (cacheError) {
      console.error(`❌ Error fetching cached ${entityType}s:`, cacheError);
      continue;
    }

    console.log(
      `   Found ${cachedEntities?.length || 0} cached ${entityType}s`,
    );

    // 2. Check which ones are stale
    const staleEntries: StaleEntry[] = [];

    for (const cached of cachedEntities || []) {
      const { data: entity } = await adminClient
        .from(tableName as 'productions' | 'venues' | 'events')
        .select('id')
        .eq('id', cached.entity_id)
        .maybeSingle();

      if (!entity) {
        staleEntries.push(cached as StaleEntry);
        console.log(
          `   ❌ STALE: ${cached.airtable_unique_id} → ${cached.entity_id}`,
        );
      }
    }

    console.log(
      `\n   Found ${staleEntries.length} stale ${entityType} entries`,
    );

    // 3. Delete stale entries (if not dry run)
    let deletedCount = 0;

    if (staleEntries.length > 0 && !dryRun) {
      console.log(`\n   🗑️  Deleting stale entries...`);

      for (const staleEntry of staleEntries) {
        const { error: deleteError } = await adminClient
          .from('airtable_entity_mapping')
          .delete()
          .eq('airtable_unique_id', staleEntry.airtable_unique_id);

        if (deleteError) {
          console.error(
            `   ❌ Failed to delete ${staleEntry.airtable_unique_id}:`,
            deleteError,
          );
        } else {
          deletedCount++;
          console.log(`   ✅ Deleted: ${staleEntry.airtable_unique_id}`);
        }
      }
    } else if (staleEntries.length > 0) {
      console.log(
        `\n   ℹ️  DRY RUN: Would delete ${staleEntries.length} entries`,
      );
      staleEntries.forEach((entry) => {
        console.log(`      - ${entry.airtable_unique_id} → ${entry.entity_id}`);
      });
    }

    results.push({
      entityType,
      total: cachedEntities?.length || 0,
      stale: staleEntries.length,
      deleted: deletedCount,
      staleEntries,
    });
  }

  return results;
}

// Parse command line arguments
const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const typeArg = args.find((arg) => arg.startsWith('--type='));
const specificType = typeArg?.split('=')[1] as EntityType | undefined;

const entityTypes: EntityType[] = specificType
  ? [specificType]
  : ['production', 'venue', 'event'];

cleanupStaleCache(dryRun, entityTypes)
  .then((results) => {
    console.log('\n\n✅ Cleanup complete\n');
    console.log('📊 SUMMARY:');
    console.log('─'.repeat(60));

    let totalStale = 0;
    let totalDeleted = 0;

    results.forEach((result) => {
      console.log(`\n   ${result.entityType.toUpperCase()}S:`);
      console.log(`      Total cached: ${result.total}`);
      console.log(`      Stale entries: ${result.stale}`);
      console.log(
        `      ${dryRun ? 'Would delete' : 'Deleted'}: ${dryRun ? result.stale : result.deleted}`,
      );

      totalStale += result.stale;
      totalDeleted += result.deleted;
    });

    console.log('\n' + '─'.repeat(60));
    console.log(`   TOTAL STALE: ${totalStale}`);
    console.log(
      `   TOTAL ${dryRun ? 'TO DELETE' : 'DELETED'}: ${dryRun ? totalStale : totalDeleted}`,
    );

    if (dryRun && totalStale > 0) {
      console.log(
        '\n💡 To actually delete these entries, run without --dry-run flag',
      );
    }

    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Cleanup failed:', error);
    process.exit(1);
  });

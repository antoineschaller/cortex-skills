#!/usr/bin/env tsx
/**
 * MongoDB vs Supabase Count Comparison Script
 *
 * Compares document counts between MongoDB and Supabase
 * to identify sync gaps.
 *
 * Usage:
 *   pnpm tsx .claude/skills/meteor-sync-specialist/scripts/compare-counts.ts
 */
import { resolve } from 'path';
import { createClient } from '@supabase/supabase-js';
import { config } from 'dotenv';
import { MongoClient } from 'mongodb';

// Load environment variables
config({ path: resolve(process.cwd(), 'apps/web/.env.local') });

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const METEOR_MONGO_URL = process.env.METEOR_MONGO_URL;

// Collection to table mapping
const COLLECTION_TABLE_MAP: Record<
  string,
  { collection: string; table: string; filter?: Record<string, unknown> }
> = {
  organization: { collection: 'Organizations', table: 'organizations' },
  candidate: { collection: 'Candidates', table: 'professional_profiles' },
  media: { collection: 'Media', table: 'dancer_media' },
  experience: { collection: 'Experiences', table: 'experiences' },
  post: { collection: 'Posts', table: 'posts' },
  like: { collection: 'Likes', table: 'likes' },
  follow: { collection: 'Follow', table: 'follows' },
};

interface CountResult {
  entityType: string;
  mongoCount: number;
  supabaseCount: number;
  mappedCount: number;
  diff: number;
  syncedPercent: number;
}

async function main() {
  console.log('\n📊 MongoDB vs Supabase Count Comparison\n');
  console.log('='.repeat(80));

  // Check prerequisites
  if (!METEOR_MONGO_URL) {
    console.log('❌ METEOR_MONGO_URL not set');
    return;
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    console.log('❌ Supabase credentials not set');
    return;
  }

  // Connect to MongoDB
  let mongoClient: MongoClient;
  try {
    mongoClient = new MongoClient(METEOR_MONGO_URL, {
      serverSelectionTimeoutMS: 10000,
    });
    await mongoClient.connect();
    console.log('✅ MongoDB connected\n');
  } catch (error) {
    console.log(
      `❌ MongoDB connection failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
    );
    return;
  }

  const mongodb = mongoClient.db('meteor');
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  const results: CountResult[] = [];

  // Get counts for each entity type
  console.log(
    'Entity Type         MongoDB    Supabase   Mapped     Diff       Synced%',
  );
  console.log('-'.repeat(80));

  for (const [entityType, mapping] of Object.entries(COLLECTION_TABLE_MAP)) {
    try {
      // MongoDB count
      const mongoCount = await mongodb
        .collection(mapping.collection)
        .countDocuments(mapping.filter || {});

      // Supabase table count
      const { count: supabaseCount, error: countError } = await supabase
        .from(mapping.table)
        .select('*', { count: 'exact', head: true });

      if (countError) {
        console.log(
          `${entityType.padEnd(20)} ${String(mongoCount).padStart(6)}     Error: ${countError.message}`,
        );
        continue;
      }

      // Meteor entity mapping count
      const { count: mappedCount } = await supabase
        .from('meteor_entity_mapping')
        .select('*', { count: 'exact', head: true })
        .eq('entity_type', entityType);

      const diff = (supabaseCount || 0) - mongoCount;
      const syncedPercent =
        mongoCount > 0 ? ((mappedCount || 0) / mongoCount) * 100 : 100;

      results.push({
        entityType,
        mongoCount,
        supabaseCount: supabaseCount || 0,
        mappedCount: mappedCount || 0,
        diff,
        syncedPercent,
      });

      const diffStr =
        diff === 0 ? '  ✓  ' : diff > 0 ? `+${diff}` : String(diff);
      const percentStr = `${syncedPercent.toFixed(1)}%`;
      const statusIcon =
        syncedPercent >= 99 ? '✅' : syncedPercent >= 90 ? '⚠️' : '❌';

      console.log(
        `${entityType.padEnd(20)} ${String(mongoCount).padStart(6)}     ${String(supabaseCount || 0).padStart(6)}     ${String(mappedCount || 0).padStart(6)}     ${diffStr.padStart(6)}     ${percentStr.padStart(6)} ${statusIcon}`,
      );
    } catch (error) {
      console.log(
        `${entityType.padEnd(20)} Error: ${error instanceof Error ? error.message : 'Unknown'}`,
      );
    }
  }

  console.log('-'.repeat(80));

  // Summary
  const totalMongo = results.reduce((sum, r) => sum + r.mongoCount, 0);
  const totalSupabase = results.reduce((sum, r) => sum + r.supabaseCount, 0);
  const totalMapped = results.reduce((sum, r) => sum + r.mappedCount, 0);
  const totalDiff = totalSupabase - totalMongo;
  const overallPercent =
    totalMongo > 0 ? (totalMapped / totalMongo) * 100 : 100;

  console.log(
    `${'TOTAL'.padEnd(20)} ${String(totalMongo).padStart(6)}     ${String(totalSupabase).padStart(6)}     ${String(totalMapped).padStart(6)}     ${String(totalDiff).padStart(6)}     ${overallPercent.toFixed(1).padStart(6)}%`,
  );

  // Analysis
  console.log('\n📋 Analysis:\n');

  const underSynced = results.filter((r) => r.syncedPercent < 99);
  if (underSynced.length > 0) {
    console.log('   Entities needing attention:');
    for (const r of underSynced) {
      const missing = r.mongoCount - r.mappedCount;
      console.log(
        `   • ${r.entityType}: ${missing} documents not synced (${r.syncedPercent.toFixed(1)}%)`,
      );
    }
  } else {
    console.log('   ✅ All entity types are at least 99% synced');
  }

  // Check for orphaned Supabase records (more in Supabase than MongoDB)
  const orphaned = results.filter((r) => r.diff > 0);
  if (orphaned.length > 0) {
    console.log('\n   Records in Supabase without MongoDB source:');
    for (const r of orphaned) {
      console.log(`   • ${r.entityType}: ${r.diff} extra records`);
    }
  }

  // Entities with errors
  const { count: errorCount } = await supabase
    .from('meteor_entity_mapping')
    .select('*', { count: 'exact', head: true })
    .eq('sync_status', 'error');

  if (errorCount && errorCount > 0) {
    console.log(`\n   ⚠️  ${errorCount} entities have sync errors`);
    console.log(
      '   Run: pnpm tsx .claude/skills/meteor-sync-specialist/scripts/diagnose-sync-status.ts',
    );
  }

  await mongoClient.close();
  console.log('\n' + '='.repeat(80));
  console.log('Comparison complete.\n');
}

main().catch(console.error);

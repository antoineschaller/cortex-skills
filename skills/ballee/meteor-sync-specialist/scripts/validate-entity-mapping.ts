#!/usr/bin/env tsx
/**
 * Entity Mapping Validation Script
 *
 * Validates cache integrity by checking:
 * - Cache entries pointing to deleted entities (stale cache)
 * - Orphaned cache entries
 * - Duplicate mappings
 *
 * Usage:
 *   pnpm tsx .claude/skills/meteor-sync-specialist/scripts/validate-entity-mapping.ts
 *   pnpm tsx .claude/skills/meteor-sync-specialist/scripts/validate-entity-mapping.ts --fix
 */
import { resolve } from 'path';
import { createClient } from '@supabase/supabase-js';
import { config } from 'dotenv';

// Load environment variables
config({ path: resolve(process.cwd(), 'apps/web/.env.local') });

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;

const FIX_MODE = process.argv.includes('--fix');

// Entity type to table name mapping
const ENTITY_TABLE_MAP: Record<string, string> = {
  organization: 'organizations',
  organization_media: 'organization_media',
  candidate: 'professional_profiles',
  media: 'dancer_media',
  experience: 'experiences',
  post: 'posts',
  like: 'likes',
  follow: 'follows',
  audition: 'auditions',
  audition_application: 'audition_applications',
};

interface ValidationResult {
  entityType: string;
  staleCount: number;
  duplicateCount: number;
  staleEntries: Array<{ meteorId: string; entityId: string }>;
  duplicateEntries: Array<{ meteorId: string; count: number }>;
}

async function main() {
  console.log('\n🔍 Entity Mapping Validation\n');
  console.log('='.repeat(60));

  if (FIX_MODE) {
    console.log('⚠️  FIX MODE ENABLED - Will delete stale entries\n');
  } else {
    console.log('ℹ️  Dry run - use --fix to delete stale entries\n');
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    console.log('❌ Supabase credentials not set');
    return;
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  const results: ValidationResult[] = [];
  let totalStale = 0;
  let totalDuplicates = 0;

  // 1. Check for stale cache entries per entity type
  console.log('📋 Checking for stale cache entries...\n');

  for (const [entityType, tableName] of Object.entries(ENTITY_TABLE_MAP)) {
    // Get all mappings for this entity type
    const { data: mappings, error: mappingError } = await supabase
      .from('meteor_entity_mapping')
      .select('meteor_id, entity_id')
      .eq('entity_type', entityType);

    if (mappingError) {
      console.log(`   ⚠️  ${entityType}: Error fetching mappings`);
      continue;
    }

    if (!mappings || mappings.length === 0) {
      continue;
    }

    // Check which entities still exist
    const entityIds = mappings.map((m) => m.entity_id);

    // Query the target table to find which IDs exist
    const { data: existingEntities, error: entityError } = await supabase
      .from(tableName)
      .select('id')
      .in('id', entityIds);

    if (entityError) {
      console.log(
        `   ⚠️  ${entityType}: Error checking target table (${tableName})`,
      );
      continue;
    }

    const existingIds = new Set(existingEntities?.map((e) => e.id) || []);

    // Find stale entries (cached but entity doesn't exist)
    const staleEntries = mappings.filter((m) => !existingIds.has(m.entity_id));

    if (staleEntries.length > 0) {
      console.log(
        `   ❌ ${entityType}: ${staleEntries.length} stale entries found`,
      );
      totalStale += staleEntries.length;

      if (FIX_MODE) {
        // Delete stale entries
        const staleIds = staleEntries.map((e) => e.meteor_id);
        const { error: deleteError } = await supabase
          .from('meteor_entity_mapping')
          .delete()
          .in('meteor_id', staleIds)
          .eq('entity_type', entityType);

        if (deleteError) {
          console.log(`      ⚠️  Failed to delete: ${deleteError.message}`);
        } else {
          console.log(`      ✅ Deleted ${staleEntries.length} stale entries`);
        }
      }

      results.push({
        entityType,
        staleCount: staleEntries.length,
        duplicateCount: 0,
        staleEntries: staleEntries.map((e) => ({
          meteorId: e.meteor_id,
          entityId: e.entity_id,
        })),
        duplicateEntries: [],
      });
    } else {
      console.log(`   ✅ ${entityType}: ${mappings.length} entries valid`);
    }
  }

  // 2. Check for duplicate mappings
  console.log('\n📋 Checking for duplicate mappings...\n');

  const { data: duplicates } = await supabase.rpc(
    'find_duplicate_meteor_mappings',
  );

  if (duplicates && duplicates.length > 0) {
    console.log(
      `   ❌ Found ${duplicates.length} duplicate meteor_id entries:`,
    );
    for (const dup of duplicates.slice(0, 10)) {
      console.log(
        `      • ${dup.entity_type}/${dup.meteor_id}: ${dup.count} entries`,
      );
      totalDuplicates += dup.count - 1; // Count extras only
    }
    if (duplicates.length > 10) {
      console.log(`      ... and ${duplicates.length - 10} more`);
    }
  } else {
    // Fallback query if RPC doesn't exist
    const { data: allMappings } = await supabase
      .from('meteor_entity_mapping')
      .select('meteor_id, entity_type');

    if (allMappings) {
      const counts: Record<string, number> = {};
      for (const m of allMappings) {
        const key = `${m.entity_type}:${m.meteor_id}`;
        counts[key] = (counts[key] || 0) + 1;
      }

      const dups = Object.entries(counts).filter(([, count]) => count > 1);
      if (dups.length > 0) {
        console.log(`   ❌ Found ${dups.length} duplicate meteor_id entries:`);
        for (const [key, count] of dups.slice(0, 10)) {
          const [entityType, meteorId] = key.split(':');
          console.log(`      • ${entityType}/${meteorId}: ${count} entries`);
          totalDuplicates += count - 1;
        }
      } else {
        console.log('   ✅ No duplicate mappings found');
      }
    }
  }

  // 3. Summary
  console.log('\n' + '='.repeat(60));
  console.log('\n📊 Summary:\n');
  console.log(`   Stale cache entries:    ${totalStale}`);
  console.log(`   Duplicate mappings:     ${totalDuplicates}`);

  if (totalStale > 0 || totalDuplicates > 0) {
    if (!FIX_MODE) {
      console.log('\n💡 Run with --fix to clean up stale entries');
    }
  } else {
    console.log('\n   ✅ All entity mappings are valid!');
  }

  // 4. Detailed report if issues found
  if (results.length > 0 && !FIX_MODE) {
    console.log('\n📋 Detailed Stale Entries (first 5 per type):\n');
    for (const result of results) {
      if (result.staleEntries.length > 0) {
        console.log(`   ${result.entityType}:`);
        for (const entry of result.staleEntries.slice(0, 5)) {
          console.log(`      meteor_id: ${entry.meteorId}`);
          console.log(`      entity_id: ${entry.entityId} (deleted)`);
        }
        if (result.staleEntries.length > 5) {
          console.log(`      ... and ${result.staleEntries.length - 5} more\n`);
        }
      }
    }
  }

  console.log('\nValidation complete.\n');
}

main().catch(console.error);

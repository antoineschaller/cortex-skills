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

async function diagnoseSyncCache() {
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

  console.log('🔍 Diagnosing Airtable sync cache...\n');

  // 1. Get all cached productions
  const { data: cachedProductions, error: prodError } = await adminClient
    .from('airtable_entity_mapping')
    .select('*')
    .eq('entity_type', 'production');

  if (prodError) {
    console.error('❌ Error fetching cached productions:', prodError);
    throw prodError;
  }

  console.log(
    `📊 Found ${cachedProductions?.length || 0} cached productions\n`,
  );

  // 2. Check which ones actually exist
  const staleProductions = [];
  const validProductions = [];

  for (const cached of cachedProductions || []) {
    const { data: production } = await adminClient
      .from('productions')
      .select('id, name')
      .eq('id', cached.entity_id)
      .maybeSingle();

    if (!production) {
      staleProductions.push(cached);
      console.log(
        `❌ STALE: ${cached.airtable_unique_id} → ${cached.entity_id}`,
      );
      console.log(`   Data: ${JSON.stringify(cached.airtable_data)}`);
    } else {
      validProductions.push(cached);
    }
  }

  console.log(`\n✅ Valid productions: ${validProductions.length}`);
  console.log(`🚨 Stale productions: ${staleProductions.length}`);

  // 3. Check for specific UUID
  const targetUuid = '6bae6af6-4f86-44b0-9230-caa633ca345e';
  const staleTarget = staleProductions.find((p) => p.entity_id === targetUuid);

  if (staleTarget) {
    console.log(`\n🎯 FOUND TARGET UUID IN STALE CACHE:`);
    console.log(`   UniqueID: ${staleTarget.airtable_unique_id}`);
    console.log(`   Entity ID: ${staleTarget.entity_id}`);
    console.log(
      `   Data: ${JSON.stringify(staleTarget.airtable_data, null, 2)}`,
    );
  } else {
    console.log(`\n⚠️  Target UUID ${targetUuid} not found in stale cache`);
    // Check if it exists in valid productions
    const validTarget = validProductions.find(
      (p) => p.entity_id === targetUuid,
    );
    if (validTarget) {
      console.log(`   ✅ Found in valid cache (production exists)`);
    } else {
      console.log(`   ❓ Not found in cache at all`);
    }
  }

  // 4. Check venues
  console.log('\n\n🏢 Checking venues...\n');
  const { data: cachedVenues, error: venueError } = await adminClient
    .from('airtable_entity_mapping')
    .select('*')
    .eq('entity_type', 'venue');

  if (venueError) {
    console.error('❌ Error fetching cached venues:', venueError);
  } else {
    console.log(`📊 Found ${cachedVenues?.length || 0} cached venues`);

    const staleVenues = [];
    for (const cached of cachedVenues || []) {
      const { data: venue } = await adminClient
        .from('venues')
        .select('id, name')
        .eq('id', cached.entity_id)
        .maybeSingle();

      if (!venue) {
        staleVenues.push(cached);
        console.log(
          `❌ STALE: ${cached.airtable_unique_id} → ${cached.entity_id}`,
        );
      }
    }
    console.log(`🚨 Stale venues: ${staleVenues.length}`);
  }

  // 5. Check events
  console.log('\n\n📅 Checking events...\n');
  const { data: cachedEvents, error: eventError } = await adminClient
    .from('airtable_entity_mapping')
    .select('*')
    .eq('entity_type', 'event');

  if (eventError) {
    console.error('❌ Error fetching cached events:', eventError);
  } else {
    console.log(`📊 Found ${cachedEvents?.length || 0} cached events`);

    const staleEvents = [];
    for (const cached of cachedEvents || []) {
      const { data: event } = await adminClient
        .from('events')
        .select('id, name')
        .eq('id', cached.entity_id)
        .maybeSingle();

      if (!event) {
        staleEvents.push(cached);
        console.log(
          `❌ STALE: ${cached.airtable_unique_id} → ${cached.entity_id}`,
        );
      }
    }
    console.log(`🚨 Stale events: ${staleEvents.length}`);
  }

  return {
    productions: {
      total: cachedProductions?.length || 0,
      valid: validProductions.length,
      stale: staleProductions.length,
      staleEntries: staleProductions,
    },
    targetUuid: {
      uuid: targetUuid,
      found: !!staleTarget,
      entry: staleTarget || null,
    },
  };
}

diagnoseSyncCache()
  .then((result) => {
    console.log('\n\n✅ Diagnosis complete');
    console.log('\n📋 SUMMARY:');
    console.log(`   Total cached productions: ${result.productions.total}`);
    console.log(`   Valid productions: ${result.productions.valid}`);
    console.log(`   Stale productions: ${result.productions.stale}`);
    console.log(
      `\n   Target UUID found in stale cache: ${result.targetUuid.found}`,
    );

    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Diagnosis failed:', error);
    process.exit(1);
  });

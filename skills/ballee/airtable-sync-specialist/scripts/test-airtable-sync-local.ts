#!/usr/bin/env tsx
/**
 * Test Airtable Sync Locally with Full Debug Logging
 */
import { createClient } from '@supabase/supabase-js';

import { getLogger } from '@kit/shared/logger';

import type { Database } from '../lib/database.types.js';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  const logger = await getLogger();
  logger.error(
    {
      service: 'airtable-sync-local-test',
      hasUrl: !!SUPABASE_URL,
      hasServiceKey: !!SUPABASE_SERVICE_ROLE_KEY,
    },
    'Missing required environment variables: NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY',
  );
  process.exit(1);
}

async function main() {
  const logger = await getLogger();
  logger.info(
    {
      service: 'airtable-sync-local-test',
      function: 'main',
      environment: process.env.NODE_ENV || 'development',
      supabaseUrl: SUPABASE_URL,
    },
    'Testing Airtable Sync Locally',
  );

  const adminClient = createClient<Database>(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: { persistSession: false },
    },
  );

  // 1. Check Fever client
  logger.info(
    { service: 'airtable-sync-local-test', function: 'main', step: 1 },
    'Step 1: Check Fever Client',
  );

  const { data: feverClient, error: clientError } = await adminClient
    .from('clients')
    .select('*')
    .eq('slug', 'fever')
    .maybeSingle();

  if (clientError || !feverClient) {
    logger.error(
      {
        service: 'airtable-sync-local-test',
        function: 'main',
        error: clientError?.message,
      },
      'Fever client NOT FOUND',
    );
    logger.info(
      { service: 'airtable-sync-local-test', function: 'main' },
      'Creating Fever client',
    );

    const { data: newClient, error: createError } = await adminClient
      .from('clients')
      .insert({
        id: '00000000-0000-0000-0000-000000000001',
        name: 'Fever',
        slug: 'fever',
        type: 'promoter',
        is_active: true,
      })
      .select()
      .single();

    if (createError) {
      logger.error(
        {
          service: 'airtable-sync-local-test',
          function: 'main',
          error: createError.message,
        },
        'Failed to create Fever client',
      );
      process.exit(1);
    }

    logger.info(
      {
        service: 'airtable-sync-local-test',
        function: 'main',
        clientId: newClient?.id,
      },
      'Created Fever client',
    );
    process.exit(0);
  }

  logger.info(
    {
      service: 'airtable-sync-local-test',
      function: 'main',
      clientId: feverClient.id,
      clientName: feverClient.name,
      clientSlug: feverClient.slug,
    },
    'Fever Client Found',
  );

  // 2. Check existing productions
  logger.info(
    { service: 'airtable-sync-local-test', function: 'main', step: 2 },
    'Step 2: Check Existing Productions',
  );

  const { data: productions, count: prodCount } = await adminClient
    .from('productions')
    .select('*', { count: 'exact' })
    .eq('client_id', feverClient.id);

  logger.info(
    {
      service: 'airtable-sync-local-test',
      function: 'main',
      prodCount: prodCount || 0,
      recentProductions:
        productions && productions.length > 0
          ? productions
              .slice(0, 5)
              .map((prod) => ({ name: prod.name, id: prod.id }))
          : [],
    },
    'Found productions for Fever',
  );

  // 3. Check existing venues
  logger.info(
    { service: 'airtable-sync-local-test', function: 'main', step: 3 },
    'Step 3: Check Existing Venues',
  );

  const { count: venueCount } = await adminClient
    .from('venues')
    .select('*', { count: 'exact', head: true });

  logger.info(
    {
      service: 'airtable-sync-local-test',
      function: 'main',
      venueCount: venueCount || 0,
    },
    'Found venues',
  );

  // 4. Check existing events
  logger.info(
    { service: 'airtable-sync-local-test', function: 'main', step: 4 },
    'Step 4: Check Existing Events',
  );

  if (productions && productions.length > 0) {
    const productionIds = productions.map((p) => p.id);

    const { count: eventCount } = await adminClient
      .from('events')
      .select('*', { count: 'exact', head: true })
      .in('production_id', productionIds);

    logger.info(
      {
        service: 'airtable-sync-local-test',
        function: 'main',
        eventCount: eventCount || 0,
      },
      'Found events for Fever productions',
    );
  } else {
    logger.warn(
      { service: 'airtable-sync-local-test', function: 'main' },
      'No events (no productions found)',
    );
  }

  // 5. Run sync
  logger.info(
    { service: 'airtable-sync-local-test', function: 'main', step: 5 },
    'Step 5: Run Airtable Sync',
  );

  const syncEndpoint = `${SUPABASE_URL.replace(/^.*\/\//, 'http://')}/api/admin/sync/airtable`;
  logger.info(
    {
      service: 'airtable-sync-local-test',
      function: 'main',
      syncEndpoint,
    },
    'Calling sync endpoint',
  );

  try {
    // Import the sync service
    const { AirtableSyncService } = await import(
      '../app/admin/sync/_lib/server/airtable-sync.service.js'
    );

    const syncService = new AirtableSyncService(adminClient);

    logger.info(
      { service: 'airtable-sync-local-test', function: 'main' },
      'Starting sync',
    );
    const result = await syncService.syncWithChangeTracking({
      clientId: feverClient.id,
      triggeredBy: undefined,
      triggerType: 'manual',
      dryRun: false,
    });

    logger.info(
      {
        service: 'airtable-sync-local-test',
        function: 'main',
        success: result.success,
        venuesCreated: result.venuesCreated,
        venuesUpdated: result.venuesUpdated,
        productionsCreated: result.productionsCreated,
        productionsUpdated: result.productionsUpdated,
        eventsCreated: result.eventsCreated,
        eventsUpdated: result.eventsUpdated,
        ratingsCreated: result.ratingsCreated,
        ratingsUpdated: result.ratingsUpdated,
        ratingsSkipped: result.ratingsSkipped,
        errorsCount: result.errors.length,
      },
      'Sync Result',
    );

    if (result.errors.length > 0) {
      logger.error(
        {
          service: 'airtable-sync-local-test',
          function: 'main',
          errors: result.errors,
        },
        'Sync completed with errors',
      );
    }
  } catch (error) {
    logger.error(
      {
        service: 'airtable-sync-local-test',
        function: 'main',
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      },
      'Sync failed',
    );
  }
}

main().catch(async (error) => {
  const logger = await getLogger();
  logger.error(
    {
      service: 'airtable-sync-local-test',
      function: 'main',
      error: error instanceof Error ? error.message : String(error),
    },
    'Fatal error',
  );
  process.exit(1);
});

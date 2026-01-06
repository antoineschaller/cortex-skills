#!/usr/bin/env tsx
/**
 * Production Airtable Sync Diagnostic Script
 *
 * This script performs a comprehensive diagnostic of the Airtable sync process in production
 * to identify issues and verify data integrity.
 *
 * Usage:
 *   pnpm tsx scripts/test-airtable-sync-prod.ts
 */
import { createClient } from '@supabase/supabase-js';

import { getLogger } from '@kit/shared/logger';

import type { Database } from '../lib/database.types.js';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
  const logger = await getLogger();
  logger.error(
    {
      service: 'airtable-sync-prod-test',
      hasUrl: !!SUPABASE_URL,
      hasAnonKey: !!SUPABASE_ANON_KEY,
      hasServiceKey: !!SUPABASE_SERVICE_ROLE_KEY,
    },
    'Missing required environment variables: NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY',
  );
  process.exit(1);
}

async function main() {
  const logger = await getLogger();
  logger.info(
    { service: 'airtable-sync-prod-test', function: 'main' },
    'Airtable Sync Production Diagnostic',
  );

  // Create admin client (bypasses RLS for diagnostic queries)
  const adminClient = createClient<Database>(
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: { persistSession: false },
    },
  );

  logger.info(
    { service: 'airtable-sync-prod-test', function: 'main', step: 1 },
    'Step 1: Check Fever Client',
  );

  const { data: feverClient, error: clientError } = await adminClient
    .from('clients')
    .select('*')
    .eq('slug', 'fever')
    .maybeSingle();

  if (clientError) {
    logger.error(
      {
        service: 'airtable-sync-prod-test',
        function: 'main',
        error: clientError.message,
      },
      'Error fetching Fever client',
    );
    return;
  }

  if (!feverClient) {
    logger.error(
      {
        service: 'airtable-sync-prod-test',
        function: 'main',
        fix: 'Run: cd apps/web && pnpm supabase db push',
        migration: '20251017000001_seed_fever_client.sql',
      },
      'Fever client not found',
    );
    return;
  }

  logger.info(
    {
      service: 'airtable-sync-prod-test',
      function: 'main',
      clientId: feverClient.id,
      clientName: feverClient.name,
      clientSlug: feverClient.slug,
    },
    'Fever client exists',
  );

  logger.info(
    { service: 'airtable-sync-prod-test', function: 'main', step: 2 },
    'Step 2: Check Recent Sync Runs',
  );

  const { data: syncRuns, error: syncError } = await adminClient
    .from('airtable_sync_runs')
    .select('*')
    .eq('client_id', feverClient.id)
    .order('started_at', { ascending: false })
    .limit(5);

  if (syncError) {
    logger.error(
      {
        service: 'airtable-sync-prod-test',
        function: 'main',
        error: syncError.message,
      },
      'Error fetching sync runs',
    );
  } else if (!syncRuns || syncRuns.length === 0) {
    logger.warn(
      { service: 'airtable-sync-prod-test', function: 'main' },
      'No sync runs found',
    );
  } else {
    logger.info(
      {
        service: 'airtable-sync-prod-test',
        function: 'main',
        syncRunsCount: syncRuns.length,
        syncRuns: syncRuns.map((run) => ({
          id: run.id,
          triggerType: run.trigger_type,
          startedAt: run.started_at,
          status: run.status,
          recordsFetched: run.records_fetched,
          recordsCreated: run.records_created,
          recordsUpdated: run.records_updated,
          changesDetected: run.changes_detected,
          errorsCount: run.errors_count,
          errorMessage: run.error_message || null,
        })),
      },
      'Found recent sync runs',
    );
  }

  logger.info(
    { service: 'airtable-sync-prod-test', function: 'main', step: 3 },
    'Step 3: Check Entity Counts',
  );

  // Check venues
  const { count: venueCount, error: venueError } = await adminClient
    .from('venues')
    .select('*', { count: 'exact', head: true });

  if (venueError) {
    logger.error(
      {
        service: 'airtable-sync-prod-test',
        function: 'main',
        error: venueError.message,
      },
      'Error counting venues',
    );
  } else {
    logger.info(
      {
        service: 'airtable-sync-prod-test',
        function: 'main',
        venueCount,
      },
      'Venues count',
    );
  }

  // Check productions for Fever client
  const { count: productionCount, error: productionError } = await adminClient
    .from('productions')
    .select('*', { count: 'exact', head: true })
    .eq('client_id', feverClient.id);

  if (productionError) {
    logger.error(
      {
        service: 'airtable-sync-prod-test',
        function: 'main',
        error: productionError.message,
      },
      'Error counting productions',
    );
  } else {
    logger.info(
      {
        service: 'airtable-sync-prod-test',
        function: 'main',
        productionCount,
        clientId: feverClient.id,
      },
      'Productions count for Fever client',
    );
  }

  // Check events for Fever productions
  const { data: feverProductions } = await adminClient
    .from('productions')
    .select('id')
    .eq('client_id', feverClient.id);

  if (feverProductions && feverProductions.length > 0) {
    const productionIds = feverProductions.map((p) => p.id);

    const { count: eventCount, error: eventError } = await adminClient
      .from('events')
      .select('*', { count: 'exact', head: true })
      .in('production_id', productionIds);

    if (eventError) {
      logger.error(
        {
          service: 'airtable-sync-prod-test',
          function: 'main',
          error: eventError.message,
        },
        'Error counting events',
      );
    } else {
      logger.info(
        {
          service: 'airtable-sync-prod-test',
          function: 'main',
          eventCount,
        },
        'Events count for Fever productions',
      );
    }

    // Check event status breakdown
    const { data: eventsByStatus } = await adminClient
      .from('events')
      .select('status')
      .in('production_id', productionIds);

    if (eventsByStatus) {
      const statusCounts = eventsByStatus.reduce(
        (acc, e) => {
          acc[e.status] = (acc[e.status] || 0) + 1;
          return acc;
        },
        {} as Record<string, number>,
      );

      logger.info(
        {
          service: 'airtable-sync-prod-test',
          function: 'main',
          statusBreakdown: statusCounts,
        },
        'Event status breakdown',
      );
    }
  } else {
    logger.warn(
      { service: 'airtable-sync-prod-test', function: 'main' },
      'No productions found for Fever client',
    );
  }

  logger.info(
    { service: 'airtable-sync-prod-test', function: 'main', step: 4 },
    'Step 4: Check Entity Mappings',
  );

  const { count: mappingCount, error: mappingError } = await adminClient
    .from('airtable_entity_mappings')
    .select('*', { count: 'exact', head: true })
    .eq('client_id', feverClient.id);

  if (mappingError) {
    logger.error(
      {
        service: 'airtable-sync-prod-test',
        function: 'main',
        error: mappingError.message,
      },
      'Error counting entity mappings',
    );
  } else {
    // Breakdown by entity type
    const { data: mappings } = await adminClient
      .from('airtable_entity_mappings')
      .select('entity_type')
      .eq('client_id', feverClient.id);

    if (mappings) {
      const typeCounts = mappings.reduce(
        (acc, m) => {
          acc[m.entity_type] = (acc[m.entity_type] || 0) + 1;
          return acc;
        },
        {} as Record<string, number>,
      );

      logger.info(
        {
          service: 'airtable-sync-prod-test',
          function: 'main',
          mappingCount,
          typeBreakdown: typeCounts,
        },
        'Entity mappings for Fever client',
      );
    } else {
      logger.info(
        {
          service: 'airtable-sync-prod-test',
          function: 'main',
          mappingCount,
        },
        'Entity mappings for Fever client',
      );
    }
  }

  logger.info(
    { service: 'airtable-sync-prod-test', function: 'main', step: 5 },
    'Step 5: Check Recent Sync Changes',
  );

  if (syncRuns && syncRuns.length > 0) {
    const latestSyncId = syncRuns[0].id;

    const { data: changes, error: changesError } = await adminClient
      .from('airtable_sync_changes')
      .select('*')
      .eq('sync_run_id', latestSyncId)
      .order('created_at', { ascending: false })
      .limit(10);

    if (changesError) {
      logger.error(
        {
          service: 'airtable-sync-prod-test',
          function: 'main',
          error: changesError.message,
        },
        'Error fetching sync changes',
      );
    } else if (!changes || changes.length === 0) {
      logger.warn(
        { service: 'airtable-sync-prod-test', function: 'main' },
        'No changes recorded for latest sync',
      );
    } else {
      logger.info(
        {
          service: 'airtable-sync-prod-test',
          function: 'main',
          changesCount: changes.length,
          changes: changes.map((change) => ({
            entityType: change.entity_type,
            changeType: change.change_type,
            airtableId: change.airtable_unique_id,
            entityId: change.entity_id,
            changedFields:
              change.changed_fields &&
              Object.keys(change.changed_fields).length > 0
                ? change.changed_fields
                : null,
          })),
        },
        'Latest sync changes (showing first 10)',
      );
    }
  }

  logger.info(
    { service: 'airtable-sync-prod-test', function: 'main', step: 6 },
    'Step 6: Sample Events Data',
  );

  if (feverProductions && feverProductions.length > 0) {
    const productionIds = feverProductions.map((p) => p.id);

    const { data: sampleEvents } = await adminClient
      .from('events')
      .select(
        'id, title, event_date, start_time, location, status, production_id, venue_id',
      )
      .in('production_id', productionIds)
      .order('event_date', { ascending: false })
      .limit(5);

    if (sampleEvents && sampleEvents.length > 0) {
      logger.info(
        {
          service: 'airtable-sync-prod-test',
          function: 'main',
          sampleEventsCount: sampleEvents.length,
          events: sampleEvents.map((event) => ({
            title: event.title,
            eventDate: event.event_date,
            startTime: event.start_time,
            location: event.location,
            status: event.status,
            productionId: event.production_id,
            venueId: event.venue_id,
          })),
        },
        'Sample events (showing 5 most recent)',
      );
    } else {
      logger.warn(
        { service: 'airtable-sync-prod-test', function: 'main' },
        'No events found',
      );
    }
  }

  logger.info(
    { service: 'airtable-sync-prod-test', function: 'main', step: 7 },
    'Step 7: Diagnostic Summary',
  );

  const issues: string[] = [];

  if (!feverClient) {
    issues.push('Fever client not found');
  }

  if (!syncRuns || syncRuns.length === 0) {
    issues.push('No sync runs found');
  } else if (syncRuns[0].errors_count > 0) {
    issues.push(`Latest sync had ${syncRuns[0].errors_count} errors`);
  }

  if (productionCount === 0) {
    issues.push('No productions found');
  }

  if (issues.length === 0) {
    logger.info(
      { service: 'airtable-sync-prod-test', function: 'main' },
      'All checks passed',
    );
  } else {
    logger.warn(
      {
        service: 'airtable-sync-prod-test',
        function: 'main',
        issues,
      },
      'Issues found',
    );
  }

  logger.info(
    { service: 'airtable-sync-prod-test', function: 'main' },
    'Diagnostic complete',
  );
}

main().catch(async (error) => {
  const logger = await getLogger();
  logger.error(
    {
      service: 'airtable-sync-prod-test',
      function: 'main',
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    },
    'Fatal error',
  );
  process.exit(1);
});

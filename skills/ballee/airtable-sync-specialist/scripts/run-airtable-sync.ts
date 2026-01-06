/**
 * Script to programmatically trigger Airtable sync and test the complete flow
 * Run with: npx tsx scripts/run-airtable-sync.ts
 */
import { createClient } from '@supabase/supabase-js';

import { getLogger } from '@kit/shared/logger';

import { AirtableSyncService } from '../app/admin/sync/_lib/server/airtable-sync.service';
import type { Database } from '../lib/database.types';

async function runSync() {
  const logger = await getLogger();
  logger.info(
    { service: 'airtable-sync-script', function: 'runSync' },
    'Starting Airtable Sync Test',
  );

  // Get credentials from environment
  const supabaseUrl =
    process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321';
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const systemAccountId = process.env.SYSTEM_ACCOUNT_ID;

  if (!supabaseServiceKey) {
    logger.error(
      { service: 'airtable-sync-script', function: 'runSync' },
      'Missing SUPABASE_SERVICE_ROLE_KEY',
    );
    process.exit(1);
  }

  if (!systemAccountId) {
    logger.error(
      { service: 'airtable-sync-script', function: 'runSync' },
      'Missing SYSTEM_ACCOUNT_ID',
    );
    logger.info(
      { service: 'airtable-sync-script', function: 'runSync' },
      'Attempting to find first account in database',
    );
  }

  // Create Supabase admin client
  const supabase = createClient<Database>(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  // Get or create system account
  let accountId = systemAccountId;

  if (!accountId) {
    const { data: accounts } = await supabase
      .from('accounts')
      .select('id')
      .limit(1);

    if (!accounts || accounts.length === 0) {
      logger.error(
        { service: 'airtable-sync-script', function: 'runSync' },
        'No accounts found in database. Please create an account first.',
      );
      process.exit(1);
    }

    accountId = accounts[0].id;
    logger.info(
      {
        service: 'airtable-sync-script',
        function: 'runSync',
        accountId,
      },
      'Using account',
    );
  }

  // Check database state before sync
  logger.info(
    { service: 'airtable-sync-script', function: 'runSync' },
    'Database state BEFORE sync',
  );

  const eventsBefore = await supabase
    .from('events')
    .select('id', { count: 'exact', head: true });
  const ratingsBefore = await supabase
    .from('ratings')
    .select('id', { count: 'exact', head: true });
  const mappingsBefore = await supabase
    .from('airtable_entity_mapping')
    .select('airtable_unique_id', { count: 'exact', head: true });

  logger.info(
    {
      service: 'airtable-sync-script',
      function: 'runSync',
      events: eventsBefore.count || 0,
      ratings: ratingsBefore.count || 0,
      mappings: mappingsBefore.count || 0,
    },
    'Database state BEFORE sync',
  );

  // Run the sync
  logger.info(
    { service: 'airtable-sync-script', function: 'runSync' },
    'Running Airtable sync',
  );

  const syncService = new AirtableSyncService(supabase);

  try {
    const result = await syncService.syncWithChangeTracking({
      accountId: accountId,
      triggerType: 'manual',
      notifyOnChanges: false,
    });

    logger.info(
      { service: 'airtable-sync-script', function: 'runSync' },
      'Sync completed',
    );
    logger.info(
      {
        service: 'airtable-sync-script',
        function: 'runSync',
        success: result.success,
        syncRunId: result.syncRunId,
        startedAt: result.startedAt,
        completedAt: result.completedAt || 'N/A',
        venuesCreated: result.venuesCreated,
        venuesUpdated: result.venuesUpdated,
        productionsCreated: result.productionsCreated,
        productionsUpdated: result.productionsUpdated,
        eventsCreated: result.eventsCreated,
        eventsUpdated: result.eventsUpdated,
        ratingsCreated: result.ratingsCreated,
        ratingsUpdated: result.ratingsUpdated,
        ratingsSkipped: result.ratingsSkipped,
        changesDetected: result.changesDetected,
        errorsCount: result.errors.length,
      },
      'Sync Results',
    );

    if (result.errors.length > 0) {
      logger.error(
        {
          service: 'airtable-sync-script',
          function: 'runSync',
          errors: result.errors,
        },
        'Sync completed with errors',
      );
    }

    // Check database state after sync
    const eventsAfter = await supabase
      .from('events')
      .select('id', { count: 'exact', head: true });
    const ratingsAfter = await supabase
      .from('ratings')
      .select('id', { count: 'exact', head: true });
    const mappingsAfter = await supabase
      .from('airtable_entity_mapping')
      .select('airtable_unique_id', { count: 'exact', head: true });

    logger.info(
      {
        service: 'airtable-sync-script',
        function: 'runSync',
        events: {
          after: eventsAfter.count || 0,
          change: (eventsAfter.count || 0) - (eventsBefore.count || 0),
        },
        ratings: {
          after: ratingsAfter.count || 0,
          change: (ratingsAfter.count || 0) - (ratingsBefore.count || 0),
        },
        mappings: {
          after: mappingsAfter.count || 0,
          change: (mappingsAfter.count || 0) - (mappingsBefore.count || 0),
        },
      },
      'Database state AFTER sync',
    );

    // Get sample ratings
    if ((ratingsAfter.count || 0) > 0) {
      const { data: sampleRatings } = await supabase
        .from('ratings')
        .select('id, overall_rating, reviewer_name, comments, event_id')
        .limit(3);

      if (sampleRatings && sampleRatings.length > 0) {
        logger.info(
          {
            service: 'airtable-sync-script',
            function: 'runSync',
            sampleRatings: sampleRatings.map((rating, idx) => ({
              index: idx + 1,
              overallRating: rating.overall_rating,
              reviewerName: rating.reviewer_name || 'Anonymous',
              eventId: rating.event_id,
              comment: rating.comments
                ? rating.comments.substring(0, 80) +
                  (rating.comments.length > 80 ? '...' : '')
                : null,
            })),
          },
          'Sample Ratings',
        );
      }
    }

    // Get a past event to test UI
    const { data: pastEvents } = await supabase
      .from('events')
      .select('id, title, start_date_time')
      .lt('start_date_time', new Date().toISOString())
      .order('start_date_time', { ascending: false })
      .limit(1);

    if (pastEvents && pastEvents.length > 0) {
      const event = pastEvents[0];
      logger.info(
        {
          service: 'airtable-sync-script',
          function: 'runSync',
          eventId: event.id,
          title: event.title,
          startDateTime: event.start_date_time,
          url: `http://localhost:3012/home/events/${event.id}`,
          adminUrl: `http://localhost:3012/admin/events/${event.id}`,
        },
        'Past Event for UI Testing',
      );
    }

    logger.info(
      { service: 'airtable-sync-script', function: 'runSync' },
      'Sync test completed successfully',
    );
  } catch (error) {
    logger.error(
      {
        service: 'airtable-sync-script',
        function: 'runSync',
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      },
      'Sync failed',
    );
    process.exit(1);
  }
}

runSync();

#!/usr/bin/env tsx
/**
 * Check Airtable Showtime Backfill Needs
 *
 * This script:
 * 1. Fetches current Airtable data
 * 2. Checks production events and showtimes
 * 3. Identifies events missing 2nd showtime
 * 4. Identifies events with incorrect times (19:00 default)
 * 5. Generates a backfill migration SQL
 */
import { createClient } from '@supabase/supabase-js';

import { fetchAirtableData } from '../app/admin/sync/_lib/server/airtable-api.service';
import type { Database } from '../lib/database.types';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_KEY);

interface ShowtimeIssue {
  eventId: string;
  eventTitle: string;
  eventDate: string;
  issue: 'missing_second_showtime' | 'wrong_time' | 'both';
  currentShowtimes: Array<{
    id: string;
    start_time: string;
    display_order: number;
  }>;
  airtableData?: {
    startTime1: string;
    startTime2?: string;
  };
}

async function analyzeShowtimes() {
  console.log('🔍 Fetching Airtable data...\n');

  // Fetch current Airtable data
  const airtableData = await fetchAirtableData();
  console.log(`📊 Found ${airtableData.shows.length} shows in Airtable\n`);

  // Create a map of Airtable shows by unique key
  const airtableMap = new Map<string, (typeof airtableData.shows)[0]>();
  for (const show of airtableData.shows) {
    // Use same key generation as UniqueIdGenerator.forEvent
    const key = `${show.program}|${show.city}|${show.date}`;
    airtableMap.set(key, show);
  }

  console.log('🔍 Fetching production events and showtimes...\n');

  // Fetch all production events with their showtimes
  const { data: events, error } = await supabase
    .from('events')
    .select(
      `
      id,
      title,
      event_date,
      production:productions(name),
      venue:venues(name, city),
      showtimes:event_showtimes(id, start_time, display_order)
    `,
    )
    .neq('status', 'cancelled')
    .order('event_date', { ascending: false });

  if (error) {
    console.error('❌ Error fetching events:', error);
    process.exit(1);
  }

  console.log(`📊 Found ${events.length} non-cancelled events in production\n`);

  const issues: ShowtimeIssue[] = [];

  // Analyze each event
  for (const event of events) {
    const productionName = event.production?.name;
    const city = event.venue?.city;
    const date = event.event_date;

    if (!productionName || !city || !date) {
      continue;
    }

    // Look up in Airtable
    const key = `${productionName}|${city}|${date}`;
    const airtableShow = airtableMap.get(key);

    if (!airtableShow) {
      // Event not in Airtable (might be manually created)
      continue;
    }

    const showtimes = (event.showtimes || []).sort(
      (a, b) => (a.display_order || 0) - (b.display_order || 0),
    );

    let hasIssue = false;
    let issueType: ShowtimeIssue['issue'] = 'missing_second_showtime';

    // Check 1: Missing second showtime
    if (airtableShow.startTime2 && showtimes.length < 2) {
      hasIssue = true;
      issueType = 'missing_second_showtime';
    }

    // Check 2: Wrong times (19:00 default)
    if (showtimes.length > 0) {
      const firstTime = showtimes[0]?.start_time;
      if (firstTime === '19:00:00' && airtableShow.startTime1 !== '19:00') {
        hasIssue = true;
        issueType =
          issueType === 'missing_second_showtime' ? 'both' : 'wrong_time';
      }
    }

    if (hasIssue) {
      issues.push({
        eventId: event.id,
        eventTitle: event.title,
        eventDate: date,
        issue: issueType,
        currentShowtimes: showtimes.map((st) => ({
          id: st.id,
          start_time: st.start_time || '',
          display_order: st.display_order || 0,
        })),
        airtableData: {
          startTime1: airtableShow.startTime1,
          startTime2: airtableShow.startTime2,
        },
      });
    }
  }

  return { issues, totalEvents: events.length };
}

async function main() {
  console.log('🚀 Airtable Showtime Analysis\n');
  console.log('='.repeat(60));
  console.log('\n');

  const { issues, totalEvents } = await analyzeShowtimes();

  console.log('\n' + '='.repeat(60));
  console.log('\n📊 ANALYSIS RESULTS\n');
  console.log('='.repeat(60));
  console.log(`\nTotal events analyzed: ${totalEvents}`);
  console.log(`Events with issues: ${issues.length}\n`);

  // Group by issue type
  const missingSecond = issues.filter((i) =>
    i.issue.includes('missing_second'),
  );
  const wrongTime = issues.filter((i) => i.issue.includes('wrong_time'));
  const both = issues.filter((i) => i.issue === 'both');

  console.log(`Missing 2nd showtime: ${missingSecond.length}`);
  console.log(`Wrong time (19:00 default): ${wrongTime.length}`);
  console.log(`Both issues: ${both.length}\n`);

  if (issues.length === 0) {
    console.log('✅ All events have correct showtimes!\n');
    return;
  }

  // Show first 10 issues
  console.log('\n📋 Sample Issues (first 10):\n');
  console.log('='.repeat(60));

  for (const issue of issues.slice(0, 10)) {
    console.log(`\n${issue.eventTitle} (${issue.eventDate})`);
    console.log(`  Issue: ${issue.issue}`);
    console.log(
      `  Current showtimes: ${issue.currentShowtimes.map((st) => st.start_time).join(', ') || 'none'}`,
    );
    console.log(
      `  Airtable times: ${issue.airtableData?.startTime1}${issue.airtableData?.startTime2 ? `, ${issue.airtableData.startTime2}` : ''}`,
    );
  }

  console.log('\n' + '='.repeat(60));
  console.log('\n💡 Run with --generate-migration to create backfill SQL\n');
}

main().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});

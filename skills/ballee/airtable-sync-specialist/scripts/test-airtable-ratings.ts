/**
 * Test script to verify Airtable ratings connection and schema
 * Run with: npx tsx scripts/test-airtable-ratings.ts
 */
import Airtable from 'airtable';

import {
  RATING_CONFIG,
  RATING_FIELDS,
} from '../app/admin/sync/_lib/server/constants';

async function testAirtableRatings() {
  const apiKey = process.env.AIRTABLE_API_KEY;
  const baseId = process.env.AIRTABLE_BASE_ID;

  if (!apiKey || !baseId) {
    console.error('❌ Missing Airtable credentials');
    console.error(
      'Please set AIRTABLE_API_KEY and AIRTABLE_BASE_ID environment variables',
    );
    process.exit(1);
  }

  console.log('🔍 Testing Airtable Ratings Connection...\n');
  console.log(`📊 Table: ${RATING_CONFIG.TABLE_NAME}`);
  console.log(`🔑 Base ID: ${baseId.substring(0, 8)}...`);

  try {
    const airtable = new Airtable({ apiKey });
    const base = airtable.base(baseId);

    // Fetch first 5 ratings to verify schema
    const records = await base(RATING_CONFIG.TABLE_NAME)
      .select({
        maxRecords: 5,
      })
      .all();

    console.log(`\n✅ Successfully connected to Airtable`);
    console.log(`📈 Found ${records.length} sample ratings\n`);

    if (records.length === 0) {
      console.warn('⚠️  No ratings found in table');
      return;
    }

    // Verify schema
    console.log('🔍 Verifying field schema...\n');

    const firstRecord = records[0];
    const fields = firstRecord.fields;

    const fieldChecks = [
      { name: 'Record ID', field: RATING_FIELDS.RECORD_ID },
      { name: 'Event Reference', field: RATING_FIELDS.EVENT_REFERENCE },
      { name: 'Overall Rating', field: RATING_FIELDS.OVERALL_RATING },
      { name: 'Technical Rating', field: RATING_FIELDS.TECHNICAL_RATING },
      { name: 'Artistic Rating', field: RATING_FIELDS.ARTISTIC_RATING },
      { name: 'Audience Rating', field: RATING_FIELDS.AUDIENCE_RATING },
      { name: 'Comments', field: RATING_FIELDS.COMMENTS },
      { name: 'Review Date', field: RATING_FIELDS.REVIEW_DATE },
      { name: 'Reviewer Name', field: RATING_FIELDS.REVIEWER_NAME },
      { name: 'Reviewer Role', field: RATING_FIELDS.REVIEWER_ROLE },
    ];

    for (const check of fieldChecks) {
      const exists =
        check.field in fields || firstRecord.id === fields[check.field];
      const value = fields[check.field];
      const status = exists || value !== undefined ? '✅' : '❌';
      console.log(`${status} ${check.name}: ${value || 'N/A'}`);
    }

    // Sample rating details
    console.log('\n📋 Sample Rating:');
    console.log('─'.repeat(50));
    records.slice(0, 3).forEach((record, index) => {
      console.log(`\n${index + 1}. Record ID: ${record.id}`);
      console.log(
        `   Event: ${record.fields[RATING_FIELDS.EVENT_REFERENCE] || 'N/A'}`,
      );
      console.log(
        `   Overall: ${record.fields[RATING_FIELDS.OVERALL_RATING] || 'N/A'}/10`,
      );
      console.log(
        `   Reviewer: ${record.fields[RATING_FIELDS.REVIEWER_NAME] || 'N/A'}`,
      );
      if (record.fields[RATING_FIELDS.COMMENTS]) {
        const comment = String(record.fields[RATING_FIELDS.COMMENTS]);
        console.log(
          `   Comment: ${comment.substring(0, 60)}${comment.length > 60 ? '...' : ''}`,
        );
      }
    });

    // Get total count
    const allRecords = await base(RATING_CONFIG.TABLE_NAME).select().all();
    console.log(`\n\n📊 Total ratings in Airtable: ${allRecords.length}`);
    console.log('✅ Airtable connection test successful!\n');
  } catch (error) {
    console.error('\n❌ Error testing Airtable connection:');
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

testAirtableRatings();

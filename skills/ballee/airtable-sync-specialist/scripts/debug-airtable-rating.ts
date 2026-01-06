/**
 * Debug script to check specific Airtable rating record
 * Run with: npx tsx scripts/debug-airtable-rating.ts
 */
import Airtable from 'airtable';

import {
  RATING_CONFIG,
  RATING_FIELDS,
} from '../app/admin/sync/_lib/server/constants';

async function debugRating() {
  const apiKey = process.env.AIRTABLE_API_KEY;
  const baseId = process.env.AIRTABLE_BASE_ID;
  const recordId = process.env.DEBUG_RATING_RECORD_ID || 'reccF3y95aoFRNGuv'; // Default for production

  if (!apiKey || !baseId) {
    console.error('❌ Missing Airtable credentials');
    process.exit(1);
  }

  console.log('🔍 Debugging Airtable Rating Record...\n');
  console.log(`📊 Table: ${RATING_CONFIG.TABLE_NAME}`);
  console.log(
    `🔑 Record ID: ${recordId} ${process.env.DEBUG_RATING_RECORD_ID ? '(from env)' : '(default)'}\n`,
  );

  try {
    const airtable = new Airtable({ apiKey });
    const base = airtable.base(baseId);

    // Fetch the specific record
    const record = await base(RATING_CONFIG.TABLE_NAME).find(recordId);

    console.log('✅ Record found!\n');
    console.log('📋 All fields in record:');
    console.log(JSON.stringify(record.fields, null, 2));

    console.log('\n🔍 Mapped field values:');
    console.log(
      `  ${RATING_FIELDS.NAME}: ${record.fields[RATING_FIELDS.NAME]}`,
    );
    console.log(
      `  ${RATING_FIELDS.DATE}: ${record.fields[RATING_FIELDS.DATE]}`,
    );
    console.log(
      `  ${RATING_FIELDS.SHOW_TIME}: ${record.fields[RATING_FIELDS.SHOW_TIME]}`,
    );
    console.log(
      `  ${RATING_FIELDS.RATING}: ${record.fields[RATING_FIELDS.RATING]}`,
    );
    console.log(
      `  ${RATING_FIELDS.COMMENT}: ${record.fields[RATING_FIELDS.COMMENT]}`,
    );

    console.log('\n🔢 Rating value details:');
    const ratingValue = record.fields[RATING_FIELDS.RATING];
    console.log(`  Raw value: ${ratingValue}`);
    console.log(`  Type: ${typeof ratingValue}`);
    console.log(`  Parsed as number: ${Number(ratingValue)}`);
    console.log(`  Used directly in DB (1-5 star scale)`);

    // Check for other possible rating fields
    console.log('\n🔍 Checking for other rating fields:');
    const possibleRatingFields = [
      'Overall Rating',
      'Overall',
      'Rating',
      'Stars',
      'Score',
      'Technical Rating',
      'Artistic Rating',
      'Audience Rating',
    ];

    for (const field of possibleRatingFields) {
      if (field in record.fields) {
        console.log(`  ✅ ${field}: ${record.fields[field]}`);
      }
    }
  } catch (error) {
    console.error('\n❌ Error:');
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

debugRating();

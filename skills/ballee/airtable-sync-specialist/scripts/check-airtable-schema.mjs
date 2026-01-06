#!/usr/bin/env node
/**
 * Check Airtable Schema - Verify field names and types
 *
 * This script fetches a sample record from the "Ballee Dates" table
 * and displays all field names to help verify the canceled field implementation.
 *
 * Usage: node scripts/check-airtable-schema.mjs
 */
import Airtable from 'airtable';

// Configuration from environment
const AIRTABLE_API_KEY = process.env.AIRTABLE_API_KEY;
const AIRTABLE_BASE_ID = process.env.AIRTABLE_BASE_ID;
const AIRTABLE_TABLE_NAME = process.env.AIRTABLE_TABLE_NAME || 'Ballee Dates';

if (!AIRTABLE_API_KEY || !AIRTABLE_BASE_ID) {
  console.error('❌ Missing required environment variables:');
  console.error('   AIRTABLE_API_KEY');
  console.error('   AIRTABLE_BASE_ID');
  console.error('\nSet these in your .env.local file');
  process.exit(1);
}

console.log('🔍 Checking Airtable Schema...\n');
console.log(`📊 Table: ${AIRTABLE_TABLE_NAME}`);
console.log(`🗄️  Base ID: ${AIRTABLE_BASE_ID}\n`);

// Initialize Airtable
const airtable = new Airtable({ apiKey: AIRTABLE_API_KEY });
const base = airtable.base(AIRTABLE_BASE_ID);

try {
  // Fetch first 3 records to see field variations
  const records = await base(AIRTABLE_TABLE_NAME)
    .select({
      maxRecords: 3,
    })
    .all();

  if (records.length === 0) {
    console.log('⚠️  No records found in table');
    process.exit(0);
  }

  console.log(`✅ Found ${records.length} sample records\n`);
  console.log('═'.repeat(80));
  console.log('FIELD ANALYSIS');
  console.log('═'.repeat(80));

  // Collect all unique field names
  const allFields = new Set();
  records.forEach((record) => {
    Object.keys(record.fields).forEach((fieldName) => {
      allFields.add(fieldName);
    });
  });

  console.log(`\n📋 Total unique fields: ${allFields.size}\n`);

  // Display each field with sample values
  const sortedFields = Array.from(allFields).sort();

  sortedFields.forEach((fieldName) => {
    console.log(`\n📌 Field: "${fieldName}"`);
    console.log('─'.repeat(80));

    // Show values from each record
    records.forEach((record, idx) => {
      const value = record.fields[fieldName];
      const type = typeof value;
      const displayValue =
        value === undefined
          ? '(undefined)'
          : value === null
            ? '(null)'
            : JSON.stringify(value);

      console.log(`   Record ${idx + 1}: ${displayValue} [${type}]`);
    });
  });

  console.log('\n' + '═'.repeat(80));
  console.log('CANCELED FIELD CHECK');
  console.log('═'.repeat(80) + '\n');

  // Specifically check for canceled-related fields
  const canceledVariants = [
    'Canceled',
    'Cancelled',
    'Status',
    'Is Canceled',
    'Event Status',
    'Cancellation Status',
    'Cancel',
  ];

  let foundCanceledField = false;

  canceledVariants.forEach((variant) => {
    if (allFields.has(variant)) {
      console.log(`✅ FOUND: "${variant}"`);
      foundCanceledField = true;

      // Show sample values
      records.forEach((record, idx) => {
        const value = record.fields[variant];
        console.log(
          `   Record ${idx + 1}: ${JSON.stringify(value)} [${typeof value}]`,
        );
      });
      console.log();
    } else {
      console.log(`❌ NOT FOUND: "${variant}"`);
    }
  });

  if (!foundCanceledField) {
    console.log('\n⚠️  WARNING: No canceled field found!');
    console.log(
      '   The canceled events feature expects a field named "Canceled"',
    );
    console.log('   but none of the common variants were found.');
    console.log('\n   Action needed:');
    console.log(
      '   1. Add a checkbox field named "Canceled" to the Airtable table',
    );
    console.log(
      '   2. OR update AIRTABLE_FIELDS.CANCELED constant to match existing field',
    );
    console.log('\n   Current implementation assumes:');
    console.log('   - Field name: "Canceled"');
    console.log('   - Field type: Checkbox (boolean)');
    console.log(
      '   - Values: true (canceled) / false or undefined (not canceled)',
    );
  } else {
    console.log(
      '\n✅ Canceled field found! Verify the implementation matches:',
    );
    console.log('   - Field name in constants.ts');
    console.log('   - Parsing logic in airtable-api.service.ts');
  }

  console.log('\n' + '═'.repeat(80));
  console.log('SAMPLE RECORD DETAILS');
  console.log('═'.repeat(80) + '\n');

  // Show full first record
  console.log('First record (complete):');
  console.log(JSON.stringify(records[0].fields, null, 2));

  console.log('\n✅ Schema check complete!');
  console.log(
    '\n📖 See docs/wip/active/AIRTABLE_CANCELED_FIELD_VERIFICATION.md for details',
  );
} catch (error) {
  console.error('\n❌ Error fetching Airtable data:');
  console.error(error.message);

  if (error.statusCode === 401) {
    console.error('\n🔐 Authentication failed. Check your AIRTABLE_API_KEY');
  } else if (error.statusCode === 404) {
    console.error(
      '\n📋 Table not found. Check AIRTABLE_TABLE_NAME and AIRTABLE_BASE_ID',
    );
  }

  process.exit(1);
}

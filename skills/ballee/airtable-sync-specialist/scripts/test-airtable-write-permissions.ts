/**
 * Comprehensive test for Airtable write permissions
 * Tests ALL fields from schema, including empty ones
 */
import Airtable from 'airtable';

const BASE_ID = process.env.AIRTABLE_BASE_ID || 'YOUR_BASE_ID';
const API_KEY = process.env.AIRTABLE_API_KEY || 'YOUR_API_KEY';

// All fields from schema for each table
const TABLES = {
  'Ballee Dates': {
    id: 'tblIsDWRcG6w9Dre9',
    fields: [
      { name: 'UniqueID', type: 'multilineText', testValue: 'TEST' },
      { name: 'Year', type: 'multilineText', testValue: '2025' },
      { name: 'Date', type: 'date', testValue: '2025-01-01' },
      { name: 'City_linked', type: 'singleLineText', testValue: 'Test City' },
      { name: 'Venue', type: 'singleLineText', testValue: 'Test Venue' },
      {
        name: 'Starttime: 1. Show',
        type: 'singleLineText',
        testValue: '19:00',
      },
      {
        name: 'Starttime: 2. Show',
        type: 'singleLineText',
        testValue: '21:00',
      },
      { name: 'Cast Confirmed', type: 'checkbox', testValue: true },
      { name: 'Month', type: 'multilineText', testValue: 'January' },
      { name: 'Is Premiere', type: 'checkbox', testValue: false },
      { name: 'Dance Assistant', type: 'singleLineText', testValue: 'Test' },
    ],
  },
  Dancer_Data: {
    id: 'tbl8cQHnbsT74Wj0T',
    fields: [
      {
        name: "Artist's name",
        type: 'multilineText',
        testValue: 'Test Artist',
      },
      { name: 'Start Date', type: 'singleLineText', testValue: '2025-01-01' },
      { name: 'Email', type: 'singleLineText', testValue: 'test@test.com' },
      { name: 'Phone', type: 'phoneNumber', testValue: '+1234567890' },
      { name: 'Address', type: 'multilineText', testValue: 'Test Address' },
      { name: 'ID / Passport ', type: 'multilineText', testValue: 'TEST123' },
      {
        name: 'Ballee link',
        type: 'singleLineText',
        testValue: 'https://ballee.app/test',
      },
      { name: 'Rehearsals Rate', type: 'currency', testValue: 100 },
      { name: 'Show Day Rate', type: 'currency', testValue: 150 },
      { name: 'PAYEE ID in TIPALTI', type: 'multilineText', testValue: 'TEST' },
    ],
  },
};

async function testTableWritePermissions(
  tableName: string,
  tableId: string,
  fields: { name: string; type: string; testValue: unknown }[],
) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`📋 TABLE: ${tableName} (${tableId})`);
  console.log('='.repeat(60));

  const airtable = new Airtable({ apiKey: API_KEY });
  const base = airtable.base(BASE_ID);
  const table = base(tableId);

  // Get first record
  let records;
  try {
    records = await table.select({ maxRecords: 1 }).firstPage();
    if (records.length === 0) {
      console.log('⚠️ Table is empty, cannot test');
      return { writable: [], readOnly: [], errors: [] };
    }
  } catch (error) {
    console.log(`❌ Cannot read table: ${(error as Error).message}`);
    return { writable: [], readOnly: [], errors: [] };
  }

  const recordId = records[0].id;
  console.log(`\nTesting on record: ${recordId}\n`);

  const writable: string[] = [];
  const readOnly: string[] = [];
  const errors: { field: string; error: string }[] = [];

  for (const field of fields) {
    // Get current value or use test value
    const currentValue = records[0].fields[field.name];
    const valueToWrite =
      currentValue !== undefined ? currentValue : field.testValue;

    try {
      await table.update(recordId, { [field.name]: valueToWrite });
      writable.push(field.name);
      console.log(`   ✅ "${field.name}": WRITABLE`);
    } catch (error) {
      const errorMsg = (error as Error).message;
      if (
        errorMsg.includes('not authorized') ||
        errorMsg.includes('NOT_AUTHORIZED') ||
        errorMsg.includes('INVALID_PERMISSIONS')
      ) {
        readOnly.push(field.name);
        console.log(`   ❌ "${field.name}": READ-ONLY`);
      } else if (errorMsg.includes('Cannot set values on computed')) {
        console.log(`   🔢 "${field.name}": COMPUTED`);
        errors.push({ field: field.name, error: 'computed' });
      } else {
        console.log(`   ⚠️ "${field.name}": ${errorMsg.substring(0, 60)}`);
        errors.push({ field: field.name, error: errorMsg });
      }
    }
  }

  return { writable, readOnly, errors };
}

async function main() {
  console.log('🔍 COMPREHENSIVE AIRTABLE WRITE PERMISSION TEST');
  console.log(`Base: ${BASE_ID}`);
  console.log(`Token: ${API_KEY.substring(0, 20)}...`);

  const allResults: Record<
    string,
    {
      writable: string[];
      readOnly: string[];
      errors: { field: string; error: string }[];
    }
  > = {};

  for (const [tableName, config] of Object.entries(TABLES)) {
    allResults[tableName] = await testTableWritePermissions(
      tableName,
      config.id,
      config.fields,
    );
  }

  // Final summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 FINAL SUMMARY');
  console.log('='.repeat(60));

  for (const [tableName, result] of Object.entries(allResults)) {
    console.log(`\n${tableName}:`);
    console.log(
      `   ✅ Writable: ${result.writable.length > 0 ? result.writable.join(', ') : '(none)'}`,
    );
    console.log(
      `   ❌ Read-only: ${result.readOnly.length > 0 ? result.readOnly.join(', ') : '(none)'}`,
    );
  }

  const totalWritable = Object.values(allResults).reduce(
    (sum, r) => sum + r.writable.length,
    0,
  );
  console.log(`\n🎯 TOTAL WRITABLE FIELDS: ${totalWritable}`);
}

main().catch(console.error);

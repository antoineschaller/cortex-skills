/**
 * Test accessing Airtable ratings table by table ID
 */
import Airtable from 'airtable';

const apiKey = process.env.AIRTABLE_API_KEY;
const baseId = process.env.AIRTABLE_BASE_ID;
const tableId = 'tblIsDWRcG6w9Dre9'; // From the URL you provided

if (!apiKey || !baseId) {
  console.error('Missing AIRTABLE_API_KEY or AIRTABLE_BASE_ID');
  process.exit(1);
}

console.log('🔍 Testing access to ratings table...\n');
console.log(`Base ID: ${baseId}`);
console.log(`Table ID: ${tableId}\n`);

const airtable = new Airtable({ apiKey });
const base = airtable.base(baseId);

async function testTableById() {
  try {
    // Try accessing by table ID
    console.log('📊 Attempting to fetch records using table ID...\n');

    const records = await base(tableId).select({ maxRecords: 5 }).all();

    console.log(`✅ SUCCESS! Found ${records.length} records\n`);

    if (records.length > 0) {
      console.log('📋 Sample record fields:');
      const firstRecord = records[0];
      console.log(`   Record ID: ${firstRecord.id}`);
      console.log(`\n   Available fields:`);

      Object.keys(firstRecord.fields).forEach((field) => {
        const value = firstRecord.fields[field];
        const displayValue = Array.isArray(value)
          ? `[Array: ${value.length} items]`
          : typeof value === 'object'
            ? '[Object]'
            : String(value).substring(0, 50);
        console.log(`   - ${field}: ${displayValue}`);
      });

      console.log(`\n📊 Total records found: ${records.length}`);

      // Show all record IDs
      console.log(`\n📝 Record IDs:`);
      records.forEach((record, idx) => {
        console.log(`   ${idx + 1}. ${record.id}`);
      });
    } else {
      console.log('⚠️  Table is empty');
    }
  } catch (error) {
    const err = error as { statusCode?: number; message?: string };
    console.error(`❌ Error accessing table:`);
    console.error(`   Status: ${err.statusCode || 'Unknown'}`);
    console.error(`   Message: ${err.message || 'Unknown error'}`);

    if (err.statusCode === 404) {
      console.error(
        `\n💡 Table not found. The table ID might be incorrect or the table might have been deleted.`,
      );
    } else if (err.statusCode === 403) {
      console.error(
        `\n💡 Access denied. The API key doesn't have permission to access this table.`,
      );
      console.error(
        `   Please check that the table is shared with the API key in Airtable.`,
      );
    }
  }
}

testTableById();

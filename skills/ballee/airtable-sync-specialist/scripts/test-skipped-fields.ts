/**
 * Test the previously skipped fields (singleSelect without values + link fields)
 */
import Airtable from 'airtable';

const BASE_ID = process.env.AIRTABLE_BASE_ID || 'YOUR_BASE_ID';
const API_KEY = process.env.AIRTABLE_API_KEY || 'YOUR_API_KEY';
const DANCER_DATA_TABLE_ID = 'tbl8cQHnbsT74Wj0T';
const BALLEE_DATES_TABLE_ID = 'tblIsDWRcG6w9Dre9';

const airtable = new Airtable({ apiKey: API_KEY });
const base = airtable.base(BASE_ID);

async function testSkippedFields() {
  console.log('🔍 TESTING PREVIOUSLY SKIPPED FIELDS\n');

  // Get a dancer record to test on
  const dancerTable = base(DANCER_DATA_TABLE_ID);
  const dancers = await dancerTable.select({ maxRecords: 1 }).firstPage();
  const dancerRecord = dancers[0];
  const dancerRecordId = dancerRecord.id;
  console.log(
    `Testing on dancer: ${dancerRecord.fields["Artist's name"]} (${dancerRecordId})\n`,
  );

  // Get a Ballee Dates record for link field testing
  const datesTable = base(BALLEE_DATES_TABLE_ID);
  const dates = await datesTable.select({ maxRecords: 1 }).firstPage();
  const dateRecordId = dates[0].id;
  console.log(`Link target record: ${dateRecordId}\n`);

  console.log('='.repeat(60));
  console.log('TESTING SKIPPED singleSelect FIELDS');
  console.log('='.repeat(60) + '\n');

  // Test Tipalti Germany
  process.stdout.write('[1/2] "Tipalti - Kzemos Germany GmbH"... ');
  try {
    await dancerTable.update(dancerRecordId, {
      'Tipalti - Kzemos Germany GmbH': { name: 'Pending' },
    });
    console.log('✅ WRITABLE');
  } catch (error) {
    const msg = (error as Error).message;
    if (msg.includes('not authorized')) {
      console.log('❌ READ-ONLY');
    } else {
      console.log('⚠️ ERROR: ' + msg.substring(0, 50));
    }
  }

  await new Promise((r) => setTimeout(r, 200));

  // Test Tipalti Flander
  process.stdout.write('[2/2] "Tipalti - Eventos Singulares Flander"... ');
  try {
    await dancerTable.update(dancerRecordId, {
      'Tipalti - Eventos Singulares Flander': { name: 'Pending' },
    });
    console.log('✅ WRITABLE');
  } catch (error) {
    const msg = (error as Error).message;
    if (msg.includes('not authorized')) {
      console.log('❌ READ-ONLY');
    } else {
      console.log('⚠️ ERROR: ' + msg.substring(0, 50));
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('TESTING LINK FIELDS (multipleRecordLinks)');
  console.log('='.repeat(60) + '\n');

  const linkFields = [
    'Aurora / Cinderella',
    'Prince',
    'Fairy 3',
    'Fairy 4',
    'Fairy 5',
    'Carabose',
  ];

  for (let i = 0; i < linkFields.length; i++) {
    const field = linkFields[i];
    process.stdout.write(`[${i + 1}/6] "${field}"... `);

    try {
      // Try to set a link to the Ballee Dates record
      await dancerTable.update(dancerRecordId, {
        [field]: [dateRecordId],
      });
      console.log('✅ WRITABLE');
    } catch (error) {
      const msg = (error as Error).message;
      if (msg.includes('not authorized')) {
        console.log('❌ READ-ONLY');
      } else if (msg.includes('INVALID_MULTIPLE_CHOICE_OPTIONS')) {
        console.log('❌ READ-ONLY (invalid link)');
      } else {
        console.log('⚠️ ERROR: ' + msg.substring(0, 60));
      }
    }

    await new Promise((r) => setTimeout(r, 200));
  }

  console.log('\n' + '='.repeat(60));
  console.log('📊 SKIPPED FIELDS TEST COMPLETE');
  console.log('='.repeat(60));
}

testSkippedFields().catch(console.error);

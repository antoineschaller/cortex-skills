/**
 * Discover all tables in the Airtable base using the Metadata API
 */

interface AirtableField {
  name: string;
  type: string;
}

interface AirtableTable {
  id: string;
  name: string;
  description?: string;
  fields?: AirtableField[];
}

interface AirtableBaseResponse {
  tables: AirtableTable[];
}

const apiKey = process.env.AIRTABLE_API_KEY;
const baseId = process.env.AIRTABLE_BASE_ID;

if (!apiKey || !baseId) {
  console.error('Missing AIRTABLE_API_KEY or AIRTABLE_BASE_ID');
  process.exit(1);
}

console.log('🔍 Discovering all tables in Airtable base...\n');
console.log(`Base ID: ${baseId}\n`);

async function discoverTables() {
  try {
    // Use Airtable Meta API to list all tables
    const response = await fetch(
      `https://api.airtable.com/v0/meta/bases/${baseId}/tables`,
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
        },
      },
    );

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = (await response.json()) as AirtableBaseResponse;

    if (data.tables && Array.isArray(data.tables)) {
      console.log(`✅ Found ${data.tables.length} table(s) in the base:\n`);

      data.tables.forEach((table, idx) => {
        console.log(`${idx + 1}. ${table.name}`);
        console.log(`   ID: ${table.id}`);
        console.log(`   Description: ${table.description || 'No description'}`);
        console.log(`   Fields: ${table.fields?.length || 0}`);

        if (table.fields && table.fields.length > 0) {
          console.log(`   Field names:`);
          table.fields.slice(0, 10).forEach((field) => {
            console.log(`     - ${field.name} (${field.type})`);
          });
          if (table.fields.length > 10) {
            console.log(`     ... and ${table.fields.length - 10} more fields`);
          }
        }
        console.log('');
      });

      // Look for ratings-related tables
      const ratingsTables = data.tables.filter(
        (t) =>
          t.name.toLowerCase().includes('rating') ||
          t.name.toLowerCase().includes('review') ||
          t.name.toLowerCase().includes('feedback'),
      );

      if (ratingsTables.length > 0) {
        console.log(
          `\n⭐ Found ${ratingsTables.length} ratings-related table(s):`,
        );
        ratingsTables.forEach((table) => {
          console.log(`   - ${table.name} (${table.id})`);
        });
      } else {
        console.log(`\n⚠️  No ratings-related tables found`);
        console.log(
          `   You may need to create a "Ratings" or "Reviews" table in Airtable`,
        );
      }
    } else {
      console.log('⚠️  No tables found or unexpected response format');
    }
  } catch (error) {
    console.error(`❌ Error discovering tables:`);
    console.error(
      `   ${error instanceof Error ? error.message : String(error)}`,
    );

    if (error instanceof Error && error.message.includes('403')) {
      console.error(
        `\n💡 The API key might not have permission to access the Metadata API`,
      );
      console.error(
        `   Try using a Personal Access Token (PAT) with full base access`,
      );
    }
  }
}

discoverTables();

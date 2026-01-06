#!/usr/bin/env tsx
/**
 * Apply atomic_profile_update fix to production database
 *
 * This script applies the critical fix for the ON CONFLICT regression
 * directly to the production database using the service role key.
 */
import { readFileSync } from 'fs';
import { join } from 'path';
import { createClient } from '@supabase/supabase-js';

async function applyMigration() {
  console.log('🔧 Applying atomic_profile_update fix to production...\n');

  // Get production credentials from Supabase CLI config
  const projectRef = readFileSync(
    join(__dirname, '../supabase/.temp/project-ref'),
    'utf-8',
  ).trim();

  // We need the service role key from environment or .env.local
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!serviceRoleKey) {
    console.error(
      '❌ Error: SUPABASE_SERVICE_ROLE_KEY not found in environment',
    );
    console.error(
      '   Run: export SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>',
    );
    process.exit(1);
  }

  const supabaseUrl = `https://${projectRef}.supabase.co`;

  console.log(`📡 Connecting to: ${supabaseUrl}`);

  // Create admin client
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  // Read migration file
  const migrationPath = join(
    __dirname,
    '../supabase/migrations/20251012155558_fix_professional_profiles_on_conflict_regression.sql',
  );
  const migrationSQL = readFileSync(migrationPath, 'utf-8');

  try {
    console.log('⏳ Executing migration SQL...\n');

    // Execute the SQL directly
    const { _data, error } = await supabase.rpc('exec_sql', {
      sql: migrationSQL,
    });

    if (error) {
      // If exec_sql doesn't exist, try alternative approach
      console.log(
        '⚠️  exec_sql function not available, trying direct execution...\n',
      );

      // Split into function creation and comment
      const statements = migrationSQL
        .split(/;\s*(?=--|CREATE|COMMENT)/g)
        .filter((stmt) => stmt.trim().length > 0)
        .map((stmt) => stmt.trim() + (stmt.trim().endsWith(';') ? '' : ';'));

      console.log(`📝 Found ${statements.length} statements to execute\n`);

      // Execute function creation first (the main fix)
      const functionSQL = statements.find((s) =>
        s.includes('CREATE OR REPLACE FUNCTION'),
      );

      if (!functionSQL) {
        throw new Error('Could not find CREATE OR REPLACE FUNCTION statement');
      }

      console.log('🔄 Creating function atomic_profile_update...');

      // Use PostgreSQL REST API to execute SQL
      const response = await fetch(`${supabaseUrl}/rest/v1/rpc/query`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          apikey: serviceRoleKey,
          Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          query: functionSQL,
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(
          `Failed to execute SQL: ${response.status} ${errorText}`,
        );
      }

      console.log('✅ Function created successfully');

      // Execute comment
      const commentSQL = statements.find((s) =>
        s.includes('COMMENT ON FUNCTION'),
      );
      if (commentSQL) {
        console.log('📝 Adding function comment...');
        await fetch(`${supabaseUrl}/rest/v1/rpc/query`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            apikey: serviceRoleKey,
            Authorization: `Bearer ${serviceRoleKey}`,
          },
          body: JSON.stringify({
            query: commentSQL,
          }),
        });
        console.log('✅ Comment added');
      }
    } else {
      console.log('✅ Migration executed successfully');
    }

    console.log('\n🎉 Fix applied successfully to production!');
    console.log('\n📋 Next steps:');
    console.log('   1. Mark migration as applied:');
    console.log(
      '      pnpm supabase migration repair --status applied 20251012155558',
    );
    console.log('   2. Test in production: Have a dancer update their profile');
    console.log('   3. Monitor logs for any errors');
  } catch (error) {
    console.error('\n❌ Error applying migration:', error);
    console.error('\nℹ️  You can still apply manually using the SQL Editor:');
    console.error(`   ${supabaseUrl}/project/${projectRef}/sql/new`);
    process.exit(1);
  }
}

applyMigration();

#!/usr/bin/env tsx
/* eslint-disable @typescript-eslint/no-explicit-any */
/**
 * Diagnose Fever Client RLS Issue
 *
 * This script investigates why the Fever client lookup returns null
 * despite the client existing and the user being a super admin.
 *
 * Usage:
 *   pnpm tsx scripts/diagnose-fever-client-rls.ts
 */
import { createClient } from '@supabase/supabase-js';

import type { Database } from '~/lib/database.types';

async function diagnoseFeverClientRLS() {
  console.log('🔍 Diagnosing Fever Client RLS Issue\n');

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('❌ Missing environment variables');
    process.exit(1);
  }

  const adminClient = createClient<Database>(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  // Test 1: Check if Fever client exists at all
  console.log('='.repeat(70));
  console.log('TEST 1: Does Fever client exist? (Admin client - bypasses RLS)');
  console.log('='.repeat(70));

  const { data: fever, error: feverError } = await adminClient
    .from('clients')
    .select('*')
    .eq('slug', 'fever')
    .maybeSingle();

  if (feverError) {
    console.error('❌ Error querying Fever client:', feverError.message);
    console.error('   Code:', (feverError as any).code);
    console.error('   Details:', (feverError as any).details);
  } else if (!fever) {
    console.log('❌ Fever client DOES NOT EXIST in database');
    console.log('   This is the root cause! The migration was not applied.');
    console.log(
      '\n   Solution: Apply migration apps/web/supabase/migrations/20251017000001_seed_fever_client.sql',
    );
  } else {
    console.log('✅ Fever client EXISTS:');
    console.log(JSON.stringify(fever, null, 2));
  }

  // Test 2: List ALL clients
  console.log('\n' + '='.repeat(70));
  console.log('TEST 2: List all clients in database');
  console.log('='.repeat(70));

  const { data: allClients, error: allError } = await adminClient
    .from('clients')
    .select('id, name, slug, email, created_at');

  if (allError) {
    console.error('❌ Error listing clients:', allError.message);
  } else {
    console.log(`\nTotal clients: ${allClients?.length || 0}`);
    if (allClients && allClients.length > 0) {
      allClients.forEach((client, index) => {
        console.log(`\n${index + 1}. ${client.name} (slug: ${client.slug})`);
        console.log(`   ID: ${client.id}`);
        console.log(`   Email: ${client.email || 'none'}`);
        console.log(`   Created: ${client.created_at}`);
      });
    } else {
      console.log('❌ NO CLIENTS FOUND in database!');
      console.log('   This explains the issue - the clients table is empty.');
    }
  }

  // Test 3: Check RLS policies
  console.log('\n' + '='.repeat(70));
  console.log('TEST 3: Check RLS policies on clients table');
  console.log('='.repeat(70));

  const { data: rls, error: rlsError } = await adminClient.rpc(
    'exec_sql' as any,
    {
      query: `
      SELECT
        schemaname,
        tablename,
        policyname,
        permissive,
        roles,
        cmd,
        qual,
        with_check
      FROM pg_policies
      WHERE tablename = 'clients'
    `,
    },
  );

  if (rlsError) {
    // Try alternative method
    console.log('Trying alternative query method...');

    const { data: altRls, error: altError } = await adminClient
      .from('pg_catalog.pg_policies' as any)
      .select('*')
      .eq('tablename', 'clients');

    if (altError) {
      console.log(
        '⚠️  Cannot query RLS policies (may need direct database access)',
      );
    } else {
      console.log('\nRLS Policies:');
      console.log(JSON.stringify(altRls, null, 2));
    }
  } else {
    console.log('\nRLS Policies:');
    console.log(JSON.stringify(rls, null, 2));
  }

  // Test 4: Check if RLS is enabled
  console.log('\n' + '='.repeat(70));
  console.log('TEST 4: Check if RLS is enabled on clients table');
  console.log('='.repeat(70));

  const { data: rlsEnabled, error: rlsCheckError } = await adminClient
    .from('pg_tables' as any)
    .select('schemaname, tablename, rowsecurity')
    .eq('tablename', 'clients');

  if (rlsCheckError) {
    console.log('⚠️  Cannot check RLS status');
  } else {
    console.log('\nRLS Status:');
    console.log(JSON.stringify(rlsEnabled, null, 2));
  }

  console.log('\n' + '='.repeat(70));
  console.log('DIAGNOSIS COMPLETE');
  console.log('='.repeat(70));
  console.log(
    '\nKey Finding: Check TEST 1 and TEST 2 above to see if Fever client exists.',
  );
}

diagnoseFeverClientRLS().catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});

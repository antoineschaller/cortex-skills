#!/usr/bin/env tsx
/* eslint-disable @typescript-eslint/no-explicit-any, @typescript-eslint/no-unused-vars */
/**
 * Test RLS and is_super_admin() Function
 *
 * This script tests whether the is_super_admin() function is working correctly
 * and whether RLS policies are properly configured on the clients table.
 *
 * Usage:
 *   pnpm tsx scripts/test-rls-and-is-super-admin.ts
 */
import { createClient } from '@supabase/supabase-js';

import { getSupabaseServerClient } from '@kit/supabase/server-client';

import type { Database } from '~/lib/database.types';

async function testRLSAndSuperAdmin() {
  console.log('🔍 Testing RLS and is_super_admin() Function\n');

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('❌ Missing environment variables');
    process.exit(1);
  }

  // Test 1: Check is_super_admin() function via SQL
  console.log('='.repeat(60));
  console.log('TEST 1: Check is_super_admin() function in production');
  console.log('='.repeat(60));

  const adminClient = createClient<Database>(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const { data: functionCheck, error: functionError } = await adminClient.rpc(
    'is_super_admin' as any,
  );

  console.log('is_super_admin() result (admin client):', functionCheck);
  if (functionError) {
    console.error('Error:', functionError.message);
  }

  // Test 2: Check RLS policies on clients table
  console.log('\n' + '='.repeat(60));
  console.log('TEST 2: Query RLS policies on clients table');
  console.log('='.repeat(60));

  const { data: policies, error: policiesError } = await adminClient
    .from('pg_policies' as any)
    .select('*')
    .eq('tablename', 'clients');

  if (policiesError) {
    console.error('Error fetching policies:', policiesError.message);
  } else {
    console.log('\nPolicies on clients table:');
    policies?.forEach((policy: any) => {
      console.log(`\nPolicy: ${policy.policyname}`);
      console.log(`  Command: ${policy.cmd}`);
      console.log(`  Using: ${policy.qual}`);
      console.log(`  With Check: ${policy.with_check}`);
    });
  }

  // Test 3: Check if Fever client exists (admin client - bypasses RLS)
  console.log('\n' + '='.repeat(60));
  console.log('TEST 3: Check if Fever client exists (admin client)');
  console.log('='.repeat(60));

  const { data: feverAdmin, error: feverAdminError } = await adminClient
    .from('clients')
    .select('id, name, slug, email')
    .eq('slug', 'fever')
    .maybeSingle();

  if (feverAdminError) {
    console.error('Error:', feverAdminError.message);
  } else if (feverAdmin) {
    console.log('✅ Fever client found:', feverAdmin);
  } else {
    console.log('❌ Fever client NOT found');
  }

  // Test 4: List ALL clients (admin client)
  console.log('\n' + '='.repeat(60));
  console.log('TEST 4: List all clients (admin client)');
  console.log('='.repeat(60));

  const { data: allClients, error: allClientsError } = await adminClient
    .from('clients')
    .select('id, name, slug');

  if (allClientsError) {
    console.error('Error:', allClientsError.message);
  } else {
    console.log(`\nTotal clients: ${allClients?.length}`);
    allClients?.forEach((client) => {
      console.log(`  - ${client.slug} (${client.name})`);
    });
  }

  // Test 5: Check JWT structure via SQL
  console.log('\n' + '='.repeat(60));
  console.log('TEST 5: Inspect auth.jwt() structure');
  console.log('='.repeat(60));

  const { data: jwtData, error: jwtError } = await adminClient.rpc(
    'exec_sql' as any,
    {
      sql: "SELECT auth.jwt() AS jwt_token, (auth.jwt() ->> 'app_metadata')::jsonb ->> 'role' AS role",
    },
  );

  if (jwtError) {
    console.log('Cannot query JWT (expected in admin context)');
  } else {
    console.log('JWT inspection:', jwtData);
  }

  // Test 6: Test is_super_admin() via raw SQL
  console.log('\n' + '='.repeat(60));
  console.log('TEST 6: Test is_super_admin() via SQL query');
  console.log('='.repeat(60));

  const { data: sqlResult, error: sqlError } = await adminClient.rpc(
    'exec_sql' as any,
    {
      sql: 'SELECT public.is_super_admin() AS is_admin',
    },
  );

  if (sqlError) {
    console.log('Cannot execute SQL query');
  } else {
    console.log('is_super_admin() SQL result:', sqlResult);
  }

  console.log('\n' + '='.repeat(60));
  console.log('DIAGNOSIS COMPLETE');
  console.log('='.repeat(60));
}

testRLSAndSuperAdmin().catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});

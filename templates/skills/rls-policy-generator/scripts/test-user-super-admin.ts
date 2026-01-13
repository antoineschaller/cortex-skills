#!/usr/bin/env tsx
/**
 * Test User Super Admin Status
 *
 * This script tests if the current user session has proper super admin privileges
 * by checking:
 * 1. User authentication
 * 2. is_super_admin() function evaluation
 * 3. RLS policy effectiveness for clients table
 *
 * Usage:
 *   pnpm tsx scripts/test-user-super-admin.ts
 */
import { getSupabaseServerClient } from '@kit/supabase/server-client';

interface TestResult {
  step: string;
  success: boolean;
  message: string;
  data?: unknown;
  error?: string;
}

const results: TestResult[] = [];

function logResult(result: TestResult) {
  results.push(result);
  const icon = result.success ? '✅' : '❌';
  console.log(`${icon} ${result.step}: ${result.message}`);
  if (result.data) {
    console.log('   Data:', JSON.stringify(result.data, null, 2));
  }
  if (result.error) {
    console.error('   Error:', result.error);
  }
}

async function testSuperAdminAccess() {
  console.log('🔍 Testing User Super Admin Access\n');

  // Get user session
  const userClient = getSupabaseServerClient();

  // Step 1: Check authentication
  const {
    data: { user },
    error: authError,
  } = await userClient.auth.getUser();

  if (authError || !user) {
    logResult({
      step: 'Authentication',
      success: false,
      message: 'User not authenticated',
      error: authError?.message ?? 'No user session',
    });
    return;
  }

  logResult({
    step: 'Authentication',
    success: true,
    message: 'User authenticated',
    data: {
      userId: user.id,
      email: user.email,
      role: user.app_metadata?.role,
    },
  });

  // Step 2: Check app_metadata role
  const role = user.app_metadata?.role;
  const isSuperAdminRole = role === 'super-admin';

  logResult({
    step: 'JWT Role Check',
    success: isSuperAdminRole,
    message: isSuperAdminRole
      ? 'User has super-admin role in JWT'
      : `User role is "${role}" (expected "super-admin")`,
    data: {
      role,
      app_metadata: user.app_metadata,
    },
  });

  if (!isSuperAdminRole) {
    console.log('\n⚠️  CRITICAL: User does not have super-admin role in JWT!');
    console.log('   This is why RLS policies are blocking access.');
    console.log('\n   To fix: Update user role in Supabase Dashboard:');
    console.log('   1. Go to Authentication → Users');
    console.log(`   2. Find user: ${user.email}`);
    console.log('   3. Edit Raw User Meta Data');
    console.log('   4. Set app_metadata.role to "super-admin"');
    console.log('   5. Save and try again\n');
  }

  // Step 3: Test is_super_admin() function via RPC
  try {
    const { data: isSuperAdmin, error: rpcError } =
      await userClient.rpc('is_super_admin');

    if (rpcError) {
      logResult({
        step: 'is_super_admin() Function',
        success: false,
        message: 'Failed to call is_super_admin()',
        error: rpcError.message,
      });
    } else {
      logResult({
        step: 'is_super_admin() Function',
        success: isSuperAdmin === true,
        message: isSuperAdmin
          ? 'is_super_admin() returns true'
          : 'is_super_admin() returns false',
        data: { result: isSuperAdmin },
      });
    }
  } catch (error) {
    logResult({
      step: 'is_super_admin() Function',
      success: false,
      message: 'Exception calling is_super_admin()',
      error: error instanceof Error ? error.message : String(error),
    });
  }

  // Step 4: Test SELECT on clients table
  const { data: clients, error: selectError } = await userClient
    .from('clients')
    .select('id, name, slug')
    .limit(5);

  if (selectError) {
    logResult({
      step: 'Clients Table SELECT',
      success: false,
      message: 'Cannot SELECT from clients table',
      error: selectError.message,
    });
  } else {
    logResult({
      step: 'Clients Table SELECT',
      success: true,
      message: `Can SELECT from clients table (found ${clients?.length ?? 0})`,
      data: {
        clientCount: clients?.length,
        clients: clients?.map((c) => c.slug),
      },
    });
  }

  // Step 5: Test SELECT Fever client specifically
  const { data: feverClient, error: feverError } = await userClient
    .from('clients')
    .select('id, name, slug, email')
    .eq('slug', 'fever')
    .maybeSingle();

  if (feverError) {
    logResult({
      step: 'Fever Client Lookup',
      success: false,
      message: 'Cannot lookup Fever client',
      error: feverError.message,
    });
  } else if (!feverClient) {
    logResult({
      step: 'Fever Client Lookup',
      success: false,
      message: 'Fever client not found (query returned null)',
      error:
        'RLS might be blocking access OR client does not exist. Run verify-fever-client.ts with admin credentials.',
    });
  } else {
    logResult({
      step: 'Fever Client Lookup',
      success: true,
      message: 'Fever client found successfully',
      data: feverClient,
    });
  }

  // Step 6: Test INSERT capability
  const testSlug = `test-${Date.now()}`;
  const { data: inserted, error: insertError } = await userClient
    .from('clients')
    .insert({
      name: 'Test Client',
      slug: testSlug,
      email: 'test@test.local',
      type: 'agency',
    })
    .select('id, slug')
    .single();

  if (insertError) {
    logResult({
      step: 'Client INSERT Test',
      success: false,
      message: 'Cannot INSERT into clients table',
      error: insertError.message,
    });
  } else {
    // Clean up
    await userClient.from('clients').delete().eq('id', inserted.id);

    logResult({
      step: 'Client INSERT Test',
      success: true,
      message: 'Can INSERT into clients table',
      data: { testSlug, wasDeleted: true },
    });
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('TEST SUMMARY');
  console.log('='.repeat(60));

  results.forEach((result) => {
    const icon = result.success ? '✅' : '❌';
    console.log(`${icon} ${result.step}`);
  });

  const passed = results.filter((r) => r.success).length;
  const total = results.length;

  console.log('='.repeat(60));
  console.log(`\nResults: ${passed}/${total} checks passed\n`);

  if (!isSuperAdminRole) {
    console.log('🔴 ROOT CAUSE IDENTIFIED:');
    console.log('   User JWT does not contain super-admin role.');
    console.log('   Update user role in Supabase Dashboard to fix.\n');
    process.exit(1);
  }

  if (passed === total) {
    console.log('✅ All checks passed. User has proper super admin access.\n');
    process.exit(0);
  } else {
    console.log(
      '❌ Some checks failed. Review errors above to identify issues.\n',
    );
    process.exit(1);
  }
}

// Run test
testSuperAdminAccess().catch((error) => {
  console.error('💥 Test script failed:', error);
  process.exit(1);
});

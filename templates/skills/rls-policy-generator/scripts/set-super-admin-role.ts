#!/usr/bin/env tsx
/**
 * Set Super Admin Role for User
 *
 * This script updates a user's app_metadata to grant super-admin role.
 * This is necessary for the user to bypass RLS policies protected by is_super_admin().
 *
 * Usage:
 *   pnpm tsx scripts/set-super-admin-role.ts <user-id>
 *
 * Example:
 *   pnpm tsx scripts/set-super-admin-role.ts fdd7be46-a8ee-4c6d-9a28-8251abf1860e
 */
import { createClient } from '@supabase/supabase-js';

async function setSuperAdminRole(userId: string) {
  console.log('🔧 Setting super-admin role for user:', userId);

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('❌ Missing environment variables:');
    console.error('   SUPABASE_URL:', supabaseUrl ? '✓' : '✗');
    console.error('   SUPABASE_SERVICE_ROLE_KEY:', serviceRoleKey ? '✓' : '✗');
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  try {
    // Step 1: Get current user data
    console.log('\n📋 Fetching current user data...');
    const { data: currentUser, error: fetchError } =
      await supabase.auth.admin.getUserById(userId);

    if (fetchError) {
      console.error('❌ Failed to fetch user:', fetchError.message);
      process.exit(1);
    }

    if (!currentUser.user) {
      console.error('❌ User not found:', userId);
      process.exit(1);
    }

    console.log('✅ User found:', {
      id: currentUser.user.id,
      email: currentUser.user.email,
      currentRole: currentUser.user.app_metadata?.role || 'none',
    });

    // Step 2: Update user metadata to add super-admin role
    console.log('\n🔄 Updating user role to super-admin...');

    const updatedAppMetadata = {
      ...currentUser.user.app_metadata,
      role: 'super-admin',
    };

    const { data: updatedUser, error: updateError } =
      await supabase.auth.admin.updateUserById(userId, {
        app_metadata: updatedAppMetadata,
      });

    if (updateError) {
      console.error('❌ Failed to update user:', updateError.message);
      process.exit(1);
    }

    console.log('✅ User role updated successfully!');
    console.log('\n📊 Updated user data:', {
      id: updatedUser.user.id,
      email: updatedUser.user.email,
      role: updatedUser.user.app_metadata?.role,
      app_metadata: updatedUser.user.app_metadata,
    });

    // Step 3: Verify the update
    console.log('\n🔍 Verifying update...');
    const { data: verifiedUser, error: verifyError } =
      await supabase.auth.admin.getUserById(userId);

    if (verifyError) {
      console.warn('⚠️  Could not verify update:', verifyError.message);
    } else {
      const verifiedRole = verifiedUser.user?.app_metadata?.role;
      if (verifiedRole === 'super-admin') {
        console.log('✅ Verification successful! Role is now: super-admin');
      } else {
        console.warn('⚠️  Verification failed. Current role:', verifiedRole);
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('✅ SUPER ADMIN ROLE SET SUCCESSFULLY');
    console.log('='.repeat(60));
    console.log('\n📝 Next steps:');
    console.log('   1. User must LOG OUT and LOG BACK IN to refresh JWT');
    console.log('   2. After re-login, test the Airtable sync');
    console.log('   3. The sync should now work without RLS blocking\n');
  } catch (error) {
    console.error('💥 Unexpected error:', error);
    process.exit(1);
  }
}

// Main execution
const userId = process.argv[2];

if (!userId) {
  console.error('❌ Usage: pnpm tsx scripts/set-super-admin-role.ts <user-id>');
  console.error(
    '\nExample: pnpm tsx scripts/set-super-admin-role.ts fdd7be46-a8ee-4c6d-9a28-8251abf1860e',
  );
  process.exit(1);
}

// Validate UUID format
const uuidRegex =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
if (!uuidRegex.test(userId)) {
  console.error('❌ Invalid user ID format. Must be a valid UUID.');
  process.exit(1);
}

setSuperAdminRole(userId).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});

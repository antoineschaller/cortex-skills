#!/usr/bin/env tsx
/**
 * Debug RLS for event_invitations
 * Tests if authenticated dancers can update their own invitations
 */
import { createClient, SupabaseClient } from '@supabase/supabase-js';

const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321';
const SUPABASE_ANON_KEY =
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

const SUPER_ADMIN_EMAIL = 'antoine@ballee.co';
const SUPER_ADMIN_ID = 'a1b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d';
const DANCER_EMAIL = 'dancer@ballee.test';
const DANCER_ID = '00000000-0000-0000-0000-000000000005';

async function debugRLS() {
  console.log('🔍 RLS Debug Script for event_invitations\n');

  // Step 1: Create admin client
  console.log('Step 1: Creating super admin client...');
  const adminClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false },
  });

  const { error: adminAuthError } = await adminClient.auth.signInWithPassword({
    email: SUPER_ADMIN_EMAIL,
    password: 'password',
  });

  if (adminAuthError) {
    console.error('❌ Admin auth failed:', adminAuthError.message);
    return;
  }
  console.log('✅ Admin authenticated\n');

  // Step 2: Create test event
  console.log('Step 2: Creating test event...');
  const testEventId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

  const { error: eventError } = await adminClient.from('events').insert({
    id: testEventId,
    title: '[DEBUG] RLS Test Event',
    production_id: '40000000-0000-0000-0000-000000000001',
    event_type: 'performance',
    event_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      .toISOString()
      .split('T')[0],
    start_date_time: new Date(
      Date.now() + 30 * 24 * 60 * 60 * 1000,
    ).toISOString(),
    start_time: '19:00:00',
    end_time: '21:00:00',
    status: 'open',
    venue_id: '30000000-0000-0000-0000-000000000001',
    created_by: SUPER_ADMIN_ID,
  });

  if (eventError) {
    console.error('❌ Event creation failed:', eventError.message);
    return;
  }
  console.log('✅ Event created:', testEventId, '\n');

  // Step 3: Create invitation
  console.log('Step 3: Creating invitation...');
  const { data: invitation, error: inviteError } = await adminClient
    .from('event_invitations')
    .insert({
      event_id: testEventId,
      inviter_id: SUPER_ADMIN_ID,
      invitee_id: DANCER_ID,
      status: 'pending',
    })
    .select()
    .single();

  if (inviteError) {
    console.error('❌ Invitation creation failed:', inviteError.message);
    await cleanup(adminClient, testEventId);
    return;
  }
  console.log('✅ Invitation created:', invitation.id);
  console.log('   Inviter:', invitation.inviter_id);
  console.log('   Invitee:', invitation.invitee_id);
  console.log('   Status:', invitation.status, '\n');

  // Step 4: Sign out admin, sign in as dancer
  console.log('Step 4: Signing in as dancer...');
  await adminClient.auth.signOut();

  const { data: authData, error: dancerAuthError } =
    await adminClient.auth.signInWithPassword({
      email: DANCER_EMAIL,
      password: 'test-password-123',
    });

  if (dancerAuthError) {
    console.error('❌ Dancer auth failed:', dancerAuthError.message);
    await cleanup(adminClient, testEventId);
    return;
  }

  console.log('✅ Dancer authenticated');
  console.log('   User ID from JWT:', authData.user?.id);
  console.log('   Expected ID:', DANCER_ID);
  console.log('   IDs match:', authData.user?.id === DANCER_ID, '\n');

  // Step 5: Test UPDATE as dancer
  console.log('Step 5: Testing UPDATE as dancer (invitee)...');
  const respondedAt = new Date().toISOString();

  const { data: updatedInvitation, error: updateError } = await adminClient
    .from('event_invitations')
    .update({
      status: 'accepted',
      responded_at: respondedAt,
    })
    .eq('id', invitation.id)
    .select()
    .single();

  if (updateError) {
    console.error('❌ UPDATE FAILED (RLS blocking!)');
    console.error('   Error:', updateError.message);
    console.error('   Code:', updateError.code);
    console.error('   Details:', updateError.details);
    console.error('   Hint:', updateError.hint);
  } else if (!updatedInvitation) {
    console.error('❌ UPDATE RETURNED NULL (RLS policy blocking silently)');
    console.error('   This means USING clause failed but no error was thrown');
  } else {
    console.log('✅ UPDATE SUCCESSFUL!');
    console.log('   New status:', updatedInvitation.status);
    console.log('   Responded at:', updatedInvitation.responded_at);
  }

  // Step 6: Check RLS policies
  console.log('\nStep 6: Checking RLS policies...');
  await adminClient.auth.signOut();
  const { error: adminAuth2Error } = await adminClient.auth.signInWithPassword({
    email: SUPER_ADMIN_EMAIL,
    password: 'password',
  });

  if (!adminAuth2Error) {
    const { data: policies } = await adminClient.rpc('pg_policies', {});
    console.log('RLS policies check:', policies ? '✅' : '❌');
  }

  // Cleanup
  await cleanup(adminClient, testEventId);
}

async function cleanup(client: SupabaseClient, eventId: string) {
  console.log('\n🧹 Cleaning up test data...');
  await client.from('events').delete().eq('id', eventId);
  console.log('✅ Cleanup complete');
}

debugRLS().catch(console.error);

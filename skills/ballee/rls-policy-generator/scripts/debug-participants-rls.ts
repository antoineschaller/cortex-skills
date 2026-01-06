#!/usr/bin/env tsx
/**
 * Debug RLS for event_participants (the table used by UI!)
 * Tests if authenticated dancers can INSERT and UPDATE their own participation
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

async function debugParticipantsRLS() {
  console.log('🔍 RLS Debug Script for event_participants (UI TABLE)\n');

  // Step 1: Create admin client and event
  console.log('Step 1: Setting up test event...');
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

  const testEventId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

  // Clean up first
  await adminClient
    .from('event_participants')
    .delete()
    .eq('event_id', testEventId);
  await adminClient.from('events').delete().eq('id', testEventId);

  const { error: eventError } = await adminClient.from('events').insert({
    id: testEventId,
    title: '[DEBUG] Participants RLS Test',
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

  // Step 2: Sign in as dancer
  console.log('Step 2: Signing in as dancer...');
  await adminClient.auth.signOut();

  const dancerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false },
  });

  const { data: authData, error: dancerAuthError } =
    await dancerClient.auth.signInWithPassword({
      email: DANCER_EMAIL,
      password: 'test-password-123',
    });

  if (dancerAuthError) {
    console.error('❌ Dancer auth failed:', dancerAuthError.message);
    await cleanup(adminClient, testEventId);
    return;
  }

  console.log('✅ Dancer authenticated');
  console.log('   User ID:', authData.user?.id);
  console.log('   Expected:', DANCER_ID);
  console.log('   Match:', authData.user?.id === DANCER_ID, '\n');

  // Step 3: Test INSERT (creating participation as dancer)
  console.log('Step 3: Testing INSERT (dancer creates participation)...');
  const { data: newParticipation, error: insertError } = await dancerClient
    .from('event_participants')
    .insert({
      event_id: testEventId,
      user_id: DANCER_ID,
      status: 'confirmed',
      response_date: new Date().toISOString(),
    })
    .select()
    .single();

  if (insertError) {
    console.error('❌ INSERT FAILED!');
    console.error('   Error:', insertError.message);
    console.error('   Code:', insertError.code);
    console.error('   Details:', insertError.details);
    console.error(
      '   This is the PROBLEM - dancers cannot create participations!\n',
    );
  } else if (!newParticipation) {
    console.error('❌ INSERT RETURNED NULL (RLS blocking)\n');
  } else {
    console.log('✅ INSERT SUCCESSFUL!');
    console.log('   ID:', newParticipation.id);
    console.log('   Status:', newParticipation.status);
    console.log('   User:', newParticipation.user_id, '\n');

    // Step 4: Test UPDATE (if insert worked)
    console.log('Step 4: Testing UPDATE (dancer updates own participation)...');
    const { data: updated, error: updateError } = await dancerClient
      .from('event_participants')
      .update({
        status: 'tentative',
        response_date: new Date().toISOString(),
      })
      .eq('id', newParticipation.id)
      .select()
      .single();

    if (updateError) {
      console.error('❌ UPDATE FAILED!');
      console.error('   Error:', updateError.message);
    } else if (!updated) {
      console.error('❌ UPDATE RETURNED NULL');
    } else {
      console.log('✅ UPDATE SUCCESSFUL!');
      console.log('   New status:', updated.status);
    }
  }

  // Step 5: Check RLS policies
  console.log('\nStep 5: Checking RLS policies on event_participants...');
  await dancerClient.auth.signOut();
  await adminClient.auth.signInWithPassword({
    email: SUPER_ADMIN_EMAIL,
    password: 'password',
  });

  const { data: _policies, error: policyError } = await adminClient.rpc(
    'pg_policies',
    {},
  );
  if (policyError) {
    console.log('Cannot fetch policies directly, check manually in database');
  }

  // Cleanup
  await cleanup(adminClient, testEventId);
}

async function cleanup(client: SupabaseClient, eventId: string) {
  console.log('\n🧹 Cleaning up test data...');
  await client.from('event_participants').delete().eq('event_id', eventId);
  await client.from('events').delete().eq('id', eventId);
  console.log('✅ Cleanup complete');
}

debugParticipantsRLS().catch(console.error);

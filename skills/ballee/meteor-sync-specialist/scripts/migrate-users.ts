#!/usr/bin/env tsx
/**
 * Migrate MongoDB Users to Supabase
 *
 * This script migrates users from MongoDB to Supabase auth.users and profiles tables.
 * It preserves bcrypt password hashes for seamless authentication.
 *
 * PREREQUISITES:
 * - Trigger functions must be fixed to use `public.` schema prefix (see SKILL.md)
 * - Environment variables or defaults for MongoDB and Supabase connections
 *
 * Steps:
 * 1. Fetch all MongoDB users
 * 2. Check for existing Supabase users by email
 * 3. Create new auth.users entries (preserving bcrypt hashes)
 * 4. Create/update profiles with meteor_id mapping
 * 5. Link professional_profiles.user_id where applicable
 *
 * Usage:
 *   npx tsx migrate-users.ts
 *   npx tsx migrate-users.ts --dry-run  # Preview only
 *
 * Last successful run: 2025-12-09
 *   - Created: 12,950 users
 *   - Updated: 1,869 users (existing)
 *   - Professional profiles linked: 13,855
 */
import { randomUUID } from 'crypto';
import { MongoClient } from 'mongodb';
import pg from 'pg';

const { Pool } = pg;

// Connection configuration - use environment variables or defaults
const SUPABASE_HOST =
  process.env.SUPABASE_DB_HOST || 'db.hxpcknyqswetsqmqmeep.supabase.co';
const SUPABASE_DB = 'postgres';
const SUPABASE_USER = 'postgres';
const SUPABASE_PASSWORD = process.env.SUPABASE_DB_PASSWORD_STAGING;
const SUPABASE_PORT = 5432;

const MONGO_URL = process.env.METEOR_MONGO_URL;

// Validate required environment variables
if (!SUPABASE_PASSWORD) {
  console.error(
    'ERROR: SUPABASE_DB_PASSWORD_STAGING environment variable is required',
  );
  console.error(
    'Set it via: export SUPABASE_DB_PASSWORD_STAGING="your-password"',
  );
  process.exit(1);
}

if (!MONGO_URL) {
  console.error('ERROR: METEOR_MONGO_URL environment variable is required');
  console.error('Set it via: export METEOR_MONGO_URL="mongodb://..."');
  process.exit(1);
}

interface MongoUser {
  _id: string;
  emails?: Array<{ address: string; verified?: boolean }>;
  services?: {
    password?: { bcrypt?: string };
    google?: { id?: string; email?: string; name?: string };
    facebook?: { id?: string; email?: string; name?: string };
  };
  profile?: {
    firstname?: string;
    lastname?: string;
    archived?: boolean;
    preferredUserCandidateId?: string;
    preferredUserOrganizationId?: string;
  };
  name?: string;
  createdAt?: Date | string;
  setupComplete?: boolean;
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');

  console.log('=== Migrate MongoDB Users to Supabase ===');
  if (dryRun) {
    console.log('*** DRY RUN MODE - No changes will be made ***');
  }
  console.log('');

  const pool = new Pool({
    host: SUPABASE_HOST,
    database: SUPABASE_DB,
    user: SUPABASE_USER,
    password: SUPABASE_PASSWORD,
    port: SUPABASE_PORT,
    ssl: { rejectUnauthorized: false },
  });

  const pgClient = await pool.connect();
  const mongoClient = new MongoClient(MONGO_URL);
  await mongoClient.connect();
  const db = mongoClient.db();

  try {
    // Build existing email map from Supabase
    console.log('--- Building existing user map ---');
    const existingUsersResult = await pgClient.query(`
      SELECT id, email FROM auth.users
    `);
    const existingEmailMap = new Map<string, string>();
    for (const row of existingUsersResult.rows) {
      if (row.email) existingEmailMap.set(row.email.toLowerCase(), row.id);
    }
    console.log(`Existing Supabase users: ${existingEmailMap.size}`);

    // Build candidate → professional_profile map
    const profProfilesResult = await pgClient.query(`
      SELECT id, meteor_id FROM professional_profiles WHERE meteor_id IS NOT NULL
    `);
    const candidateToProfileMap = new Map<string, string>();
    for (const row of profProfilesResult.rows) {
      candidateToProfileMap.set(row.meteor_id, row.id);
    }
    console.log(
      `Professional profiles with meteor_id: ${candidateToProfileMap.size}`,
    );

    // Fetch all MongoDB users
    const mongoUsers = (await db
      .collection('users')
      .find({})
      .toArray()) as MongoUser[];
    console.log(`MongoDB users to migrate: ${mongoUsers.length}`);

    let created = 0;
    let updated = 0;
    let skipped = 0;
    let failed = 0;
    let profilesLinked = 0;

    for (const user of mongoUsers) {
      const mongoId = user._id?.toString();
      if (!mongoId) {
        skipped++;
        continue;
      }

      // Get primary email
      const primaryEmail = user.emails?.[0]?.address?.toLowerCase();
      if (!primaryEmail) {
        skipped++;
        continue;
      }

      // Get name
      const firstName =
        user.profile?.firstname || user.name?.split(' ')[0] || 'User';
      const lastName =
        user.profile?.lastname ||
        user.name?.split(' ').slice(1).join(' ') ||
        '';

      // Get password hash (Meteor uses bcrypt which Supabase supports)
      const bcryptHash = user.services?.password?.bcrypt;

      // Get creation date
      const createdAt = user.createdAt ? new Date(user.createdAt) : new Date();

      // Check if email verified
      const emailVerified = user.emails?.[0]?.verified === true;

      try {
        // Check if user already exists
        const existingUserId = existingEmailMap.get(primaryEmail);

        let supabaseUserId: string;

        if (existingUserId) {
          // User exists - just update meteor_id in profiles
          supabaseUserId = existingUserId;

          if (!dryRun) {
            // Update profile with meteor_id
            await pgClient.query(
              `
              UPDATE public.profiles SET meteor_id = $1, updated_at = NOW()
              WHERE id = $2 AND meteor_id IS NULL
            `,
              [mongoId, supabaseUserId],
            );
          }

          updated++;
        } else {
          if (dryRun) {
            created++;
            continue;
          }

          // Create new user in auth.users
          supabaseUserId = randomUUID();

          // Start transaction for new user creation
          await pgClient.query('BEGIN');

          try {
            // Supabase auth.users expects specific structure
            // We insert directly into auth.users with the bcrypt hash
            await pgClient.query(
              `
              INSERT INTO auth.users (
                id, instance_id, email, encrypted_password,
                email_confirmed_at, created_at, updated_at,
                raw_app_meta_data, raw_user_meta_data,
                is_super_admin, role, aud, confirmation_token
              ) VALUES (
                $1,
                '00000000-0000-0000-0000-000000000000',
                $2,
                $3,
                $4,
                $5,
                NOW(),
                '{"provider": "email", "providers": ["email"]}',
                $6,
                false,
                'authenticated',
                'authenticated',
                ''
              )
            `,
              [
                supabaseUserId,
                primaryEmail,
                bcryptHash || '', // Empty if no password (social login users)
                emailVerified ? createdAt : null,
                createdAt,
                JSON.stringify({
                  first_name: firstName,
                  last_name: lastName,
                  meteor_id: mongoId,
                }),
              ],
            );

            // Create identity for email provider
            await pgClient.query(
              `
              INSERT INTO auth.identities (
                id, user_id, identity_data, provider, provider_id,
                last_sign_in_at, created_at, updated_at
              ) VALUES (
                $1, $2, $3, 'email', $4, $5, $5, NOW()
              )
            `,
              [
                randomUUID(),
                supabaseUserId,
                JSON.stringify({ sub: supabaseUserId, email: primaryEmail }),
                primaryEmail,
                createdAt,
              ],
            );

            // Commit auth.users insert - trigger will create profile and account
            await pgClient.query('COMMIT');

            // Update profile with meteor_id and first/last name
            await pgClient.query(
              `
              UPDATE public.profiles
              SET meteor_id = $1,
                  first_name = COALESCE(NULLIF(first_name, ''), $2),
                  last_name = COALESCE(NULLIF(last_name, ''), $3),
                  archived = $4,
                  updated_at = NOW()
              WHERE id = $5
            `,
              [
                mongoId,
                firstName,
                lastName,
                user.profile?.archived || false,
                supabaseUserId,
              ],
            );
            existingEmailMap.set(primaryEmail, supabaseUserId);
            created++;
          } catch (txErr) {
            await pgClient.query('ROLLBACK');
            throw txErr;
          }
        }

        // Link professional_profile if user has preferredUserCandidateId
        // Note: The trigger creates a new professional_profile, but we want to link to the existing one from MongoDB
        const candidateId = user.profile?.preferredUserCandidateId;
        if (candidateId && !dryRun) {
          const profProfileId = candidateToProfileMap.get(candidateId);
          if (profProfileId) {
            try {
              // First, check if the trigger created a duplicate profile
              // If so, we need to delete it and link to the existing one
              const triggerProfileResult = await pgClient.query(
                `
                SELECT id FROM professional_profiles
                WHERE user_id = $1 AND profile_type = 'dancer' AND id != $2
              `,
                [supabaseUserId, profProfileId],
              );

              if (triggerProfileResult.rows.length > 0) {
                // Delete the trigger-created profile and link to the MongoDB one
                await pgClient.query(
                  `
                  DELETE FROM dancer_profiles WHERE id = $1
                `,
                  [triggerProfileResult.rows[0].id],
                );
                await pgClient.query(
                  `
                  DELETE FROM professional_profiles WHERE id = $1
                `,
                  [triggerProfileResult.rows[0].id],
                );
              }

              // Link the existing MongoDB profile to this user
              const linkResult = await pgClient.query(
                `
                UPDATE professional_profiles
                SET user_id = $1, updated_at = NOW()
                WHERE id = $2 AND (user_id IS NULL OR user_id = $1)
              `,
                [supabaseUserId, profProfileId],
              );
              if (linkResult.rowCount && linkResult.rowCount > 0) {
                profilesLinked++;
              }
            } catch (_linkErr) {
              // Ignore linking errors - profile may already be linked
            }
          }
        }
      } catch (err) {
        failed++;
        if (failed <= 10) {
          console.error(
            `  Failed ${mongoId} (${primaryEmail}):`,
            (err as Error).message,
          );
        }
      }
    }

    console.log(`\n=== Migration Results ===`);
    console.log(`Created: ${created}`);
    console.log(`Updated (existing): ${updated}`);
    console.log(`Skipped (no email): ${skipped}`);
    console.log(`Failed: ${failed}`);
    console.log(`Professional profiles linked: ${profilesLinked}`);

    if (!dryRun) {
      // Final counts
      const finalCounts = await pgClient.query(`
        SELECT
          (SELECT COUNT(*) FROM auth.users) as auth_users,
          (SELECT COUNT(*) FROM profiles) as profiles,
          (SELECT COUNT(*) FROM profiles WHERE meteor_id IS NOT NULL) as profiles_with_meteor_id,
          (SELECT COUNT(*) FROM professional_profiles WHERE user_id IS NOT NULL) as prof_profiles_linked
      `);

      console.log(`\n=== Final State ===`);
      console.log(`Auth users: ${finalCounts.rows[0].auth_users}`);
      console.log(`Profiles: ${finalCounts.rows[0].profiles}`);
      console.log(
        `Profiles with meteor_id: ${finalCounts.rows[0].profiles_with_meteor_id}`,
      );
      console.log(
        `Professional profiles with user_id: ${finalCounts.rows[0].prof_profiles_linked}`,
      );
    }
  } finally {
    pgClient.release();
    await pool.end();
    await mongoClient.close();
  }
}

main().catch(console.error);

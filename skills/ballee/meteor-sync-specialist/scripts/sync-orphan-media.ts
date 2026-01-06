#!/usr/bin/env tsx
/**
 * Sync Orphan Media
 *
 * This script syncs media that only has userId (no candidateId/organizationId)
 * to the profile_media table, now that users are migrated.
 *
 * PREREQUISITES:
 * - Users must be migrated first (run migrate-users.ts)
 * - profiles table must have meteor_id populated
 *
 * Usage:
 *   npx tsx sync-orphan-media.ts
 *   npx tsx sync-orphan-media.ts --dry-run  # Preview only
 *
 * Last successful run: 2025-12-09
 *   - Synced: 1,824 records
 *   - Total profile_media: 2,283
 */
import { MongoClient } from 'mongodb';
import pg from 'pg';

const { Pool } = pg;

// Connection configuration - use environment variables
const SUPABASE_HOST =
  process.env.SUPABASE_DB_HOST || 'db.hxpcknyqswetsqmqmeep.supabase.co';
const SUPABASE_DB = 'postgres';
const SUPABASE_USER = 'postgres';
const SUPABASE_PASSWORD = process.env.SUPABASE_DB_PASSWORD_STAGING;
const SUPABASE_PORT = 5432;

const MONGO_URL = process.env.METEOR_MONGO_URL;

// S3 configuration for URL construction
const S3_REGION = 'eu-central-1';
const S3_BUCKET = 'ch.akson.dance.bucket';

// Validate required environment variables
if (!SUPABASE_PASSWORD) {
  console.error(
    'ERROR: SUPABASE_DB_PASSWORD_STAGING environment variable is required',
  );
  process.exit(1);
}

if (!MONGO_URL) {
  console.error('ERROR: METEOR_MONGO_URL environment variable is required');
  process.exit(1);
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');

  console.log('=== Sync Orphan Media ===');
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
    // Build user mapping (MongoDB userId -> Supabase profiles.id via meteor_id)
    console.log('Building user mapping...');
    const profilesResult = await pgClient.query(`
      SELECT id, meteor_id FROM public.profiles WHERE meteor_id IS NOT NULL
    `);
    const userMap = new Map<string, string>();
    for (const row of profilesResult.rows) {
      userMap.set(row.meteor_id, row.id);
    }
    console.log(`Profiles with meteor_id: ${userMap.size}`);

    // Get orphan media from MongoDB (has userId but no candidateId/organizationId)
    const orphanMedia = await db
      .collection('Media')
      .find({
        userId: { $exists: true },
        candidateId: { $exists: false },
        organizationId: { $exists: false },
        archived: { $ne: true },
      })
      .toArray();

    console.log(`Orphan media in MongoDB: ${orphanMedia.length}`);

    let synced = 0;
    let skipped = 0;
    let failed = 0;

    for (const media of orphanMedia) {
      const mongoMediaId = (
        media._id as unknown as { toString(): string }
      )?.toString();
      const mongoUserId = media.userId as string;

      if (!mongoMediaId || !mongoUserId) {
        skipped++;
        continue;
      }

      // Find Supabase profile for this user
      const profileId = userMap.get(mongoUserId);
      if (!profileId) {
        skipped++;
        continue;
      }

      // Construct media URL
      let mediaUrl: string | null = null;
      const fileObj = media.file as { s3Key?: string } | undefined;
      if (fileObj?.s3Key) {
        mediaUrl = `https://s3.${S3_REGION}.amazonaws.com/${S3_BUCKET}/${fileObj.s3Key}`;
      } else if ((media as { videoUrl?: string }).videoUrl) {
        mediaUrl = (media as { videoUrl: string }).videoUrl;
      }

      if (!mediaUrl) {
        skipped++;
        continue;
      }

      // Determine media type
      const isVideo = (media.isVideo as boolean) || false;
      const mediaType = isVideo ? 'video' : 'photo';

      try {
        // Check if already synced
        const existsResult = await pgClient.query(
          `
          SELECT id FROM profile_media WHERE url = $1 AND profile_id = $2
        `,
          [mediaUrl, profileId],
        );

        if (existsResult.rows.length > 0) {
          skipped++;
          continue;
        }

        if (!dryRun) {
          // Insert into profile_media
          await pgClient.query(
            `
            INSERT INTO public.profile_media (
              profile_id, type, url, title, created_at, updated_at
            ) VALUES ($1, $2, $3, $4, $5, NOW())
          `,
            [
              profileId,
              mediaType,
              mediaUrl,
              (media.fileName as string) ?? null,
              (media.createdAt as Date) ?? new Date(),
            ],
          );
        }
        synced++;
      } catch (err) {
        failed++;
        if (failed <= 5) {
          console.error(`  Failed ${mongoMediaId}:`, (err as Error).message);
        }
      }
    }

    console.log(`\n=== Results ===`);
    console.log(`Synced: ${synced}`);
    console.log(`Skipped: ${skipped}`);
    console.log(`Failed: ${failed}`);

    if (!dryRun) {
      // Final count
      const finalCount = await pgClient.query(
        'SELECT COUNT(*) FROM profile_media',
      );
      console.log(`\nTotal profile_media: ${finalCount.rows[0].count}`);
    }
  } finally {
    pgClient.release();
    await pool.end();
    await mongoClient.close();
  }
}

main().catch(console.error);

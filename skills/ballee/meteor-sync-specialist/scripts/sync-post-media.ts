#!/usr/bin/env tsx
/**
 * Sync Post Media
 *
 * Syncs media references from MongoDB Posts to Supabase post_media table.
 *
 * PREREQUISITES:
 * - Posts must be synced first (profile_posts table populated)
 * - Organization and dancer media should be synced
 *
 * Usage:
 *   npx tsx sync-post-media.ts
 *   npx tsx sync-post-media.ts --dry-run  # Preview only
 *
 * Last successful run: 2025-12-09
 *   - Media synced: 1,631
 *   - Final post_media count: 1,631
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

  console.log('=== Sync Post Media ===');
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
    // Build mappings
    console.log('Building mappings...');

    // Organization media (for post media references)
    const orgMediaResult = await pgClient.query(`
      SELECT id, mongo_id FROM organization_media WHERE mongo_id IS NOT NULL
    `);
    const orgMediaMap = new Map<string, string>();
    for (const row of orgMediaResult.rows) {
      orgMediaMap.set(row.mongo_id, row.id);
    }
    console.log(`Organization media: ${orgMediaMap.size}`);

    // Dancer media (for post media references)
    const dancerMediaResult = await pgClient.query(`
      SELECT id, meteor_id FROM dancer_media WHERE meteor_id IS NOT NULL
    `);
    const dancerMediaMap = new Map<string, string>();
    for (const row of dancerMediaResult.rows) {
      if (row.meteor_id) dancerMediaMap.set(row.meteor_id, row.id);
    }
    console.log(`Dancer media: ${dancerMediaMap.size}`);

    // Posts already in Supabase (meteor_id -> uuid)
    const postsResult = await pgClient.query(`
      SELECT id, meteor_id FROM profile_posts WHERE meteor_id IS NOT NULL
    `);
    const postMap = new Map<string, string>();
    for (const row of postsResult.rows) {
      postMap.set(row.meteor_id, row.id);
    }
    console.log(`Profile posts: ${postMap.size}`);

    // Get current post_media count
    const currentCount = await pgClient.query(
      'SELECT COUNT(*) FROM post_media',
    );
    console.log(`Current post_media count: ${currentCount.rows[0].count}`);

    // Get MongoDB posts with media
    const mongoPosts = await db
      .collection('Posts')
      .find({
        mediaIds: { $exists: true, $type: 'array', $not: { $size: 0 } },
      })
      .toArray();
    console.log(`\nMongoDB posts with media: ${mongoPosts.length}`);

    let mediaSynced = 0;
    let mediaSkipped = 0;
    let mediaFailed = 0;
    let postsNotFound = 0;

    for (const post of mongoPosts) {
      const postMongoId = (
        post._id as unknown as { toString(): string }
      )?.toString();
      if (!postMongoId) continue;

      // Get Supabase post UUID
      const postUuid = postMap.get(postMongoId);
      if (!postUuid) {
        postsNotFound++;
        continue;
      }

      const mediaIds = post.mediaIds as string[];
      for (let i = 0; i < mediaIds.length; i++) {
        const mediaMongoId = mediaIds[i];

        // Check if already synced
        const existsResult = await pgClient.query(
          'SELECT id FROM post_media WHERE post_id = $1 AND mongo_id = $2',
          [postUuid, mediaMongoId],
        );

        if (existsResult.rows.length > 0) {
          mediaSkipped++;
          continue;
        }

        // Try to find existing media references
        const orgMediaUuid = orgMediaMap.get(mediaMongoId) ?? null;
        const dancerMediaUuid = dancerMediaMap.get(mediaMongoId) ?? null;

        // Get URL from MongoDB if not found
        let mediaUrl: string | null = null;
        if (!orgMediaUuid && !dancerMediaUuid) {
          const mediaDoc = await db
            .collection('Media')
            .findOne({ _id: mediaMongoId });
          if (mediaDoc) {
            const fileObj = mediaDoc.file as { s3Key?: string } | undefined;
            if (fileObj?.s3Key) {
              mediaUrl = `https://s3.${S3_REGION}.amazonaws.com/${S3_BUCKET}/${fileObj.s3Key}`;
            } else if ((mediaDoc as { videoUrl?: string }).videoUrl) {
              mediaUrl = (mediaDoc as { videoUrl: string }).videoUrl;
            }
          }
        }

        try {
          if (!dryRun) {
            await pgClient.query(
              `
              INSERT INTO post_media (
                post_id, organization_media_id, dancer_media_id,
                media_url, mongo_id, display_order, created_at
              ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
            `,
              [
                postUuid,
                orgMediaUuid,
                dancerMediaUuid,
                mediaUrl,
                mediaMongoId,
                i,
              ],
            );
          }
          mediaSynced++;
        } catch (err) {
          mediaFailed++;
          if (mediaFailed <= 5) {
            console.error(
              `  Failed media ${mediaMongoId}:`,
              (err as Error).message,
            );
          }
        }
      }
    }

    console.log(`\n=== Results ===`);
    console.log(`Media synced: ${mediaSynced}`);
    console.log(`Media skipped (already exists): ${mediaSkipped}`);
    console.log(`Media failed: ${mediaFailed}`);
    console.log(`Posts not found in Supabase: ${postsNotFound}`);

    if (!dryRun) {
      // Final count
      const finalCount = await pgClient.query(
        'SELECT COUNT(*) FROM post_media',
      );
      console.log(`\nFinal post_media count: ${finalCount.rows[0].count}`);
    }
  } finally {
    pgClient.release();
    await pool.end();
    await mongoClient.close();
  }
}

main().catch(console.error);

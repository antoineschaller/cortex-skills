# API Patterns

Server-side API patterns for building secure, validated, and type-safe endpoints.

> **Template Usage:** Customize for your framework (Next.js, Express, Fastify, etc.) and validation library (Zod, Yup, etc.).

## Server Action Pattern (Next.js App Router)

```typescript
'use server';

import { z } from 'zod';
import { revalidatePath } from 'next/cache';

// 1. Define validation schema
const CreateItemSchema = z.object({
  name: z.string().min(1).max(100).transform(v => v.trim()),
  email: z.string().email().toLowerCase(),
  amount: z.coerce.number().positive(),
});

// 2. Create typed action with auth
export async function createItemAction(formData: FormData) {
  // Auth check (customize for your auth system)
  const user = await getCurrentUser();
  if (!user) {
    return { success: false, error: 'Unauthorized' };
  }

  // Validate input
  const parsed = CreateItemSchema.safeParse({
    name: formData.get('name'),
    email: formData.get('email'),
    amount: formData.get('amount'),
  });

  if (!parsed.success) {
    return { success: false, error: parsed.error.flatten() };
  }

  try {
    // Business logic
    const result = await createItem(parsed.data);

    // Revalidate affected paths
    revalidatePath('/items');

    return { success: true, data: result };
  } catch (error) {
    console.error('Create item failed:', error);
    return { success: false, error: 'Failed to create item' };
  }
}
```

## Auth Wrapper Pattern

```typescript
// lib/auth-wrappers.ts
import { redirect } from 'next/navigation';

type AuthParams = {
  user: User;
  // Add other common params
};

export function withAuth<T extends any[], R>(
  fn: (params: AuthParams, ...args: T) => Promise<R>
) {
  return async (...args: T): Promise<R> => {
    const user = await getCurrentUser();
    if (!user) {
      redirect('/login');
    }
    return fn({ user }, ...args);
  };
}

// Usage
export const protectedAction = withAuth(async ({ user }, formData: FormData) => {
  // user is guaranteed to exist
  return doSomething(user.id, formData);
});
```

## REST API Pattern (Express/Fastify)

```typescript
// routes/items.ts
import { z } from 'zod';

const CreateItemSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional(),
});

export async function createItem(req: Request, res: Response) {
  // 1. Validate input
  const parsed = CreateItemSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(400).json({
      success: false,
      errors: parsed.error.flatten(),
    });
  }

  // 2. Auth check
  if (!req.user) {
    return res.status(401).json({
      success: false,
      error: 'Unauthorized',
    });
  }

  // 3. Business logic
  try {
    const item = await itemService.create(parsed.data, req.user.id);
    return res.status(201).json({
      success: true,
      data: item,
    });
  } catch (error) {
    console.error('Create item failed:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
}
```

## Cursor-Based Pagination

Cursor-based pagination is more reliable than offset-based for large datasets.

### Schema

```typescript
const PaginationSchema = z.object({
  cursor: z.string().optional(),  // Opaque cursor from previous response
  limit: z.coerce.number().min(1).max(100).default(20),
  direction: z.enum(['forward', 'backward']).default('forward'),
});

type PaginatedResponse<T> = {
  data: T[];
  pageInfo: {
    hasNextPage: boolean;
    hasPreviousPage: boolean;
    startCursor: string | null;
    endCursor: string | null;
    totalCount?: number;  // Optional, can be expensive
  };
};
```

### Implementation

```typescript
// Encode/decode cursor (ID + timestamp for stable ordering)
function encodeCursor(id: string, createdAt: Date): string {
  return Buffer.from(`${id}:${createdAt.toISOString()}`).toString('base64url');
}

function decodeCursor(cursor: string): { id: string; createdAt: Date } {
  const decoded = Buffer.from(cursor, 'base64url').toString();
  const [id, timestamp] = decoded.split(':');
  return { id, createdAt: new Date(timestamp) };
}

// Paginated query
async function getItemsPaginated(
  params: z.infer<typeof PaginationSchema>
): Promise<PaginatedResponse<Item>> {
  const { cursor, limit, direction } = params;

  let query = db.from('items')
    .select('*')
    .order('created_at', { ascending: direction === 'forward' })
    .limit(limit + 1);  // Fetch one extra to check if more exist

  if (cursor) {
    const { id, createdAt } = decodeCursor(cursor);
    const operator = direction === 'forward' ? 'gt' : 'lt';
    query = query.or(`created_at.${operator}.${createdAt.toISOString()},and(created_at.eq.${createdAt.toISOString()},id.${operator}.${id})`);
  }

  const { data: items, error } = await query;

  if (error) throw error;

  const hasMore = items.length > limit;
  const pageItems = hasMore ? items.slice(0, limit) : items;

  return {
    data: pageItems,
    pageInfo: {
      hasNextPage: direction === 'forward' ? hasMore : cursor !== undefined,
      hasPreviousPage: direction === 'backward' ? hasMore : cursor !== undefined,
      startCursor: pageItems[0] ? encodeCursor(pageItems[0].id, pageItems[0].created_at) : null,
      endCursor: pageItems.length ? encodeCursor(pageItems[pageItems.length - 1].id, pageItems[pageItems.length - 1].created_at) : null,
    },
  };
}
```

### Usage in API

```typescript
// GET /api/items?cursor=abc123&limit=20
export async function GET(req: Request) {
  const url = new URL(req.url);
  const params = PaginationSchema.parse({
    cursor: url.searchParams.get('cursor'),
    limit: url.searchParams.get('limit'),
  });

  const result = await getItemsPaginated(params);
  return Response.json(result);
}
```

## API Versioning

### URL Path Versioning (Recommended)

```typescript
// /api/v1/items
// /api/v2/items

// app/api/v1/items/route.ts
export async function GET() {
  return Response.json({ version: 'v1', items: await getItemsV1() });
}

// app/api/v2/items/route.ts
export async function GET() {
  return Response.json({ version: 'v2', items: await getItemsV2() });
}
```

### Header Versioning

```typescript
// Accept: application/vnd.api+json; version=2

export async function GET(req: Request) {
  const accept = req.headers.get('Accept') || '';
  const versionMatch = accept.match(/version=(\d+)/);
  const version = versionMatch ? parseInt(versionMatch[1]) : 1;

  switch (version) {
    case 2:
      return Response.json(await getItemsV2());
    default:
      return Response.json(await getItemsV1());
  }
}
```

### Version Migration Strategy

```typescript
// Gradual migration with deprecation warnings
export async function GET(req: Request) {
  const version = getApiVersion(req);

  if (version === 1) {
    return Response.json(await getItemsV1(), {
      headers: {
        'Deprecation': 'true',
        'Sunset': 'Sat, 31 Dec 2024 23:59:59 GMT',
        'Link': '</api/v2/items>; rel="successor-version"',
      },
    });
  }

  return Response.json(await getItemsV2());
}
```

## Rate Limiting

### Token Bucket Implementation

```typescript
// lib/rate-limiter.ts
interface RateLimitConfig {
  windowMs: number;      // Time window in milliseconds
  maxRequests: number;   // Max requests per window
  keyPrefix?: string;    // Redis key prefix
}

class RateLimiter {
  constructor(
    private redis: Redis,
    private config: RateLimitConfig
  ) {}

  async isAllowed(identifier: string): Promise<{
    allowed: boolean;
    remaining: number;
    resetAt: Date;
  }> {
    const key = `${this.config.keyPrefix || 'ratelimit'}:${identifier}`;
    const now = Date.now();
    const windowStart = now - this.config.windowMs;

    // Remove old entries and count current
    const pipeline = this.redis.pipeline();
    pipeline.zremrangebyscore(key, 0, windowStart);
    pipeline.zcard(key);
    pipeline.zadd(key, now, `${now}-${Math.random()}`);
    pipeline.pexpire(key, this.config.windowMs);

    const results = await pipeline.exec();
    const currentCount = results[1][1] as number;

    const allowed = currentCount < this.config.maxRequests;
    const remaining = Math.max(0, this.config.maxRequests - currentCount - 1);
    const resetAt = new Date(now + this.config.windowMs);

    return { allowed, remaining, resetAt };
  }
}
```

### Middleware

```typescript
// middleware/rate-limit.ts
const rateLimiter = new RateLimiter(redis, {
  windowMs: 60 * 1000,  // 1 minute
  maxRequests: 100,
  keyPrefix: 'api',
});

export async function rateLimitMiddleware(req: Request): Promise<Response | null> {
  // Use IP or user ID as identifier
  const identifier = req.headers.get('x-forwarded-for') || 'anonymous';

  const { allowed, remaining, resetAt } = await rateLimiter.isAllowed(identifier);

  if (!allowed) {
    return new Response(JSON.stringify({
      success: false,
      error: 'Too many requests',
    }), {
      status: 429,
      headers: {
        'Retry-After': Math.ceil((resetAt.getTime() - Date.now()) / 1000).toString(),
        'X-RateLimit-Remaining': '0',
        'X-RateLimit-Reset': resetAt.toISOString(),
      },
    });
  }

  // Add rate limit headers to successful responses
  return null; // Continue processing
}
```

### Tiered Rate Limits

```typescript
const RATE_LIMITS = {
  anonymous: { windowMs: 60000, maxRequests: 20 },
  authenticated: { windowMs: 60000, maxRequests: 100 },
  premium: { windowMs: 60000, maxRequests: 1000 },
} as const;

async function getRateLimitConfig(req: Request): Promise<RateLimitConfig> {
  const user = await getCurrentUser();
  if (!user) return RATE_LIMITS.anonymous;
  if (user.subscription === 'premium') return RATE_LIMITS.premium;
  return RATE_LIMITS.authenticated;
}
```

## Webhook Patterns

### Webhook Delivery

```typescript
// lib/webhooks.ts
interface WebhookPayload {
  event: string;
  data: Record<string, unknown>;
  timestamp: string;
  webhookId: string;
}

async function deliverWebhook(
  endpoint: string,
  secret: string,
  payload: WebhookPayload
): Promise<{ success: boolean; statusCode?: number; error?: string }> {
  const body = JSON.stringify(payload);
  const signature = createHmac('sha256', secret)
    .update(body)
    .digest('hex');

  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Webhook-Signature': `sha256=${signature}`,
        'X-Webhook-Timestamp': payload.timestamp,
        'X-Webhook-ID': payload.webhookId,
      },
      body,
      signal: AbortSignal.timeout(30000),  // 30s timeout
    });

    return {
      success: response.ok,
      statusCode: response.status,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}
```

### Webhook with Retry Queue

```typescript
// Use with background jobs (BullMQ, Inngest, etc.)
interface WebhookJob {
  endpointId: string;
  payload: WebhookPayload;
  attempt: number;
}

async function processWebhookJob(job: WebhookJob): Promise<void> {
  const endpoint = await getWebhookEndpoint(job.endpointId);
  if (!endpoint || !endpoint.active) return;

  const result = await deliverWebhook(endpoint.url, endpoint.secret, job.payload);

  // Log delivery attempt
  await logWebhookDelivery({
    endpointId: job.endpointId,
    webhookId: job.payload.webhookId,
    attempt: job.attempt,
    success: result.success,
    statusCode: result.statusCode,
    error: result.error,
  });

  if (!result.success) {
    // Retry with exponential backoff
    const maxAttempts = 5;
    if (job.attempt < maxAttempts) {
      const delay = Math.pow(2, job.attempt) * 1000;  // 2s, 4s, 8s, 16s, 32s
      await scheduleWebhookRetry({ ...job, attempt: job.attempt + 1 }, delay);
    } else {
      // Max retries reached, notify
      await notifyWebhookFailure(endpoint, job.payload);
    }
  }
}
```

### Webhook Signature Verification (Receiver)

```typescript
// Verify incoming webhook from external service
export async function POST(req: Request) {
  const signature = req.headers.get('x-webhook-signature');
  const timestamp = req.headers.get('x-webhook-timestamp');

  if (!signature || !timestamp) {
    return Response.json({ error: 'Missing signature' }, { status: 401 });
  }

  // Prevent replay attacks
  const timestampAge = Date.now() - new Date(timestamp).getTime();
  if (timestampAge > 5 * 60 * 1000) {  // 5 minutes
    return Response.json({ error: 'Timestamp too old' }, { status: 401 });
  }

  const body = await req.text();
  const expectedSignature = `sha256=${createHmac('sha256', WEBHOOK_SECRET)
    .update(body)
    .digest('hex')}`;

  if (!timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSignature))) {
    return Response.json({ error: 'Invalid signature' }, { status: 401 });
  }

  // Process webhook
  const payload = JSON.parse(body);
  await handleWebhookEvent(payload);

  return Response.json({ received: true });
}
```

## Bulk Operations

### Batch Create

```typescript
const BulkCreateSchema = z.object({
  items: z.array(CreateItemSchema).min(1).max(100),
});

export async function bulkCreateItems(
  items: z.infer<typeof CreateItemSchema>[]
): Promise<{
  success: boolean;
  created: Item[];
  errors: Array<{ index: number; error: string }>;
}> {
  const created: Item[] = [];
  const errors: Array<{ index: number; error: string }> = [];

  // Process in batches to avoid overwhelming the database
  const batchSize = 50;
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);

    try {
      const { data, error } = await db
        .from('items')
        .insert(batch)
        .select();

      if (error) {
        // Mark all items in batch as failed
        batch.forEach((_, idx) => {
          errors.push({ index: i + idx, error: error.message });
        });
      } else {
        created.push(...data);
      }
    } catch (e) {
      batch.forEach((_, idx) => {
        errors.push({ index: i + idx, error: 'Unexpected error' });
      });
    }
  }

  return {
    success: errors.length === 0,
    created,
    errors,
  };
}
```

### Batch Update

```typescript
const BulkUpdateSchema = z.object({
  updates: z.array(z.object({
    id: z.string().uuid(),
    data: UpdateItemSchema.partial(),
  })).min(1).max(100),
});

export async function bulkUpdateItems(
  updates: z.infer<typeof BulkUpdateSchema>['updates']
): Promise<{
  success: boolean;
  updated: number;
  errors: Array<{ id: string; error: string }>;
}> {
  const errors: Array<{ id: string; error: string }> = [];
  let updated = 0;

  // Use transaction for atomicity
  await db.transaction(async (tx) => {
    for (const { id, data } of updates) {
      const { error } = await tx
        .from('items')
        .update(data)
        .eq('id', id);

      if (error) {
        errors.push({ id, error: error.message });
      } else {
        updated++;
      }
    }

    // Rollback if too many errors
    if (errors.length > updates.length * 0.1) {  // > 10% failure rate
      throw new Error('Too many errors, rolling back');
    }
  });

  return { success: errors.length === 0, updated, errors };
}
```

### Batch Delete

```typescript
const BulkDeleteSchema = z.object({
  ids: z.array(z.string().uuid()).min(1).max(100),
});

export async function bulkDeleteItems(
  ids: string[]
): Promise<{
  success: boolean;
  deleted: number;
  notFound: string[];
}> {
  // First, verify all items exist and user has permission
  const { data: existing } = await db
    .from('items')
    .select('id')
    .in('id', ids);

  const existingIds = new Set(existing?.map(i => i.id) || []);
  const notFound = ids.filter(id => !existingIds.has(id));

  // Delete existing items
  const { error, count } = await db
    .from('items')
    .delete()
    .in('id', Array.from(existingIds));

  if (error) {
    throw new Error(`Delete failed: ${error.message}`);
  }

  return {
    success: true,
    deleted: count || 0,
    notFound,
  };
}
```

## Validation Schemas

### Common Patterns

```typescript
import { z } from 'zod';

// String transformations
const nameSchema = z.string()
  .min(1, 'Required')
  .max(100, 'Too long')
  .transform(v => v.trim());

// Email normalization
const emailSchema = z.string()
  .email('Invalid email')
  .toLowerCase();

// Numeric coercion (for form data)
const amountSchema = z.coerce.number()
  .positive('Must be positive');

// Date coercion
const dateSchema = z.coerce.date();

// Optional with default
const statusSchema = z.enum(['active', 'inactive'])
  .default('active');

// Array validation
const tagsSchema = z.array(z.string()).min(1).max(10);

// Nested object
const addressSchema = z.object({
  street: z.string(),
  city: z.string(),
  country: z.string(),
});
```

## Response Types

```typescript
// Consistent response type
type ApiResponse<T> =
  | { success: true; data: T }
  | { success: false; error: string | Record<string, string[]> };

// Usage
function createResponse<T>(data: T): ApiResponse<T> {
  return { success: true, data };
}

function createError(error: string): ApiResponse<never> {
  return { success: false, error };
}
```

## Error Handling

```typescript
// Custom error class
class ApiError extends Error {
  constructor(
    message: string,
    public statusCode: number = 500,
    public code?: string
  ) {
    super(message);
  }
}

// Error handler middleware
function errorHandler(error: Error, req: Request, res: Response) {
  if (error instanceof ApiError) {
    return res.status(error.statusCode).json({
      success: false,
      error: error.message,
      code: error.code,
    });
  }

  console.error('Unhandled error:', error);
  return res.status(500).json({
    success: false,
    error: 'Internal server error',
  });
}
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Pagination returns duplicates | Using offset with concurrent writes | Use cursor-based pagination |
| Rate limit not working | Clock skew between servers | Use Redis MULTI/EXEC for atomic operations |
| Webhook delivery failing | Timeout or retry storm | Add exponential backoff, dead letter queue |
| Bulk operation partial failure | No transaction | Wrap in transaction, implement rollback |
| Version header ignored | Cache not respecting Vary | Add `Vary: Accept` header |

## Checklist

- [ ] Input validated with schema
- [ ] Auth check before business logic
- [ ] Proper error handling
- [ ] Consistent response format
- [ ] Path revalidation after mutations
- [ ] Logging for debugging
- [ ] Rate limiting for public endpoints
- [ ] Pagination for list endpoints
- [ ] API versioning strategy defined
- [ ] Webhook signature verification

## Related Templates

- See `service-patterns` for business logic layer
- See `error-handling` for error boundaries
- See `auth-patterns` for authentication
- See `background-jobs` for webhook delivery queues
- See `caching-patterns` for response caching

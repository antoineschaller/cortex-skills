# Caching Patterns

Caching strategies for web applications including in-memory, Redis, and HTTP caching.

> **Template Usage:** Customize for your cache provider (Redis, Memcached, Upstash) and framework (Next.js, Express, etc.).

## Cache Types

| Type | Use Case | TTL | Example |
|------|----------|-----|---------|
| **In-Memory** | Single instance, fast access | Short (seconds-minutes) | Rate limiting, session |
| **Redis** | Distributed, persistence | Medium (minutes-hours) | User sessions, API responses |
| **HTTP Cache** | Browser/CDN caching | Long (hours-days) | Static assets, public data |
| **Database** | Query caching | Varies | Materialized views |

## In-Memory Cache

### LRU Cache

```typescript
// lib/cache/memory-cache.ts
import { LRUCache } from 'lru-cache';

interface CacheOptions {
  max?: number;
  ttl?: number; // milliseconds
}

export function createMemoryCache<T>(options: CacheOptions = {}) {
  const cache = new LRUCache<string, T>({
    max: options.max || 500,
    ttl: options.ttl || 1000 * 60 * 5, // 5 minutes default
  });

  return {
    get: (key: string): T | undefined => cache.get(key),

    set: (key: string, value: T, ttl?: number): void => {
      cache.set(key, value, { ttl });
    },

    delete: (key: string): boolean => cache.delete(key),

    clear: (): void => cache.clear(),

    has: (key: string): boolean => cache.has(key),

    // Get or set pattern
    async getOrSet(
      key: string,
      fetcher: () => Promise<T>,
      ttl?: number
    ): Promise<T> {
      const cached = cache.get(key);
      if (cached !== undefined) {
        return cached;
      }

      const value = await fetcher();
      cache.set(key, value, { ttl });
      return value;
    },
  };
}

// Usage
const userCache = createMemoryCache<User>({ ttl: 1000 * 60 * 10 }); // 10 min

const user = await userCache.getOrSet(
  `user:${userId}`,
  () => db.user.findUnique({ where: { id: userId } })
);
```

### Map-based Simple Cache

```typescript
// lib/cache/simple-cache.ts
interface CacheEntry<T> {
  value: T;
  expiresAt: number;
}

class SimpleCache<T> {
  private cache = new Map<string, CacheEntry<T>>();
  private defaultTtl: number;

  constructor(defaultTtlMs: number = 60000) {
    this.defaultTtl = defaultTtlMs;

    // Cleanup expired entries every minute
    setInterval(() => this.cleanup(), 60000);
  }

  get(key: string): T | undefined {
    const entry = this.cache.get(key);
    if (!entry) return undefined;

    if (Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      return undefined;
    }

    return entry.value;
  }

  set(key: string, value: T, ttlMs?: number): void {
    this.cache.set(key, {
      value,
      expiresAt: Date.now() + (ttlMs || this.defaultTtl),
    });
  }

  delete(key: string): void {
    this.cache.delete(key);
  }

  private cleanup(): void {
    const now = Date.now();
    for (const [key, entry] of this.cache.entries()) {
      if (now > entry.expiresAt) {
        this.cache.delete(key);
      }
    }
  }
}

export const cache = new SimpleCache(5 * 60 * 1000); // 5 min default
```

## Redis Cache

### Redis Client Setup

```typescript
// lib/cache/redis.ts
import { Redis } from 'ioredis';

const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD,
  retryStrategy: (times) => {
    if (times > 3) return null; // Stop retrying
    return Math.min(times * 100, 3000);
  },
});

redis.on('error', (err) => console.error('Redis error:', err));
redis.on('connect', () => console.log('Redis connected'));

export { redis };
```

### Redis Cache Service

```typescript
// lib/cache/cache-service.ts
import { redis } from './redis';

export const cacheService = {
  async get<T>(key: string): Promise<T | null> {
    const data = await redis.get(key);
    if (!data) return null;
    return JSON.parse(data) as T;
  },

  async set<T>(key: string, value: T, ttlSeconds?: number): Promise<void> {
    const serialized = JSON.stringify(value);
    if (ttlSeconds) {
      await redis.setex(key, ttlSeconds, serialized);
    } else {
      await redis.set(key, serialized);
    }
  },

  async delete(key: string): Promise<void> {
    await redis.del(key);
  },

  async deletePattern(pattern: string): Promise<void> {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
  },

  async getOrSet<T>(
    key: string,
    fetcher: () => Promise<T>,
    ttlSeconds: number = 300
  ): Promise<T> {
    const cached = await this.get<T>(key);
    if (cached !== null) {
      return cached;
    }

    const value = await fetcher();
    await this.set(key, value, ttlSeconds);
    return value;
  },

  // Atomic increment
  async increment(key: string, ttlSeconds?: number): Promise<number> {
    const result = await redis.incr(key);
    if (ttlSeconds && result === 1) {
      await redis.expire(key, ttlSeconds);
    }
    return result;
  },

  // Hash operations
  async hget<T>(key: string, field: string): Promise<T | null> {
    const data = await redis.hget(key, field);
    if (!data) return null;
    return JSON.parse(data) as T;
  },

  async hset<T>(key: string, field: string, value: T): Promise<void> {
    await redis.hset(key, field, JSON.stringify(value));
  },

  async hgetall<T>(key: string): Promise<Record<string, T>> {
    const data = await redis.hgetall(key);
    return Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, JSON.parse(v) as T])
    );
  },
};
```

### Upstash (Serverless Redis)

```typescript
// lib/cache/upstash.ts
import { Redis } from '@upstash/redis';

export const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

// Same interface as ioredis
export const cache = {
  async get<T>(key: string): Promise<T | null> {
    return redis.get<T>(key);
  },

  async set<T>(key: string, value: T, ttlSeconds?: number): Promise<void> {
    if (ttlSeconds) {
      await redis.setex(key, ttlSeconds, value);
    } else {
      await redis.set(key, value);
    }
  },

  async delete(key: string): Promise<void> {
    await redis.del(key);
  },
};
```

## Cache Strategies

### Cache-Aside (Lazy Loading)

```typescript
// Most common pattern - load on demand
async function getUser(id: string): Promise<User> {
  const cacheKey = `user:${id}`;

  // Try cache first
  const cached = await cacheService.get<User>(cacheKey);
  if (cached) {
    return cached;
  }

  // Cache miss - fetch from DB
  const user = await db.user.findUnique({ where: { id } });
  if (!user) {
    throw new NotFoundError('User not found');
  }

  // Store in cache
  await cacheService.set(cacheKey, user, 300); // 5 min TTL

  return user;
}
```

### Write-Through

```typescript
// Update cache when writing to DB
async function updateUser(id: string, data: UpdateUserInput): Promise<User> {
  // Update DB
  const user = await db.user.update({
    where: { id },
    data,
  });

  // Update cache immediately
  await cacheService.set(`user:${id}`, user, 300);

  return user;
}
```

### Write-Behind (Async)

```typescript
// Queue cache updates for batch processing
import { Queue } from 'bullmq';

const cacheQueue = new Queue('cache-updates');

async function updateUserAsync(id: string, data: UpdateUserInput): Promise<User> {
  const user = await db.user.update({
    where: { id },
    data,
  });

  // Queue cache update
  await cacheQueue.add('update-cache', {
    key: `user:${id}`,
    value: user,
    ttl: 300,
  });

  return user;
}
```

### Read-Through

```typescript
// Cache handles fetching automatically
class ReadThroughCache<T> {
  constructor(
    private fetcher: (key: string) => Promise<T>,
    private ttl: number = 300
  ) {}

  async get(key: string): Promise<T> {
    const cached = await cacheService.get<T>(key);
    if (cached !== null) {
      return cached;
    }

    const value = await this.fetcher(key);
    await cacheService.set(key, value, this.ttl);
    return value;
  }
}

// Usage
const userCache = new ReadThroughCache<User>(
  (id) => db.user.findUniqueOrThrow({ where: { id } }),
  300
);

const user = await userCache.get(userId);
```

## Cache Invalidation

### Tag-Based Invalidation

```typescript
// lib/cache/tagged-cache.ts
export const taggedCache = {
  async set<T>(
    key: string,
    value: T,
    tags: string[],
    ttl: number
  ): Promise<void> {
    // Store value
    await cacheService.set(key, value, ttl);

    // Associate key with tags
    for (const tag of tags) {
      await redis.sadd(`tag:${tag}`, key);
    }
  },

  async invalidateTag(tag: string): Promise<void> {
    const keys = await redis.smembers(`tag:${tag}`);
    if (keys.length > 0) {
      await redis.del(...keys);
      await redis.del(`tag:${tag}`);
    }
  },
};

// Usage
await taggedCache.set(
  `user:${userId}`,
  user,
  ['users', `account:${user.accountId}`],
  300
);

// Invalidate all users
await taggedCache.invalidateTag('users');

// Invalidate specific account's users
await taggedCache.invalidateTag(`account:${accountId}`);
```

### Event-Based Invalidation

```typescript
// lib/cache/invalidation.ts
type CacheEvent =
  | { type: 'user.updated'; userId: string }
  | { type: 'user.deleted'; userId: string }
  | { type: 'account.updated'; accountId: string };

export async function handleCacheInvalidation(event: CacheEvent): Promise<void> {
  switch (event.type) {
    case 'user.updated':
    case 'user.deleted':
      await cacheService.delete(`user:${event.userId}`);
      break;

    case 'account.updated':
      await cacheService.deletePattern(`account:${event.accountId}:*`);
      break;
  }
}

// Emit events after DB operations
async function updateUser(id: string, data: UpdateUserInput): Promise<User> {
  const user = await db.user.update({ where: { id }, data });

  await handleCacheInvalidation({ type: 'user.updated', userId: id });

  return user;
}
```

## HTTP Caching

### Next.js Cache Headers

```typescript
// app/api/products/route.ts
export async function GET() {
  const products = await getProducts();

  return Response.json(products, {
    headers: {
      // Cache for 1 hour, stale-while-revalidate for 1 day
      'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=86400',
    },
  });
}

// Revalidation
export const revalidate = 3600; // Revalidate every hour
```

### Next.js `unstable_cache`

```typescript
import { unstable_cache } from 'next/cache';

const getCachedProducts = unstable_cache(
  async () => {
    return db.product.findMany({
      where: { isActive: true },
    });
  },
  ['products'], // Cache key
  {
    revalidate: 3600, // 1 hour
    tags: ['products'],
  }
);

// Usage in Server Component
export default async function ProductsPage() {
  const products = await getCachedProducts();
  return <ProductGrid products={products} />;
}

// Invalidate
import { revalidateTag } from 'next/cache';
revalidateTag('products');
```

### React Query (Client-Side)

```typescript
// hooks/use-products.ts
import { useQuery, useQueryClient } from '@tanstack/react-query';

export function useProducts() {
  return useQuery({
    queryKey: ['products'],
    queryFn: () => fetch('/api/products').then(r => r.json()),
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 30 * 60 * 1000, // 30 minutes (formerly cacheTime)
  });
}

// Prefetching
export function usePrefetchProducts() {
  const queryClient = useQueryClient();

  return () => {
    queryClient.prefetchQuery({
      queryKey: ['products'],
      queryFn: () => fetch('/api/products').then(r => r.json()),
    });
  };
}

// Invalidation
export function useInvalidateProducts() {
  const queryClient = useQueryClient();

  return () => {
    queryClient.invalidateQueries({ queryKey: ['products'] });
  };
}
```

## Rate Limiting with Cache

```typescript
// lib/rate-limit.ts
import { redis } from './cache/redis';

interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
}

export async function checkRateLimit(
  key: string,
  limit: number,
  windowSeconds: number
): Promise<RateLimitResult> {
  const now = Math.floor(Date.now() / 1000);
  const windowKey = `ratelimit:${key}:${Math.floor(now / windowSeconds)}`;

  const current = await redis.incr(windowKey);

  if (current === 1) {
    await redis.expire(windowKey, windowSeconds);
  }

  const resetAt = new Date(
    (Math.floor(now / windowSeconds) + 1) * windowSeconds * 1000
  );

  return {
    allowed: current <= limit,
    remaining: Math.max(0, limit - current),
    resetAt,
  };
}

// Middleware
export async function rateLimitMiddleware(
  req: Request,
  identifier: string,
  limit: number = 100,
  windowSeconds: number = 60
) {
  const result = await checkRateLimit(identifier, limit, windowSeconds);

  if (!result.allowed) {
    return new Response('Too Many Requests', {
      status: 429,
      headers: {
        'X-RateLimit-Limit': limit.toString(),
        'X-RateLimit-Remaining': result.remaining.toString(),
        'X-RateLimit-Reset': result.resetAt.toISOString(),
        'Retry-After': Math.ceil((result.resetAt.getTime() - Date.now()) / 1000).toString(),
      },
    });
  }

  return null; // Allowed
}
```

## Cache Key Patterns

```typescript
// lib/cache/keys.ts
export const cacheKeys = {
  // User
  user: (id: string) => `user:${id}`,
  userByEmail: (email: string) => `user:email:${email}`,
  userSessions: (id: string) => `user:${id}:sessions`,

  // Products
  product: (id: string) => `product:${id}`,
  productsByCategory: (categoryId: string) => `products:category:${categoryId}`,
  productSearch: (query: string, page: number) =>
    `products:search:${query}:page:${page}`,

  // Lists with pagination
  list: (entity: string, filters: object, page: number) =>
    `${entity}:list:${JSON.stringify(filters)}:page:${page}`,

  // Computed/aggregated
  userStats: (id: string) => `user:${id}:stats`,
  dashboardMetrics: (accountId: string) => `dashboard:${accountId}:metrics`,
};

// Usage
await cacheService.set(cacheKeys.user(userId), user, 300);
await cacheService.get(cacheKeys.productsByCategory(categoryId));
```

## Monitoring Cache Performance

```typescript
// lib/cache/instrumented-cache.ts
import { createLogger } from '@/lib/logger';

const logger = createLogger('cache');

export function createInstrumentedCache<T>(cache: CacheService) {
  let hits = 0;
  let misses = 0;

  return {
    async get(key: string): Promise<T | null> {
      const start = Date.now();
      const value = await cache.get<T>(key);
      const duration = Date.now() - start;

      if (value !== null) {
        hits++;
        logger.debug('Cache hit', { key, duration });
      } else {
        misses++;
        logger.debug('Cache miss', { key, duration });
      }

      return value;
    },

    async set(key: string, value: T, ttl?: number): Promise<void> {
      const start = Date.now();
      await cache.set(key, value, ttl);
      logger.debug('Cache set', { key, ttl, duration: Date.now() - start });
    },

    getStats() {
      const total = hits + misses;
      return {
        hits,
        misses,
        hitRate: total > 0 ? (hits / total) * 100 : 0,
      };
    },
  };
}
```

## Checklist

### Strategy
- [ ] Appropriate cache type for use case
- [ ] TTL values aligned with data freshness needs
- [ ] Invalidation strategy defined
- [ ] Cache key naming convention

### Implementation
- [ ] Cache-aside for read-heavy data
- [ ] Write-through for consistency
- [ ] Tag-based invalidation for related data
- [ ] Rate limiting with cache

### Performance
- [ ] Cache hit rate monitored
- [ ] Slow cache operations logged
- [ ] Memory usage tracked
- [ ] Connection pooling configured

### Reliability
- [ ] Graceful degradation on cache failure
- [ ] Cache warming on startup (if needed)
- [ ] Distributed cache for multi-instance
- [ ] No sensitive data cached (or encrypted)

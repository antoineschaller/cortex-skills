# Production Readiness Patterns

Patterns for deploying and operating applications in production with confidence.

> **Template Usage:** Customize health checks, monitoring, and runbooks for your infrastructure (Kubernetes, Vercel, AWS, etc.).

## Health Check Endpoints

### Basic Health Check

```typescript
// app/api/health/route.ts
import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json(
    {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.APP_VERSION || 'unknown',
    },
    { status: 200 }
  );
}
```

### Comprehensive Health Check

```typescript
// app/api/health/route.ts
import { NextResponse } from 'next/server';

interface HealthCheck {
  name: string;
  status: 'healthy' | 'degraded' | 'unhealthy';
  latencyMs?: number;
  message?: string;
}

async function checkDatabase(): Promise<HealthCheck> {
  const start = Date.now();
  try {
    await db.$queryRaw`SELECT 1`;
    return {
      name: 'database',
      status: 'healthy',
      latencyMs: Date.now() - start,
    };
  } catch (error) {
    return {
      name: 'database',
      status: 'unhealthy',
      message: error instanceof Error ? error.message : 'Unknown error',
      latencyMs: Date.now() - start,
    };
  }
}

async function checkRedis(): Promise<HealthCheck> {
  const start = Date.now();
  try {
    await redis.ping();
    return {
      name: 'redis',
      status: 'healthy',
      latencyMs: Date.now() - start,
    };
  } catch (error) {
    return {
      name: 'redis',
      status: 'unhealthy',
      message: error instanceof Error ? error.message : 'Unknown error',
      latencyMs: Date.now() - start,
    };
  }
}

async function checkExternalAPI(): Promise<HealthCheck> {
  const start = Date.now();
  try {
    const response = await fetch(process.env.EXTERNAL_API_URL + '/health', {
      signal: AbortSignal.timeout(5000),
    });
    return {
      name: 'external_api',
      status: response.ok ? 'healthy' : 'degraded',
      latencyMs: Date.now() - start,
    };
  } catch (error) {
    return {
      name: 'external_api',
      status: 'degraded', // External API failure is degraded, not unhealthy
      message: 'External API unreachable',
      latencyMs: Date.now() - start,
    };
  }
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const deep = url.searchParams.get('deep') === 'true';

  // Basic health check (for load balancers)
  if (!deep) {
    return NextResponse.json({ status: 'healthy' });
  }

  // Deep health check (for monitoring)
  const checks = await Promise.all([
    checkDatabase(),
    checkRedis(),
    checkExternalAPI(),
  ]);

  const overallStatus = checks.some((c) => c.status === 'unhealthy')
    ? 'unhealthy'
    : checks.some((c) => c.status === 'degraded')
      ? 'degraded'
      : 'healthy';

  const statusCode = overallStatus === 'unhealthy' ? 503 : 200;

  return NextResponse.json(
    {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      version: process.env.APP_VERSION,
      environment: process.env.NODE_ENV,
      checks,
    },
    { status: statusCode }
  );
}
```

### Kubernetes Probes

```typescript
// app/api/health/live/route.ts
// Liveness probe - is the app running?
export async function GET() {
  return new Response('OK', { status: 200 });
}

// app/api/health/ready/route.ts
// Readiness probe - can the app serve traffic?
export async function GET() {
  try {
    // Check critical dependencies
    await db.$queryRaw`SELECT 1`;
    return new Response('OK', { status: 200 });
  } catch {
    return new Response('Not Ready', { status: 503 });
  }
}

// app/api/health/startup/route.ts
// Startup probe - has the app finished initializing?
export async function GET() {
  if (!global.isInitialized) {
    return new Response('Starting', { status: 503 });
  }
  return new Response('OK', { status: 200 });
}
```

## Graceful Shutdown

### Node.js Server

```typescript
// server.ts
import { createServer } from 'http';

const server = createServer(app);
let isShuttingDown = false;

// Track active connections
const connections = new Set<Socket>();
server.on('connection', (socket) => {
  connections.add(socket);
  socket.on('close', () => connections.delete(socket));
});

async function gracefulShutdown(signal: string) {
  console.log(`Received ${signal}, starting graceful shutdown...`);
  isShuttingDown = true;

  // Stop accepting new connections
  server.close(() => {
    console.log('HTTP server closed');
  });

  // Close existing connections with grace period
  const forceCloseTimeout = setTimeout(() => {
    console.log('Force closing remaining connections');
    connections.forEach((socket) => socket.destroy());
  }, 30000); // 30 second grace period

  // Close database connections
  try {
    await db.$disconnect();
    console.log('Database disconnected');
  } catch (error) {
    console.error('Error disconnecting database:', error);
  }

  // Close Redis connections
  try {
    await redis.quit();
    console.log('Redis disconnected');
  } catch (error) {
    console.error('Error disconnecting Redis:', error);
  }

  // Clear force close timeout if all connections closed
  clearTimeout(forceCloseTimeout);

  console.log('Graceful shutdown complete');
  process.exit(0);
}

// Handle shutdown signals
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Middleware to reject requests during shutdown
app.use((req, res, next) => {
  if (isShuttingDown) {
    res.set('Connection', 'close');
    return res.status(503).json({ error: 'Server is shutting down' });
  }
  next();
});
```

### Next.js Graceful Shutdown

```typescript
// instrumentation.ts (Next.js 13+)
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const cleanup = async () => {
      console.log('Cleaning up before shutdown...');

      // Flush any pending analytics
      await analytics.flush();

      // Close database connection pool
      const { db } = await import('@/lib/db');
      await db.$disconnect();

      console.log('Cleanup complete');
    };

    process.on('SIGTERM', async () => {
      await cleanup();
      process.exit(0);
    });

    process.on('SIGINT', async () => {
      await cleanup();
      process.exit(0);
    });
  }
}
```

## Environment Variable Validation

### Zod Schema Validation

```typescript
// lib/env.ts
import { z } from 'zod';

const envSchema = z.object({
  // Required
  NODE_ENV: z.enum(['development', 'test', 'staging', 'production']),
  DATABASE_URL: z.string().url(),
  NEXTAUTH_SECRET: z.string().min(32),
  NEXTAUTH_URL: z.string().url(),

  // Required in production only
  SENTRY_DSN: z.string().url().optional(),
  REDIS_URL: z.string().url().optional(),

  // Optional with defaults
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  PORT: z.coerce.number().default(3000),

  // Feature flags
  FEATURE_NEW_CHECKOUT: z.coerce.boolean().default(false),
  FEATURE_DARK_MODE: z.coerce.boolean().default(true),
});

// Validate at startup
function validateEnv() {
  const parsed = envSchema.safeParse(process.env);

  if (!parsed.success) {
    console.error('Invalid environment variables:');
    console.error(parsed.error.flatten().fieldErrors);
    process.exit(1);
  }

  // Production-only requirements
  if (parsed.data.NODE_ENV === 'production') {
    if (!parsed.data.SENTRY_DSN) {
      console.error('SENTRY_DSN is required in production');
      process.exit(1);
    }
  }

  return parsed.data;
}

export const env = validateEnv();

// Type-safe access
declare global {
  namespace NodeJS {
    interface ProcessEnv extends z.infer<typeof envSchema> {}
  }
}
```

### Runtime Validation

```typescript
// lib/config.ts
interface AppConfig {
  database: {
    url: string;
    poolSize: number;
  };
  auth: {
    secret: string;
    sessionTtl: number;
  };
  features: {
    newCheckout: boolean;
    darkMode: boolean;
  };
}

function loadConfig(): AppConfig {
  const requiredVars = [
    'DATABASE_URL',
    'NEXTAUTH_SECRET',
  ];

  const missing = requiredVars.filter((v) => !process.env[v]);
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  return {
    database: {
      url: process.env.DATABASE_URL!,
      poolSize: parseInt(process.env.DB_POOL_SIZE || '10', 10),
    },
    auth: {
      secret: process.env.NEXTAUTH_SECRET!,
      sessionTtl: parseInt(process.env.SESSION_TTL || '86400', 10),
    },
    features: {
      newCheckout: process.env.FEATURE_NEW_CHECKOUT === 'true',
      darkMode: process.env.FEATURE_DARK_MODE !== 'false',
    },
  };
}

export const config = loadConfig();
```

## Feature Flags

### Simple Feature Flags

```typescript
// lib/features.ts
interface FeatureFlags {
  newCheckout: boolean;
  darkMode: boolean;
  betaFeatures: boolean;
  maintenanceMode: boolean;
}

// Load from environment
export const features: FeatureFlags = {
  newCheckout: process.env.FEATURE_NEW_CHECKOUT === 'true',
  darkMode: process.env.FEATURE_DARK_MODE !== 'false',
  betaFeatures: process.env.FEATURE_BETA === 'true',
  maintenanceMode: process.env.MAINTENANCE_MODE === 'true',
};

// Usage
if (features.newCheckout) {
  return <NewCheckout />;
}
return <LegacyCheckout />;
```

### User-Targeted Feature Flags

```typescript
// lib/features.ts
interface FeatureFlag {
  enabled: boolean;
  rolloutPercentage?: number;
  allowedUserIds?: string[];
  allowedRoles?: string[];
}

const featureFlags: Record<string, FeatureFlag> = {
  new_dashboard: {
    enabled: true,
    rolloutPercentage: 25, // 25% of users
  },
  admin_v2: {
    enabled: true,
    allowedRoles: ['admin', 'super_admin'],
  },
  beta_features: {
    enabled: true,
    allowedUserIds: ['user-123', 'user-456'], // Beta testers
  },
};

export function isFeatureEnabled(
  featureName: string,
  user?: { id: string; role: string }
): boolean {
  const flag = featureFlags[featureName];

  if (!flag || !flag.enabled) return false;

  // Check user-specific allowlist
  if (flag.allowedUserIds?.includes(user?.id ?? '')) return true;

  // Check role-based access
  if (flag.allowedRoles?.includes(user?.role ?? '')) return true;

  // Check percentage rollout
  if (flag.rolloutPercentage !== undefined && user) {
    const hash = hashString(user.id + featureName);
    return (hash % 100) < flag.rolloutPercentage;
  }

  // Default to enabled if no conditions specified
  return flag.enabled && !flag.rolloutPercentage && !flag.allowedUserIds && !flag.allowedRoles;
}

function hashString(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash = hash & hash;
  }
  return Math.abs(hash);
}
```

### Feature Flag Component

```tsx
// components/feature-flag.tsx
'use client';

import { useUser } from '@/hooks/use-user';
import { isFeatureEnabled } from '@/lib/features';

interface FeatureFlagProps {
  name: string;
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export function FeatureFlag({ name, children, fallback = null }: FeatureFlagProps) {
  const user = useUser();

  if (!isFeatureEnabled(name, user)) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
}

// Usage
<FeatureFlag name="new_dashboard" fallback={<LegacyDashboard />}>
  <NewDashboard />
</FeatureFlag>
```

## Monitoring & Alerting

### Structured Logging

```typescript
// lib/logger.ts
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  base: {
    service: 'my-app',
    version: process.env.APP_VERSION,
    environment: process.env.NODE_ENV,
  },
  redact: ['password', 'token', 'authorization', '*.password', '*.token'],
});

// Create child loggers for different modules
export const dbLogger = logger.child({ module: 'database' });
export const authLogger = logger.child({ module: 'auth' });
export const apiLogger = logger.child({ module: 'api' });
```

### Error Tracking (Sentry)

```typescript
// lib/sentry.ts
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.APP_VERSION,

  // Performance monitoring
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,

  // Session replay
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,

  // Filter out noise
  ignoreErrors: [
    'ResizeObserver loop limit exceeded',
    'Non-Error promise rejection captured',
    /^Network request failed$/,
  ],

  beforeSend(event, hint) {
    // Don't send errors in development
    if (process.env.NODE_ENV === 'development') {
      return null;
    }

    // Add extra context
    event.tags = {
      ...event.tags,
      server_region: process.env.VERCEL_REGION,
    };

    return event;
  },
});

// Helper to capture errors with context
export function captureError(error: Error, context?: Record<string, unknown>) {
  Sentry.withScope((scope) => {
    if (context) {
      scope.setExtras(context);
    }
    Sentry.captureException(error);
  });
}
```

### Metrics Collection

```typescript
// lib/metrics.ts
import { Counter, Histogram, Gauge, Registry } from 'prom-client';

export const registry = new Registry();

// Request metrics
export const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [registry],
});

export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'path', 'status'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [registry],
});

// Business metrics
export const activeUsers = new Gauge({
  name: 'active_users',
  help: 'Number of active users',
  registers: [registry],
});

export const ordersTotal = new Counter({
  name: 'orders_total',
  help: 'Total orders placed',
  labelNames: ['status'],
  registers: [registry],
});

// Database metrics
export const dbQueryDuration = new Histogram({
  name: 'db_query_duration_seconds',
  help: 'Database query duration',
  labelNames: ['operation', 'table'],
  buckets: [0.001, 0.01, 0.1, 0.5, 1, 5],
  registers: [registry],
});

// Expose metrics endpoint
// app/api/metrics/route.ts
export async function GET() {
  const metrics = await registry.metrics();
  return new Response(metrics, {
    headers: { 'Content-Type': registry.contentType },
  });
}
```

### Alert Rules (Example: Prometheus)

```yaml
# alerts.yml
groups:
  - name: app-alerts
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }}"

      # Slow response time
      - alert: SlowResponseTime
        expr: |
          histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
          > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Slow response times"
          description: "P95 latency is {{ $value | humanizeDuration }}"

      # Database connection issues
      - alert: DatabaseUnhealthy
        expr: up{job="database"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database is down"
          description: "Database health check failing"

      # High memory usage
      - alert: HighMemoryUsage
        expr: |
          process_resident_memory_bytes / (1024 * 1024 * 1024) > 1.5
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value | humanize }}GB"
```

## Incident Response

### Incident Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| P1 - Critical | Service down, data loss | Immediate | Database down, auth broken |
| P2 - High | Major feature broken | 30 minutes | Payments failing, signup broken |
| P3 - Medium | Feature degraded | 4 hours | Slow queries, partial outage |
| P4 - Low | Minor issue | 24 hours | UI bug, non-critical error |

### Incident Response Checklist

```markdown
## Incident Response Checklist

### 1. Acknowledge (0-5 minutes)
- [ ] Acknowledge alert in monitoring system
- [ ] Join incident channel (#incident-YYYY-MM-DD)
- [ ] Assign incident commander
- [ ] Start incident timeline document

### 2. Assess (5-15 minutes)
- [ ] Identify scope of impact (users, regions, features)
- [ ] Determine severity level (P1-P4)
- [ ] Check recent deployments: `git log --oneline -10`
- [ ] Check for external dependencies status
- [ ] Update status page if customer-facing

### 3. Mitigate (15-60 minutes)
- [ ] Implement immediate fix or workaround
  - Rollback: `vercel rollback` or `git revert && deploy`
  - Feature flag: Disable problematic feature
  - Scale: Increase resources if capacity issue
- [ ] Verify mitigation is effective
- [ ] Communicate status to stakeholders

### 4. Resolve (varies)
- [ ] Implement permanent fix
- [ ] Deploy fix with proper review
- [ ] Verify fix in production
- [ ] Close incident

### 5. Post-Incident (within 48 hours)
- [ ] Write incident report
- [ ] Schedule post-mortem meeting
- [ ] Create follow-up action items
- [ ] Update runbooks if needed
```

### On-Call Runbook Template

```markdown
# Runbook: [Service/Alert Name]

## Overview
Brief description of what this alert means and its impact.

## Alert Conditions
- **Metric**: `http_error_rate > 5%`
- **Duration**: 5 minutes
- **Severity**: P2

## Impact
- Users affected: All users making API requests
- Revenue impact: Direct - payment processing affected

## Quick Diagnosis

### 1. Check Service Health
\`\`\`bash
curl https://api.example.com/health?deep=true | jq
\`\`\`

### 2. Check Recent Deployments
\`\`\`bash
vercel ls --limit 5
git log --oneline --since="1 hour ago"
\`\`\`

### 3. Check Error Logs
\`\`\`bash
# Vercel
vercel logs --since 1h | grep ERROR

# Sentry
# Check https://sentry.io/organizations/[org]/issues/
\`\`\`

### 4. Check Dependencies
- Database: Check Supabase dashboard
- Redis: Check Redis Cloud dashboard
- External APIs: Check status pages

## Common Causes & Fixes

### Cause 1: Recent deployment broke something
**Fix**: Rollback to previous deployment
\`\`\`bash
vercel rollback
\`\`\`

### Cause 2: Database connection pool exhausted
**Fix**: Restart pods or increase pool size
\`\`\`bash
# Check active connections
psql $DATABASE_URL -c "SELECT count(*) FROM pg_stat_activity;"
\`\`\`

### Cause 3: External API rate limited
**Fix**: Enable circuit breaker or reduce request rate
\`\`\`typescript
// Enable circuit breaker for external API
await setFeatureFlag('external_api_circuit_breaker', true);
\`\`\`

### Cause 4: High traffic spike
**Fix**: Scale up or enable rate limiting
\`\`\`bash
# Enable stricter rate limiting
vercel env add RATE_LIMIT_REQUESTS_PER_MINUTE 30
\`\`\`

## Escalation
If unable to resolve within 30 minutes:
1. Page on-call engineer: `pd trigger --escalation-policy "engineering"`
2. Notify #engineering-urgent channel
3. Contact: @tech-lead (primary), @cto (secondary)

## References
- Architecture diagram: [Link]
- Previous incidents: [INC-123], [INC-456]
- Related alerts: [Alert Name 2]
```

## Deployment Checklist

### Pre-Deployment

```markdown
## Pre-Deployment Checklist

### Code Quality
- [ ] All tests passing locally
- [ ] TypeScript compiles without errors
- [ ] Linting passes
- [ ] No console.log/debugger statements

### Database
- [ ] Migrations are idempotent
- [ ] Migrations tested on staging
- [ ] Rollback strategy documented
- [ ] No breaking schema changes (or migration plan exists)

### Configuration
- [ ] Environment variables documented
- [ ] New env vars added to all environments
- [ ] Feature flags configured correctly

### Dependencies
- [ ] No security vulnerabilities (npm audit)
- [ ] No breaking changes in dependencies
- [ ] Lock file updated

### Monitoring
- [ ] New errors have Sentry fingerprints
- [ ] Alerts configured for new features
- [ ] Logging added for new code paths
```

### Post-Deployment

```markdown
## Post-Deployment Checklist

### Immediate (0-5 minutes)
- [ ] Deployment succeeded
- [ ] Health check passing
- [ ] No new errors in Sentry
- [ ] Critical user flows working

### Short-term (5-30 minutes)
- [ ] Error rate stable
- [ ] Response times normal
- [ ] No customer complaints
- [ ] Database metrics stable

### Follow-up (1-24 hours)
- [ ] Monitor for delayed issues
- [ ] Check scheduled jobs ran correctly
- [ ] Review any new errors
- [ ] Clean up feature flags if needed
```

## Troubleshooting

### Common Production Issues

| Issue | Symptoms | Quick Fix |
|-------|----------|-----------|
| Memory leak | Increasing memory, eventual crash | Restart pods, investigate heap |
| Connection pool exhaustion | Database timeout errors | Reduce pool size, check for leaks |
| Rate limiting | 429 errors, slow responses | Implement backoff, cache requests |
| SSL certificate expiry | HTTPS errors | Renew certificate |
| Disk full | Write errors, service down | Clear logs, increase storage |

### Debug Commands

```bash
# Check service health
curl https://api.example.com/health?deep=true | jq

# Check recent errors (Vercel)
vercel logs --since 1h | grep -i error

# Check deployment status
vercel ls --limit 10

# Check database connections
psql $DATABASE_URL -c "SELECT count(*) FROM pg_stat_activity;"

# Check memory usage (Kubernetes)
kubectl top pods -n production

# Check recent deployments (Git)
git log --oneline --since="2 hours ago"

# Rollback deployment
vercel rollback [deployment-id]
```

## Related Templates

- See `logging-patterns` for structured logging
- See `error-handling` for error management
- See `cicd-patterns` for deployment automation
- See `caching-patterns` for performance optimization

## Checklist

### Health Checks
- [ ] Basic health endpoint (`/health`)
- [ ] Deep health check with dependencies (`/health?deep=true`)
- [ ] Kubernetes probes (liveness, readiness, startup)

### Graceful Shutdown
- [ ] SIGTERM handler implemented
- [ ] Connection draining
- [ ] Database disconnect on shutdown
- [ ] Grace period before force close

### Configuration
- [ ] Environment variables validated at startup
- [ ] Type-safe config access
- [ ] Production-specific requirements enforced

### Feature Flags
- [ ] Feature flag system implemented
- [ ] Percentage rollout capability
- [ ] User targeting capability
- [ ] Quick disable mechanism

### Monitoring
- [ ] Structured logging configured
- [ ] Error tracking (Sentry) configured
- [ ] Metrics collection enabled
- [ ] Alerts defined for critical metrics

### Incident Response
- [ ] Severity levels defined
- [ ] Response procedures documented
- [ ] On-call runbooks created
- [ ] Escalation paths defined

### Deployment
- [ ] Pre-deployment checklist
- [ ] Post-deployment verification
- [ ] Rollback procedure tested
- [ ] Canary/staged deployments

## Rules

1. **Health First**: Every service needs health checks - no exceptions
2. **Graceful Shutdown**: Always handle SIGTERM to prevent data loss
3. **Validate Early**: Check environment variables at startup, not runtime
4. **Feature Flags for Risk**: New features should be flag-guarded in production
5. **Monitor Everything**: If you can't measure it, you can't improve it
6. **Document Runbooks**: Every alert needs a corresponding runbook
7. **Test Rollbacks**: Practice rollback procedures before you need them

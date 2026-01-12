---
name: production-readiness
description: Production readiness patterns for Ballee including health checks, feature flags, graceful shutdown, monitoring, and incident response. Use when deploying features, setting up monitoring, or handling incidents.
tools: Read, Glob, Grep, Bash
---

# Production Readiness Patterns

Patterns for deploying and operating Ballee in production with Vercel, Supabase, and Sentry.

## Quick Reference

```typescript
// Health check endpoint
// app/api/health/route.ts
export async function GET(request: Request) {
  const url = new URL(request.url);
  const deep = url.searchParams.get('deep') === 'true';

  if (!deep) return Response.json({ status: 'healthy' });

  const checks = await Promise.all([
    checkSupabase(),
    checkSentry(),
  ]);

  const overallStatus = checks.some(c => c.status === 'unhealthy')
    ? 'unhealthy'
    : checks.some(c => c.status === 'degraded')
      ? 'degraded'
      : 'healthy';

  return Response.json({ status: overallStatus, checks }, {
    status: overallStatus === 'unhealthy' ? 503 : 200
  });
}
```

## When to Use

- Setting up health check endpoints for monitoring
- Implementing feature flags for gradual rollouts
- Configuring graceful shutdown for background tasks
- Setting up alerts and incident response procedures
- Before major deployments or feature launches

## Health Check Endpoints

### Basic Health Check

```typescript
// app/api/health/route.ts
import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7) || 'local',
    environment: process.env.VERCEL_ENV || 'development',
  });
}
```

### Deep Health Check with Supabase

```typescript
// app/api/health/route.ts
import { createClient } from '@supabase/supabase-js';

interface HealthCheck {
  name: string;
  status: 'healthy' | 'degraded' | 'unhealthy';
  latencyMs?: number;
  message?: string;
}

async function checkSupabase(): Promise<HealthCheck> {
  const start = Date.now();
  try {
    const client = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    // Simple query to verify connection
    const { error } = await client.from('accounts').select('id').limit(1);

    if (error) throw error;

    return {
      name: 'supabase',
      status: 'healthy',
      latencyMs: Date.now() - start,
    };
  } catch (error) {
    return {
      name: 'supabase',
      status: 'unhealthy',
      message: error instanceof Error ? error.message : 'Unknown error',
      latencyMs: Date.now() - start,
    };
  }
}

async function checkSentry(): Promise<HealthCheck> {
  // Sentry doesn't need health checks - just verify DSN is configured
  const hasDsn = !!process.env.SENTRY_DSN || !!process.env.NEXT_PUBLIC_SENTRY_DSN;
  return {
    name: 'sentry',
    status: hasDsn ? 'healthy' : 'degraded',
    message: hasDsn ? undefined : 'Sentry DSN not configured',
  };
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const deep = url.searchParams.get('deep') === 'true';

  // Basic health check (fast, for load balancers)
  if (!deep) {
    return NextResponse.json({ status: 'healthy' });
  }

  // Deep health check (for monitoring dashboards)
  const checks = await Promise.all([
    checkSupabase(),
    checkSentry(),
  ]);

  const overallStatus = checks.some(c => c.status === 'unhealthy')
    ? 'unhealthy'
    : checks.some(c => c.status === 'degraded')
      ? 'degraded'
      : 'healthy';

  return NextResponse.json(
    {
      status: overallStatus,
      timestamp: new Date().toISOString(),
      version: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 7),
      environment: process.env.VERCEL_ENV,
      region: process.env.VERCEL_REGION,
      checks,
    },
    { status: overallStatus === 'unhealthy' ? 503 : 200 }
  );
}
```

## Feature Flags

### Environment-Based Feature Flags

```typescript
// lib/features.ts
interface FeatureFlags {
  newDashboard: boolean;
  feverSync: boolean;
  tipaltiPayments: boolean;
  maintenanceMode: boolean;
}

export const features: FeatureFlags = {
  newDashboard: process.env.FEATURE_NEW_DASHBOARD === 'true',
  feverSync: process.env.FEATURE_FEVER_SYNC !== 'false', // Default enabled
  tipaltiPayments: process.env.FEATURE_TIPALTI === 'true',
  maintenanceMode: process.env.MAINTENANCE_MODE === 'true',
};

// Usage
if (features.maintenanceMode) {
  return <MaintenancePage />;
}
```

### User-Targeted Feature Flags

```typescript
// lib/features.ts
interface FeatureFlag {
  enabled: boolean;
  rolloutPercentage?: number;
  allowedAccountIds?: string[];
  allowedRoles?: string[];
}

const featureFlags: Record<string, FeatureFlag> = {
  new_event_editor: {
    enabled: true,
    rolloutPercentage: 25, // 25% of users
  },
  admin_analytics_v2: {
    enabled: true,
    allowedRoles: ['owner', 'admin'],
  },
  beta_features: {
    enabled: true,
    allowedAccountIds: ['acct_xxx', 'acct_yyy'], // Beta testers
  },
};

export function isFeatureEnabled(
  featureName: string,
  context?: { accountId: string; role: string }
): boolean {
  const flag = featureFlags[featureName];
  if (!flag || !flag.enabled) return false;

  // Check account allowlist
  if (flag.allowedAccountIds?.includes(context?.accountId ?? '')) return true;

  // Check role-based access
  if (flag.allowedRoles?.includes(context?.role ?? '')) return true;

  // Check percentage rollout (deterministic based on account ID)
  if (flag.rolloutPercentage !== undefined && context?.accountId) {
    const hash = hashString(context.accountId + featureName);
    return (hash % 100) < flag.rolloutPercentage;
  }

  return flag.enabled && !flag.rolloutPercentage && !flag.allowedAccountIds && !flag.allowedRoles;
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

import { useAccountContext } from '@/hooks/use-account';
import { isFeatureEnabled } from '@/lib/features';

interface FeatureFlagProps {
  name: string;
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export function FeatureFlag({ name, children, fallback = null }: FeatureFlagProps) {
  const { accountId, role } = useAccountContext();

  if (!isFeatureEnabled(name, { accountId, role })) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
}

// Usage
<FeatureFlag name="new_event_editor" fallback={<LegacyEventEditor />}>
  <NewEventEditor />
</FeatureFlag>
```

## Graceful Shutdown

### Next.js Instrumentation

```typescript
// instrumentation.ts
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const cleanup = async () => {
      console.log('Cleaning up before shutdown...');

      // Flush Sentry events
      const Sentry = await import('@sentry/nextjs');
      await Sentry.close(2000);

      // Note: Supabase connections are pooled by Supabase itself
      // No explicit cleanup needed for serverless

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

### Background Job Cleanup

```typescript
// For long-running operations (sync jobs, etc.)
class JobManager {
  private isShuttingDown = false;
  private activeJobs = new Set<string>();

  registerJob(jobId: string) {
    this.activeJobs.add(jobId);
  }

  completeJob(jobId: string) {
    this.activeJobs.delete(jobId);
  }

  async shutdown(): Promise<void> {
    this.isShuttingDown = true;

    // Wait for active jobs (with timeout)
    const timeout = 30000; // 30 seconds
    const start = Date.now();

    while (this.activeJobs.size > 0 && Date.now() - start < timeout) {
      console.log(`Waiting for ${this.activeJobs.size} jobs to complete...`);
      await new Promise(resolve => setTimeout(resolve, 1000));
    }

    if (this.activeJobs.size > 0) {
      console.warn(`Force shutdown with ${this.activeJobs.size} active jobs`);
    }
  }

  canStartNewJob(): boolean {
    return !this.isShuttingDown;
  }
}
```

## Environment Variable Validation

### Zod Schema Validation

```typescript
// lib/env.ts
import { z } from 'zod';

const envSchema = z.object({
  // Supabase
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(100),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(100),

  // Auth
  NEXT_PUBLIC_SITE_URL: z.string().url(),

  // Sentry
  SENTRY_DSN: z.string().url().optional(),
  NEXT_PUBLIC_SENTRY_DSN: z.string().url().optional(),
  SENTRY_AUTH_TOKEN: z.string().optional(),

  // Feature flags
  FEATURE_FEVER_SYNC: z.enum(['true', 'false']).default('true'),
  FEATURE_TIPALTI: z.enum(['true', 'false']).default('false'),
  MAINTENANCE_MODE: z.enum(['true', 'false']).default('false'),

  // Vercel (auto-populated)
  VERCEL_ENV: z.enum(['development', 'preview', 'production']).optional(),
  VERCEL_GIT_COMMIT_SHA: z.string().optional(),
  VERCEL_REGION: z.string().optional(),
});

function validateEnv() {
  const parsed = envSchema.safeParse(process.env);

  if (!parsed.success) {
    console.error('Invalid environment variables:');
    console.error(JSON.stringify(parsed.error.flatten().fieldErrors, null, 2));

    // Only exit in production - allow dev to continue with warnings
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Invalid environment configuration');
    }
  }

  return parsed.data;
}

export const env = validateEnv();
```

## Monitoring & Alerting

### Sentry Configuration

```typescript
// sentry.client.config.ts
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.VERCEL_ENV || 'development',
  release: process.env.VERCEL_GIT_COMMIT_SHA,

  // Performance monitoring
  tracesSampleRate: process.env.VERCEL_ENV === 'production' ? 0.1 : 1.0,

  // Session replay
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,

  // Filter noise
  ignoreErrors: [
    'ResizeObserver loop limit exceeded',
    'Non-Error promise rejection captured',
    /^Network request failed$/,
    /^Load failed$/,
    /^cancelled$/,
  ],

  beforeSend(event) {
    // Don't send in development
    if (process.env.NODE_ENV === 'development') {
      return null;
    }

    // Add Vercel context
    event.tags = {
      ...event.tags,
      vercel_region: process.env.VERCEL_REGION,
      vercel_env: process.env.VERCEL_ENV,
    };

    return event;
  },
});
```

### Error Tracking with Context

```typescript
// lib/error-tracking.ts
import * as Sentry from '@sentry/nextjs';

export function captureError(
  error: Error,
  context?: {
    userId?: string;
    accountId?: string;
    action?: string;
    metadata?: Record<string, unknown>;
  }
) {
  Sentry.withScope((scope) => {
    if (context?.userId) scope.setUser({ id: context.userId });
    if (context?.accountId) scope.setTag('account_id', context.accountId);
    if (context?.action) scope.setTag('action', context.action);
    if (context?.metadata) scope.setExtras(context.metadata);

    Sentry.captureException(error);
  });
}

// Usage in server actions
export const createEventAction = withAuthParams(async (params, formData) => {
  try {
    // ... action logic
  } catch (error) {
    captureError(error as Error, {
      userId: params.user.id,
      accountId: params.accountId,
      action: 'createEvent',
      metadata: { formData: Object.fromEntries(formData) },
    });
    throw error;
  }
});
```

## Incident Response

### Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| P1 | Service down | Immediate | Supabase down, auth broken |
| P2 | Major feature broken | 30 minutes | Payments failing, sync broken |
| P3 | Feature degraded | 4 hours | Slow queries, partial outage |
| P4 | Minor issue | 24 hours | UI bug, non-critical error |

### Incident Response Checklist

```markdown
## Incident Response Checklist

### 1. Acknowledge (0-5 minutes)
- [ ] Check Sentry for error details
- [ ] Identify scope (users affected, regions)
- [ ] Check Vercel deployment status
- [ ] Check Supabase dashboard status

### 2. Assess (5-15 minutes)
- [ ] Determine severity (P1-P4)
- [ ] Check recent deployments: `vercel ls --limit 5`
- [ ] Check Supabase: Dashboard > Database > Query Performance
- [ ] Update status page if customer-facing

### 3. Mitigate (15-60 minutes)
- [ ] Rollback if deployment-related: `vercel rollback`
- [ ] Enable maintenance mode: `vercel env add MAINTENANCE_MODE true`
- [ ] Disable feature flag if isolated to new feature
- [ ] Scale Supabase if capacity issue

### 4. Document
- [ ] Comment on Sentry issue with findings
- [ ] Create GitHub issue for follow-up
- [ ] Update runbook if new pattern discovered
```

### Quick Debug Commands

```bash
# Check recent Vercel deployments
vercel ls --limit 10

# Check Vercel logs
vercel logs --since 1h | grep -i error

# Check deployment status
vercel inspect [deployment-url]

# Rollback to previous deployment
vercel rollback

# Check Supabase connection (local)
pnpm supabase:web status

# Force Sentry to send pending events
# Add to instrumentation.ts shutdown
```

## Deployment Checklist

### Pre-Deployment

```markdown
## Pre-Deployment Checklist

### Code Quality
- [ ] All tests passing: `pnpm test:e2e`
- [ ] TypeScript compiles: `pnpm typecheck`
- [ ] Linting passes: `pnpm lint`
- [ ] No console.log statements in production code

### Database
- [ ] Migrations tested on staging
- [ ] RLS policies validated: `pnpm test:e2e` (E2E tests verify RLS)
- [ ] No breaking schema changes (or migration plan exists)

### Configuration
- [ ] New env vars added to Vercel (all environments)
- [ ] Feature flags configured for gradual rollout
- [ ] Sentry release configured

### Dependencies
- [ ] No security vulnerabilities: `pnpm audit`
- [ ] Lock file committed
```

### Post-Deployment

```markdown
## Post-Deployment Checklist

### Immediate (0-5 minutes)
- [ ] Deployment succeeded in Vercel
- [ ] Health check passing: `curl https://ballee.com/api/health`
- [ ] No new errors in Sentry
- [ ] Critical user flows working (login, dashboard)

### Short-term (5-30 minutes)
- [ ] Error rate stable in Sentry
- [ ] No customer complaints
- [ ] Supabase metrics stable (check dashboard)

### Follow-up (1-24 hours)
- [ ] Monitor for delayed issues
- [ ] Review any new Sentry errors
- [ ] Clean up feature flags if needed
```

## Troubleshooting

| Issue | Symptoms | Quick Fix |
|-------|----------|-----------|
| Supabase connection timeout | 503 errors, slow queries | Check connection pooling, reduce concurrent connections |
| Vercel function timeout | 504 errors | Optimize query, increase timeout, use edge functions |
| Memory limit exceeded | Function crashes | Reduce payload size, stream large responses |
| Rate limiting | 429 errors | Implement client-side throttling, cache responses |
| SSL errors | HTTPS failures | Check Supabase SSL mode, verify certificates |
| Cold start latency | Slow first requests | Keep functions warm, reduce bundle size |

## Related Skills

- `sentry-error-manager` - Error investigation and fixes
- `db-performance-patterns` - Query optimization
- `cicd-pipeline` - Deployment automation
- `dev-environment-manager` - Local development setup

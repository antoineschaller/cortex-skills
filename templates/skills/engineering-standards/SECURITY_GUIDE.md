# Security Guide

Comprehensive security standards for production-grade applications, covering environment variables, Row Level Security, authentication, secrets management, and audit logging.

## Table of Contents

- [Overview](#overview)
- [Environment Variables](#environment-variables)
- [RLS-First Data Access](#rls-first-data-access)
- [Authentication Wrappers](#authentication-wrappers)
- [Migration Security](#migration-security)
- [Secrets Management](#secrets-management)
- [Audit Logging](#audit-logging)
- [Security Best Practices](#security-best-practices)
- [Common Vulnerabilities](#common-vulnerabilities)

## Overview

### Security Philosophy

**Defense in Depth**: Multiple layers of security validation.

```
┌─────────────────────────────────────┐
│ Layer 1: Claude Code Hooks         │ (PreToolUse blocks)
├─────────────────────────────────────┤
│ Layer 2: Git Hooks                 │ (Pre-commit RLS validation)
├─────────────────────────────────────┤
│ Layer 3: RLS Policies               │ (Database-level security)
├─────────────────────────────────────┤
│ Layer 4: Auth Wrappers              │ (Server action validation)
├─────────────────────────────────────┤
│ Layer 5: Audit Logging              │ (Sensitive operation tracking)
└─────────────────────────────────────┘
```

**Key Principles**:
1. **RLS-First** - Use Row Level Security as primary data protection
2. **Never Trust Input** - Validate all user data
3. **Least Privilege** - Only grant minimum required permissions
4. **Audit Everything Sensitive** - Log all admin/privileged operations
5. **Secrets in Environment** - Never hardcode credentials

## Environment Variables

### File Structure

```
project/
├── .env.local              # Local development (gitignored)
├── .env.local.example      # Template (committed to git)
├── .env                    # Default values (committed, no secrets)
└── .env.production         # Production (deployed via CI/CD, never committed)
```

### .env.local (Local Development)

**Never commit this file!**

```bash
# .env.local

# Supabase (local dev instance)
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# API Keys
STRIPE_SECRET_KEY=sk_test_...
SENDGRID_API_KEY=SG...

# OAuth
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
```

### .env.local.example (Template)

**Commit this to git!**

```bash
# .env.local.example

# Supabase
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_local_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_local_service_role_key_here

# API Keys (get from 1Password)
STRIPE_SECRET_KEY=sk_test_your_stripe_key
SENDGRID_API_KEY=SG.your_sendgrid_key

# OAuth (get from respective providers)
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
```

### 1Password Integration

**Workflow**:
```bash
# 1. Check if .env.local exists
if [ ! -f .env.local ]; then
  echo ".env.local not found"

  # 2. Read secrets from 1Password
  op read "op://Dev/Supabase/anon_key" > /tmp/anon_key
  op read "op://Dev/Supabase/service_role_key" > /tmp/service_role_key

  # 3. Create .env.local from template
  cp .env.local.example .env.local

  # 4. Replace placeholders
  sed -i '' "s/your_local_anon_key_here/$(cat /tmp/anon_key)/" .env.local
  sed -i '' "s/your_local_service_role_key_here/$(cat /tmp/service_role_key)/" .env.local

  # 5. Cleanup
  rm /tmp/anon_key /tmp/service_role_key
fi
```

**Script** (`scripts/setup-env.sh`):
```bash
#!/bin/bash
# Setup environment variables from 1Password

set -e

if [ ! -f .env.local ]; then
  echo "Creating .env.local from 1Password..."

  # Check if 1Password CLI is installed
  if ! command -v op &> /dev/null; then
    echo "Error: 1Password CLI not installed"
    echo "Install: brew install 1password-cli"
    exit 1
  fi

  # Authenticate with 1Password
  eval $(op signin)

  # Create .env.local
  cat > .env.local << EOF
NEXT_PUBLIC_SUPABASE_URL=$(op read "op://Dev/Supabase/url")
NEXT_PUBLIC_SUPABASE_ANON_KEY=$(op read "op://Dev/Supabase/anon_key")
SUPABASE_SERVICE_ROLE_KEY=$(op read "op://Dev/Supabase/service_role_key")
STRIPE_SECRET_KEY=$(op read "op://Dev/Stripe/secret_key")
EOF

  echo "✅ .env.local created successfully"
else
  echo "✅ .env.local already exists"
fi
```

### Vercel Environment Variables

**Critical Gotcha**: Trailing newlines break environment variables!

❌ **Wrong** (adds trailing newline):
```bash
echo "$VALUE" | vercel env add KEY production
```

✅ **Correct** (no trailing newline):
```bash
printf "%s" "$VALUE" | vercel env add KEY production
```

**Automated Setup** (`scripts/sync-vercel-env.sh`):
```bash
#!/bin/bash
# Sync environment variables to Vercel

set -e

# Load from .env.local
if [ -f .env.local ]; then
  export $(cat .env.local | grep -v '^#' | xargs)
fi

# Function to add env var (uses printf to avoid trailing newline)
add_env() {
  local key=$1
  local value=$2
  local env=$3

  printf "%s" "$value" | vercel env add "$key" "$env" --force
}

# Add to production
add_env "NEXT_PUBLIC_SUPABASE_URL" "$NEXT_PUBLIC_SUPABASE_URL" "production"
add_env "NEXT_PUBLIC_SUPABASE_ANON_KEY" "$NEXT_PUBLIC_SUPABASE_ANON_KEY" "production"
add_env "SUPABASE_SERVICE_ROLE_KEY" "$SUPABASE_SERVICE_ROLE_KEY" "production"

echo "✅ Environment variables synced to Vercel"
```

**Claude Code Hook Enforcement**:
```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "cmd=\"$CLAUDE_TOOL_INPUT_command\"; if echo \"$cmd\" | grep -q 'echo' && echo \"$cmd\" | grep -q 'vercel env add'; then echo 'BLOCKED: Use printf instead of echo to avoid trailing newlines.' && exit 1; fi"
    }
  ]
}
```

### Environment Variable Validation

**Startup Validation** (`lib/validate-env.ts`):
```typescript
import { z } from 'zod';

const envSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  STRIPE_SECRET_KEY: z.string().startsWith('sk_'),
});

export function validateEnv() {
  try {
    envSchema.parse(process.env);
  } catch (error) {
    console.error('❌ Environment variable validation failed:');
    console.error(error);
    process.exit(1);
  }
}

// Call at app startup
validateEnv();
```

## RLS-First Data Access

### Core Pattern

**Default: userClient + RLS**
```typescript
import { getSupabaseServerClient } from '@kit/supabase/server-client';

export async function getEvents() {
  const client = getSupabaseServerClient();

  // RLS automatically filters based on auth.uid()
  const { data, error } = await client
    .from('events')
    .select('*');

  if (error) {
    return { success: false, error };
  }

  return { success: true, data };
}
```

**Admin Client: Only When Necessary**
```typescript
import { getSupabaseServerAdminClient } from '@kit/supabase/server-admin-client';

export async function getAllEventsAdmin() {
  // MUST validate super admin role first!
  const isSuperAdmin = await checkIsSuperAdmin();

  if (!isSuperAdmin) {
    throw new Error('Unauthorized: Super admin access required');
  }

  const client = getSupabaseServerAdminClient();

  // Bypasses RLS - sees all data
  const { data, error } = await client
    .from('events')
    .select('*');

  if (error) {
    return { success: false, error };
  }

  return { success: true, data };
}
```

### RLS Policy Patterns

#### 1. User-Scoped Policies

**Tables with user ownership** (e.g., profiles, bookings):

```sql
-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can only read their own profile
CREATE POLICY "Users can read own profile"
ON profiles FOR SELECT
USING (auth.uid() = user_id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Super admin bypass (using custom function)
CREATE POLICY "Super admin can read all profiles"
ON profiles FOR SELECT
USING (is_super_admin());
```

#### 2. Account-Scoped Policies

**Tables with account ownership** (e.g., events, productions):

```sql
-- Enable RLS
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Users can read events for their account
CREATE POLICY "Users can read account events"
ON events FOR SELECT
USING (
  account_id IN (
    SELECT account_id FROM account_users WHERE user_id = auth.uid()
  )
);

-- Super admin bypass
CREATE POLICY "Super admin can read all events"
ON events FOR SELECT
USING (is_super_admin());
```

#### 3. Public Read, Authenticated Write

**Tables with public data** (e.g., published events):

```sql
-- Enable RLS
ALTER TABLE public_events ENABLE ROW LEVEL SECURITY;

-- Anyone can read published events
CREATE POLICY "Anyone can read published events"
ON public_events FOR SELECT
USING (status = 'published');

-- Authenticated users can create events
CREATE POLICY "Authenticated users can create events"
ON public_events FOR INSERT
TO authenticated
WITH CHECK (true);
```

### is_super_admin() Function

**Database Function**:
```sql
CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT role INTO user_role
  FROM user_roles
  WHERE user_id = auth.uid();

  RETURN user_role = 'super_admin';
END;
$$;
```

**Usage in RLS Policies**:
```sql
CREATE POLICY "Super admin can see all"
ON sensitive_table FOR SELECT
USING (is_super_admin());
```

### RLS Testing

**Test with dual-client architecture**:
```typescript
import { test } from './fixtures/dual-client';

test('RLS prevents unauthorized access', async ({ userClient, adminClient }) => {
  // Setup: Admin creates data for different accounts
  await adminClient
    .from('events')
    .insert([
      { id: '1', name: 'User Event', account_id: 'user-account' },
      { id: '2', name: 'Other Event', account_id: 'other-account' },
    ]);

  // Test: User only sees their account's data
  const { data: userEvents } = await userClient
    .from('events')
    .select('*');

  expect(userEvents).toHaveLength(1);
  expect(userEvents[0].id).toBe('1');

  // Test: Admin sees all data
  const { data: allEvents } = await adminClient
    .from('events')
    .select('*');

  expect(allEvents).toHaveLength(2);
});
```

## Authentication Wrappers

### withAuth

**Purpose**: Require authenticated user.

```typescript
// lib/auth-wrappers.ts
import { redirect } from 'next/navigation';
import { getSupabaseServerClient } from '@kit/supabase/server-client';

export async function withAuth<T>(
  fn: (user: User) => Promise<T>
): Promise<T> {
  const client = getSupabaseServerClient();

  const { data: { user }, error } = await client.auth.getUser();

  if (error || !user) {
    redirect('/sign-in');
  }

  return fn(user);
}
```

**Usage**:
```typescript
export async function getProfile() {
  return withAuth(async (user) => {
    const client = getSupabaseServerClient();

    const { data } = await client
      .from('profiles')
      .select('*')
      .eq('user_id', user.id)
      .single();

    return data;
  });
}
```

### withAuthParams

**Purpose**: Inject auth context (user, client, account_id) into server actions.

```typescript
// lib/auth-wrappers.ts
export function withAuthParams<T extends any[], R>(
  fn: (params: AuthParams, ...args: T) => Promise<R>
) {
  return async (...args: T): Promise<R> => {
    const client = getSupabaseServerClient();

    const { data: { user }, error } = await client.auth.getUser();

    if (error || !user) {
      throw new Error('Unauthorized');
    }

    // Get current account from context
    const accountId = await getCurrentAccountId();

    const params: AuthParams = {
      user,
      client,
      accountId,
    };

    return fn(params, ...args);
  };
}
```

**Usage in Server Actions**:
```typescript
'use server';

import { withAuthParams } from '@/lib/auth-wrappers';
import { revalidatePath } from 'next/cache';

export const createEvent = withAuthParams(async (params, formData: FormData) => {
  const validated = CreateEventSchema.safeParse(Object.fromEntries(formData));

  if (!validated.success) {
    return { success: false, error: validated.error };
  }

  // params.client automatically scoped to user via RLS
  const { data, error } = await params.client
    .from('events')
    .insert({
      ...validated.data,
      account_id: params.accountId,
    })
    .select()
    .single();

  if (error) {
    return { success: false, error: error.message };
  }

  revalidatePath('/events');
  return { success: true, data };
});
```

### withSuperAdmin

**Purpose**: Require super admin role.

```typescript
// lib/auth-wrappers.ts
export async function withSuperAdmin<T>(
  fn: () => Promise<T>
): Promise<T> {
  const client = getSupabaseServerClient();

  const { data: { user }, error } = await client.auth.getUser();

  if (error || !user) {
    throw new Error('Unauthorized');
  }

  const { data: role } = await client
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id)
    .single();

  if (role?.role !== 'super_admin') {
    throw new Error('Forbidden: Super admin access required');
  }

  return fn();
}
```

**Usage**:
```typescript
export async function getAllUsers() {
  return withSuperAdmin(async () => {
    const client = getSupabaseServerAdminClient();

    const { data } = await client
      .from('users')
      .select('*');

    return data;
  });
}
```

## Migration Security

### Idempotency Validation

**Pre-commit Hook** (from HOOKS_GUIDE.md):
```yaml
validate-migration-idempotency:
  glob: 'apps/web/supabase/migrations/*.sql'
  run: bash .claude/skills/database-migration-manager/scripts/validate-idempotency.sh {staged_files}
```

### SQL Injection Prevention

❌ **Vulnerable**:
```typescript
// NEVER DO THIS
const email = req.query.email;
const query = `SELECT * FROM users WHERE email = '${email}'`;
await client.query(query);

// Injection: ?email=' OR '1'='1
```

✅ **Safe (Parameterized Queries)**:
```typescript
// Use Supabase query builder (auto-escapes)
const { data } = await client
  .from('users')
  .select('*')
  .eq('email', email);

// Or use RPC with typed parameters
const { data } = await client
  .rpc('get_user_by_email', { email_param: email });
```

### Dangerous Operations Blocked

**Claude Code Hook**:
```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "cmd=\"$CLAUDE_TOOL_INPUT_command\"; if echo \"$cmd\" | grep -qE 'supabase.*db.*push|psql.*-c.*(ALTER|DROP|CREATE)'; then echo 'BLOCKED: Use migrations instead.' && exit 1; fi"
    }
  ]
}
```

**Blocked Commands**:
- `supabase db push` (use migrations)
- `psql -c "DROP TABLE ..."` (use migrations)
- Direct schema modifications

### Migration Validation Script

```bash
#!/bin/bash
# scripts/validate-migrations.sh

for file in "$@"; do
  # Check for DROP commands without confirmation
  if grep -qi 'DROP TABLE' "$file" && ! grep -qi 'IF EXISTS' "$file"; then
    echo "❌ DROP TABLE without IF EXISTS in: $file"
    exit 1
  fi

  # Check for TRUNCATE
  if grep -qi 'TRUNCATE' "$file"; then
    echo "❌ TRUNCATE command found in: $file"
    echo "   Use DELETE with WHERE clause for safety"
    exit 1
  fi

  # Check for commented destructive operations
  if grep -qiE '^--.*DROP|^--.*TRUNCATE' "$file"; then
    echo "⚠️  Commented destructive operation in: $file"
  fi
done

echo "✅ Migration validation passed"
```

## Secrets Management

### 1. Never Hardcode Secrets

❌ **Wrong**:
```typescript
const stripe = new Stripe('sk_live_hardcoded_secret_key');
const supabase = createClient('https://abc.supabase.co', 'hardcoded_key');
```

✅ **Correct**:
```typescript
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);
```

### 2. Validate Secrets at Runtime

```typescript
// lib/config.ts
import { z } from 'zod';

const configSchema = z.object({
  stripe: z.object({
    secretKey: z.string().startsWith('sk_'),
    publishableKey: z.string().startsWith('pk_'),
  }),
  supabase: z.object({
    url: z.string().url(),
    anonKey: z.string().min(1),
    serviceRoleKey: z.string().min(1),
  }),
});

export const config = configSchema.parse({
  stripe: {
    secretKey: process.env.STRIPE_SECRET_KEY,
    publishableKey: process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY,
  },
  supabase: {
    url: process.env.NEXT_PUBLIC_SUPABASE_URL,
    anonKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
  },
});
```

### 3. Rotate Secrets Regularly

**Process**:
1. Generate new secret (Stripe, Supabase, etc.)
2. Update in 1Password
3. Deploy new secret to production (Vercel env)
4. Verify application works with new secret
5. Revoke old secret

**Rotation Schedule**:
- API keys: Every 90 days
- Service role keys: Every 180 days
- OAuth secrets: After security incidents

### 4. Secrets in CI/CD

**GitHub Actions**:
```yaml
# .github/workflows/deploy.yml
jobs:
  deploy:
    steps:
      - name: Deploy to Vercel
        env:
          VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
        run: vercel deploy --prod
```

**GitHub Secrets**:
```bash
# Add secret via CLI
gh secret set SUPABASE_SERVICE_ROLE_KEY --body "$VALUE"

# Or via GitHub UI:
# Settings → Secrets and variables → Actions → New repository secret
```

## Audit Logging

### Audit Table Schema

```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  action TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT,
  old_values JSONB,
  new_values JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for queries
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);

-- RLS: Only super admins can read audit logs
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Super admin can read audit logs"
ON audit_logs FOR SELECT
USING (is_super_admin());
```

### Audit Logging Utility

```typescript
// lib/audit-logger.ts
import { getSupabaseServerAdminClient } from '@kit/supabase/server-admin-client';

export async function logAudit(params: {
  userId: string;
  action: string;
  resourceType: string;
  resourceId?: string;
  oldValues?: Record<string, any>;
  newValues?: Record<string, any>;
  ipAddress?: string;
  userAgent?: string;
}) {
  const client = getSupabaseServerAdminClient();

  await client.from('audit_logs').insert({
    user_id: params.userId,
    action: params.action,
    resource_type: params.resourceType,
    resource_id: params.resourceId,
    old_values: params.oldValues,
    new_values: params.newValues,
    ip_address: params.ipAddress,
    user_agent: params.userAgent,
  });
}
```

### Usage in Server Actions

```typescript
'use server';

import { withAuthParams } from '@/lib/auth-wrappers';
import { logAudit } from '@/lib/audit-logger';

export const deleteEvent = withAuthParams(async (params, eventId: string) => {
  // Get existing event for audit log
  const { data: existingEvent } = await params.client
    .from('events')
    .select('*')
    .eq('id', eventId)
    .single();

  if (!existingEvent) {
    return { success: false, error: 'Event not found' };
  }

  // Delete event
  const { error } = await params.client
    .from('events')
    .delete()
    .eq('id', eventId);

  if (error) {
    return { success: false, error: error.message };
  }

  // Log audit entry
  await logAudit({
    userId: params.user.id,
    action: 'delete',
    resourceType: 'event',
    resourceId: eventId,
    oldValues: existingEvent,
    newValues: null,
  });

  return { success: true };
});
```

### What to Audit

**Critical Operations** (MUST audit):
- User role changes (promote to admin, etc.)
- Data deletion (soft delete doesn't need audit)
- Permission changes (RLS policy modifications)
- Sensitive data access (PII, financial data)
- Admin operations (bulk updates, manual overrides)

**Not Required**:
- Regular CRUD on non-sensitive data
- User profile updates (by user)
- Public data reads

## Security Best Practices

### 1. Principle of Least Privilege

```typescript
// ❌ Bad: Admin client for regular operation
const client = getSupabaseServerAdminClient();
const { data } = await client.from('events').select('*'); // Bypasses RLS!

// ✅ Good: User client with RLS
const client = getSupabaseServerClient();
const { data } = await client.from('events').select('*'); // RLS enforced
```

### 2. Validate All Input

```typescript
import { z } from 'zod';

const CreateEventSchema = z.object({
  name: z.string().min(1).max(200).transform(v => v.trim()),
  email: z.string().email().toLowerCase(),
  price: z.coerce.number().positive().max(10000),
  date: z.coerce.date().refine(d => d > new Date(), 'Date must be in future'),
});

export const createEvent = withAuthParams(async (params, formData: FormData) => {
  // Validate input
  const validated = CreateEventSchema.safeParse(Object.fromEntries(formData));

  if (!validated.success) {
    return { success: false, error: validated.error.flatten() };
  }

  // Use validated data only
  const { data, error } = await params.client
    .from('events')
    .insert(validated.data);

  // ...
});
```

### 3. Rate Limiting

```typescript
// lib/rate-limiter.ts
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '10 s'), // 10 requests per 10 seconds
});

export async function checkRateLimit(identifier: string) {
  const { success, limit, remaining, reset } = await ratelimit.limit(identifier);

  if (!success) {
    throw new Error('Rate limit exceeded');
  }

  return { limit, remaining, reset };
}
```

**Usage**:
```typescript
export const createEvent = withAuthParams(async (params, formData: FormData) => {
  // Check rate limit
  await checkRateLimit(`create_event_${params.user.id}`);

  // Proceed with creation
  // ...
});
```

### 4. CSRF Protection

**Next.js automatically handles CSRF** for Server Actions, but for API routes:

```typescript
// app/api/webhooks/stripe/route.ts
import { headers } from 'next/headers';
import Stripe from 'stripe';

export async function POST(req: Request) {
  const body = await req.text();
  const sig = headers().get('stripe-signature')!;

  try {
    // Verify webhook signature (protects against CSRF)
    const event = stripe.webhooks.constructEvent(
      body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET!
    );

    // Handle event
    // ...
  } catch (err) {
    return new Response('Webhook signature verification failed', { status: 400 });
  }
}
```

## Common Vulnerabilities

### 1. SQL Injection

❌ **Vulnerable**:
```typescript
const query = `SELECT * FROM users WHERE id = '${userId}'`;
```

✅ **Safe**:
```typescript
const { data } = await client.from('users').select('*').eq('id', userId);
```

### 2. XSS (Cross-Site Scripting)

❌ **Vulnerable**:
```typescript
return <div dangerouslySetInnerHTML={{ __html: userInput }} />;
```

✅ **Safe**:
```typescript
return <div>{userInput}</div>; // React auto-escapes
```

### 3. Insecure Direct Object References

❌ **Vulnerable**:
```typescript
export async function deleteEvent(eventId: string) {
  // No authorization check!
  await client.from('events').delete().eq('id', eventId);
}
```

✅ **Safe**:
```typescript
export const deleteEvent = withAuthParams(async (params, eventId: string) => {
  // RLS ensures user can only delete their account's events
  const { error } = await params.client
    .from('events')
    .delete()
    .eq('id', eventId);

  if (error) {
    return { success: false, error: 'Unauthorized or not found' };
  }

  return { success: true };
});
```

### 4. Mass Assignment

❌ **Vulnerable**:
```typescript
// User can set any field, including role!
const { data } = await client
  .from('users')
  .update(formData) // Contains { role: 'admin' }
  .eq('id', userId);
```

✅ **Safe**:
```typescript
// Whitelist allowed fields
const allowedFields = ['name', 'email', 'bio'];
const updateData = Object.fromEntries(
  Object.entries(formData).filter(([key]) => allowedFields.includes(key))
);

const { data } = await client
  .from('users')
  .update(updateData)
  .eq('id', userId);
```

---

**Last Updated**: 2026-01-13
**Related**: [HOOKS_GUIDE.md](HOOKS_GUIDE.md), [PATTERNS_LIBRARY.md](PATTERNS_LIBRARY.md)

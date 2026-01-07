# Authentication Patterns

Authentication and authorization patterns for secure applications.

> **Template Usage:** Customize for your auth provider (NextAuth, Supabase Auth, Auth0, Clerk, etc.).

## Session vs JWT

| Aspect | Session-Based | JWT-Based |
|--------|---------------|-----------|
| Storage | Server (DB/Redis) | Client (cookie/localStorage) |
| Scalability | Needs shared session store | Stateless, easy to scale |
| Revocation | Immediate (delete session) | Harder (need blocklist) |
| Size | Small cookie (session ID) | Larger (contains claims) |
| Best for | Traditional web apps | APIs, microservices, mobile |

## Auth Middleware Pattern

```typescript
// middleware.ts (Next.js)
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { getToken } from 'next-auth/jwt';

// Routes that require authentication
const protectedRoutes = ['/dashboard', '/settings', '/api/protected'];
const authRoutes = ['/login', '/register'];

export async function middleware(request: NextRequest) {
  const token = await getToken({ req: request });
  const isAuthenticated = !!token;
  const path = request.nextUrl.pathname;

  // Redirect authenticated users away from auth pages
  if (isAuthenticated && authRoutes.some(route => path.startsWith(route))) {
    return NextResponse.redirect(new URL('/dashboard', request.url));
  }

  // Redirect unauthenticated users to login
  if (!isAuthenticated && protectedRoutes.some(route => path.startsWith(route))) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('callbackUrl', path);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
```

## Server-Side Auth Check

```typescript
// lib/auth.ts
import { getServerSession } from 'next-auth';
import { redirect } from 'next/navigation';
import { authOptions } from '@/app/api/auth/[...nextauth]/route';

// Get current user (returns null if not authenticated)
export async function getCurrentUser() {
  const session = await getServerSession(authOptions);
  return session?.user ?? null;
}

// Require authentication (redirects if not authenticated)
export async function requireUser() {
  const user = await getCurrentUser();
  if (!user) {
    redirect('/login');
  }
  return user;
}

// Require specific role
export async function requireRole(allowedRoles: string[]) {
  const user = await requireUser();
  if (!allowedRoles.includes(user.role)) {
    redirect('/unauthorized');
  }
  return user;
}

// Usage in Server Component
async function DashboardPage() {
  const user = await requireUser();
  return <Dashboard user={user} />;
}

// Usage in Server Action
'use server';

export async function updateProfile(formData: FormData) {
  const user = await requireUser();
  // user is guaranteed to exist
  await db.user.update({
    where: { id: user.id },
    data: { name: formData.get('name') as string },
  });
}
```

## Protected Route Component

```typescript
// components/protected-route.tsx
'use client';

import { useSession } from 'next-auth/react';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

interface ProtectedRouteProps {
  children: React.ReactNode;
  requiredRole?: string;
  fallback?: React.ReactNode;
}

export function ProtectedRoute({
  children,
  requiredRole,
  fallback = <LoadingSpinner />,
}: ProtectedRouteProps) {
  const { data: session, status } = useSession();
  const router = useRouter();

  useEffect(() => {
    if (status === 'loading') return;

    if (!session) {
      router.push('/login');
      return;
    }

    if (requiredRole && session.user.role !== requiredRole) {
      router.push('/unauthorized');
    }
  }, [session, status, router, requiredRole]);

  if (status === 'loading') {
    return fallback;
  }

  if (!session) {
    return fallback;
  }

  if (requiredRole && session.user.role !== requiredRole) {
    return fallback;
  }

  return <>{children}</>;
}
```

## Role-Based Access Control (RBAC)

```typescript
// lib/permissions.ts

// Define roles and their permissions
const ROLE_PERMISSIONS = {
  admin: ['read', 'write', 'delete', 'manage_users', 'manage_settings'],
  editor: ['read', 'write', 'delete'],
  viewer: ['read'],
} as const;

type Role = keyof typeof ROLE_PERMISSIONS;
type Permission = typeof ROLE_PERMISSIONS[Role][number];

export function hasPermission(userRole: Role, permission: Permission): boolean {
  const permissions = ROLE_PERMISSIONS[userRole] || [];
  return permissions.includes(permission);
}

export function requirePermission(userRole: Role, permission: Permission): void {
  if (!hasPermission(userRole, permission)) {
    throw new ForbiddenError(`Missing permission: ${permission}`);
  }
}

// Usage
async function deletePost(postId: string) {
  const user = await requireUser();
  requirePermission(user.role, 'delete');

  await db.post.delete({ where: { id: postId } });
}
```

## OAuth Integration

```typescript
// app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth';
import GoogleProvider from 'next-auth/providers/google';
import GitHubProvider from 'next-auth/providers/github';
import { PrismaAdapter } from '@auth/prisma-adapter';
import { db } from '@/lib/db';

export const authOptions = {
  adapter: PrismaAdapter(db),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
    GitHubProvider({
      clientId: process.env.GITHUB_CLIENT_ID!,
      clientSecret: process.env.GITHUB_CLIENT_SECRET!,
    }),
  ],
  callbacks: {
    async session({ session, user }) {
      // Add user ID and role to session
      session.user.id = user.id;
      session.user.role = user.role;
      return session;
    },
    async signIn({ user, account, profile }) {
      // Custom sign-in logic (e.g., check allowed domains)
      if (account?.provider === 'google') {
        return profile?.email?.endsWith('@company.com') ?? false;
      }
      return true;
    },
  },
  pages: {
    signIn: '/login',
    error: '/auth/error',
  },
};

const handler = NextAuth(authOptions);
export { handler as GET, handler as POST };
```

## Password Hashing

```typescript
// lib/password.ts
import bcrypt from 'bcryptjs';

const SALT_ROUNDS = 12;

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

export async function verifyPassword(
  password: string,
  hashedPassword: string
): Promise<boolean> {
  return bcrypt.compare(password, hashedPassword);
}

// Usage
async function registerUser(email: string, password: string) {
  const hashedPassword = await hashPassword(password);
  return db.user.create({
    data: { email, password: hashedPassword },
  });
}

async function loginUser(email: string, password: string) {
  const user = await db.user.findUnique({ where: { email } });
  if (!user) {
    throw new UnauthorizedError('Invalid credentials');
  }

  const isValid = await verifyPassword(password, user.password);
  if (!isValid) {
    throw new UnauthorizedError('Invalid credentials');
  }

  return user;
}
```

## Password Reset Flow

> **CRITICAL**: Password reset tokens must be single-use, time-limited, and cryptographically secure.

### Database Schema

```sql
CREATE TABLE password_reset_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,  -- Store hash, not plaintext
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,  -- Track if token was used
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for efficient token lookup
CREATE INDEX idx_password_reset_tokens_hash ON password_reset_tokens(token_hash);

-- Clean up expired tokens
CREATE INDEX idx_password_reset_tokens_expires ON password_reset_tokens(expires_at);
```

### Request Password Reset

```typescript
// lib/password-reset.ts
import { randomBytes, createHash } from 'crypto';

const TOKEN_EXPIRY_HOURS = 1;

function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export async function requestPasswordReset(email: string) {
  // Always return success to prevent email enumeration
  const user = await db.user.findUnique({ where: { email } });

  if (!user) {
    // Log for monitoring but don't reveal to user
    console.log(`Password reset requested for non-existent email: ${email}`);
    return { success: true };
  }

  // Invalidate any existing tokens for this user
  await db.passwordResetToken.updateMany({
    where: { userId: user.id, usedAt: null },
    data: { usedAt: new Date() },
  });

  // Generate secure token
  const token = randomBytes(32).toString('hex');
  const tokenHash = hashToken(token);

  // Store hashed token
  await db.passwordResetToken.create({
    data: {
      userId: user.id,
      tokenHash,
      expiresAt: new Date(Date.now() + TOKEN_EXPIRY_HOURS * 60 * 60 * 1000),
    },
  });

  // Send email with plaintext token
  await sendEmail({
    to: email,
    subject: 'Password Reset Request',
    template: 'password-reset',
    data: {
      resetUrl: `${process.env.APP_URL}/reset-password?token=${token}`,
      expiresInHours: TOKEN_EXPIRY_HOURS,
    },
  });

  return { success: true };
}
```

### Verify and Reset Password

```typescript
export async function resetPassword(token: string, newPassword: string) {
  const tokenHash = hashToken(token);

  // Find valid token
  const resetToken = await db.passwordResetToken.findFirst({
    where: {
      tokenHash,
      expiresAt: { gt: new Date() },
      usedAt: null,
    },
    include: { user: true },
  });

  if (!resetToken) {
    throw new Error('Invalid or expired reset token');
  }

  // Validate password strength
  validatePasswordStrength(newPassword);

  // Update password and mark token as used
  const hashedPassword = await hashPassword(newPassword);

  await db.$transaction([
    db.user.update({
      where: { id: resetToken.userId },
      data: {
        password: hashedPassword,
        tokenVersion: { increment: 1 }, // Invalidate all sessions
      },
    }),
    db.passwordResetToken.update({
      where: { id: resetToken.id },
      data: { usedAt: new Date() },
    }),
  ]);

  // Notify user of password change
  await sendEmail({
    to: resetToken.user.email,
    subject: 'Password Changed',
    template: 'password-changed',
  });

  return { success: true };
}

function validatePasswordStrength(password: string) {
  const errors: string[] = [];

  if (password.length < 8) errors.push('At least 8 characters');
  if (!/[A-Z]/.test(password)) errors.push('One uppercase letter');
  if (!/[a-z]/.test(password)) errors.push('One lowercase letter');
  if (!/[0-9]/.test(password)) errors.push('One number');
  if (!/[^A-Za-z0-9]/.test(password)) errors.push('One special character');

  if (errors.length > 0) {
    throw new Error(`Password requirements: ${errors.join(', ')}`);
  }
}
```

## Account Lockout

> **Purpose**: Prevent brute-force attacks by temporarily locking accounts after repeated failed attempts.

### Database Schema

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS failed_login_attempts INT DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_failed_login TIMESTAMPTZ;

-- Track login attempts for rate limiting
CREATE TABLE login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  ip_address INET,
  user_agent TEXT,
  success BOOLEAN NOT NULL,
  failure_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_login_attempts_email ON login_attempts(email, created_at);
CREATE INDEX idx_login_attempts_ip ON login_attempts(ip_address, created_at);
```

### Login with Lockout

```typescript
// lib/auth-lockout.ts
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_MINUTES = 15;
const ATTEMPT_WINDOW_MINUTES = 15;

export async function loginWithLockout(
  email: string,
  password: string,
  ipAddress: string,
  userAgent: string
): Promise<User> {
  // Check if account is locked
  const user = await db.user.findUnique({ where: { email } });

  if (user?.lockedUntil && user.lockedUntil > new Date()) {
    const minutesRemaining = Math.ceil(
      (user.lockedUntil.getTime() - Date.now()) / 60000
    );

    await logAttempt(email, ipAddress, userAgent, false, 'account_locked');

    throw new AccountLockedError(
      `Account locked. Try again in ${minutesRemaining} minutes.`
    );
  }

  // Check IP-based rate limiting
  const recentIpAttempts = await db.loginAttempt.count({
    where: {
      ipAddress,
      success: false,
      createdAt: { gt: new Date(Date.now() - ATTEMPT_WINDOW_MINUTES * 60000) },
    },
  });

  if (recentIpAttempts >= MAX_FAILED_ATTEMPTS * 2) {
    throw new RateLimitError('Too many login attempts from this IP');
  }

  // Attempt login
  try {
    if (!user) {
      await logAttempt(email, ipAddress, userAgent, false, 'user_not_found');
      throw new UnauthorizedError('Invalid credentials');
    }

    const isValid = await verifyPassword(password, user.password);

    if (!isValid) {
      await handleFailedLogin(user, email, ipAddress, userAgent);
      throw new UnauthorizedError('Invalid credentials');
    }

    // Successful login - reset counters
    await db.user.update({
      where: { id: user.id },
      data: {
        failedLoginAttempts: 0,
        lockedUntil: null,
        lastFailedLogin: null,
      },
    });

    await logAttempt(email, ipAddress, userAgent, true, null);

    return user;
  } catch (error) {
    throw error;
  }
}

async function handleFailedLogin(
  user: User,
  email: string,
  ipAddress: string,
  userAgent: string
) {
  const newAttempts = user.failedLoginAttempts + 1;

  const updateData: any = {
    failedLoginAttempts: newAttempts,
    lastFailedLogin: new Date(),
  };

  // Lock account if max attempts exceeded
  if (newAttempts >= MAX_FAILED_ATTEMPTS) {
    updateData.lockedUntil = new Date(
      Date.now() + LOCKOUT_DURATION_MINUTES * 60000
    );

    // Send security alert email
    await sendEmail({
      to: user.email,
      subject: 'Account Locked - Suspicious Activity',
      template: 'account-locked',
      data: {
        ipAddress,
        lockDuration: LOCKOUT_DURATION_MINUTES,
      },
    });
  }

  await db.user.update({
    where: { id: user.id },
    data: updateData,
  });

  await logAttempt(email, ipAddress, userAgent, false, 'invalid_password');
}

async function logAttempt(
  email: string,
  ipAddress: string,
  userAgent: string,
  success: boolean,
  failureReason: string | null
) {
  await db.loginAttempt.create({
    data: {
      email,
      ipAddress,
      userAgent,
      success,
      failureReason,
    },
  });
}
```

### Unlock Account (Admin)

```typescript
export async function unlockAccount(userId: string, adminId: string) {
  await db.user.update({
    where: { id: userId },
    data: {
      failedLoginAttempts: 0,
      lockedUntil: null,
    },
  });

  // Audit log
  await db.auditLog.create({
    data: {
      action: 'ACCOUNT_UNLOCKED',
      targetUserId: userId,
      performedBy: adminId,
    },
  });
}
```

## Multi-Factor Authentication (MFA/2FA)

### Database Schema

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_secret TEXT;  -- Encrypted TOTP secret
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_backup_codes TEXT[];  -- Hashed backup codes

-- MFA recovery codes (one-time use)
CREATE TABLE mfa_backup_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### TOTP Setup

```typescript
// lib/mfa.ts
import { authenticator } from 'otplib';
import QRCode from 'qrcode';
import { randomBytes, createHash } from 'crypto';

const APP_NAME = 'MyApp';

export async function setupMFA(userId: string) {
  const user = await db.user.findUnique({ where: { id: userId } });

  if (!user) throw new Error('User not found');
  if (user.mfaEnabled) throw new Error('MFA already enabled');

  // Generate secret
  const secret = authenticator.generateSecret();

  // Generate backup codes
  const backupCodes = Array.from({ length: 10 }, () =>
    randomBytes(4).toString('hex').toUpperCase()
  );

  const backupCodeHashes = backupCodes.map((code) =>
    createHash('sha256').update(code).digest('hex')
  );

  // Store encrypted secret (don't enable MFA yet)
  await db.user.update({
    where: { id: userId },
    data: {
      mfaSecret: encrypt(secret), // Use your encryption library
    },
  });

  // Store hashed backup codes
  await db.mfaBackupCode.createMany({
    data: backupCodeHashes.map((hash) => ({
      userId,
      codeHash: hash,
    })),
  });

  // Generate QR code
  const otpauthUrl = authenticator.keyuri(user.email, APP_NAME, secret);
  const qrCodeDataUrl = await QRCode.toDataURL(otpauthUrl);

  return {
    secret, // Show once for manual entry
    qrCode: qrCodeDataUrl,
    backupCodes, // Show once, user must save these
  };
}

export async function verifyAndEnableMFA(userId: string, token: string) {
  const user = await db.user.findUnique({ where: { id: userId } });

  if (!user?.mfaSecret) throw new Error('MFA not set up');
  if (user.mfaEnabled) throw new Error('MFA already enabled');

  const secret = decrypt(user.mfaSecret);
  const isValid = authenticator.verify({ token, secret });

  if (!isValid) {
    throw new Error('Invalid verification code');
  }

  await db.user.update({
    where: { id: userId },
    data: { mfaEnabled: true },
  });

  return { success: true };
}
```

### MFA Verification During Login

```typescript
export async function verifyMFA(
  userId: string,
  token: string
): Promise<boolean> {
  const user = await db.user.findUnique({
    where: { id: userId },
  });

  if (!user?.mfaEnabled || !user.mfaSecret) {
    throw new Error('MFA not enabled');
  }

  const secret = decrypt(user.mfaSecret);

  // Try TOTP first
  if (authenticator.verify({ token, secret })) {
    return true;
  }

  // Try backup code
  const tokenHash = createHash('sha256').update(token.toUpperCase()).digest('hex');
  const backupCode = await db.mfaBackupCode.findFirst({
    where: {
      userId,
      codeHash: tokenHash,
      usedAt: null,
    },
  });

  if (backupCode) {
    // Mark backup code as used
    await db.mfaBackupCode.update({
      where: { id: backupCode.id },
      data: { usedAt: new Date() },
    });

    // Warn user about used backup code
    await sendEmail({
      to: user.email,
      subject: 'MFA Backup Code Used',
      template: 'backup-code-used',
    });

    return true;
  }

  throw new Error('Invalid MFA code');
}

// Login flow with MFA
export async function loginWithMFA(email: string, password: string) {
  const user = await loginWithLockout(email, password, ip, userAgent);

  if (user.mfaEnabled) {
    // Return partial session - requires MFA step
    const mfaToken = jwt.sign(
      { userId: user.id, type: 'mfa_pending' },
      process.env.JWT_SECRET!,
      { expiresIn: '5m' }
    );

    return {
      requiresMfa: true,
      mfaToken,
    };
  }

  // No MFA - return full session
  return {
    requiresMfa: false,
    session: await createSession(user),
  };
}

export async function completeMFALogin(mfaToken: string, code: string) {
  const payload = jwt.verify(mfaToken, process.env.JWT_SECRET!) as {
    userId: string;
    type: string;
  };

  if (payload.type !== 'mfa_pending') {
    throw new Error('Invalid MFA token');
  }

  const isValid = await verifyMFA(payload.userId, code);

  if (!isValid) {
    throw new Error('Invalid MFA code');
  }

  const user = await db.user.findUnique({ where: { id: payload.userId } });
  return createSession(user!);
}
```

### Disable MFA

```typescript
export async function disableMFA(userId: string, password: string) {
  const user = await db.user.findUnique({ where: { id: userId } });

  if (!user) throw new Error('User not found');

  // Require password verification
  const isValid = await verifyPassword(password, user.password);
  if (!isValid) {
    throw new Error('Invalid password');
  }

  await db.$transaction([
    db.user.update({
      where: { id: userId },
      data: {
        mfaEnabled: false,
        mfaSecret: null,
      },
    }),
    db.mfaBackupCode.deleteMany({
      where: { userId },
    }),
  ]);

  await sendEmail({
    to: user.email,
    subject: 'MFA Disabled',
    template: 'mfa-disabled',
  });

  return { success: true };
}
```

## Device/Session Management

### Database Schema

```sql
CREATE TABLE user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  device_name TEXT,
  device_type TEXT,  -- 'desktop', 'mobile', 'tablet'
  browser TEXT,
  os TEXT,
  ip_address INET,
  location TEXT,  -- Derived from IP
  last_active_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(token_hash);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);
```

### Session Creation with Device Info

```typescript
// lib/sessions.ts
import { UAParser } from 'ua-parser-js';
import geoip from 'geoip-lite';

export async function createSession(
  user: User,
  request: Request
): Promise<Session> {
  const userAgent = request.headers.get('user-agent') || '';
  const ip = request.headers.get('x-forwarded-for')?.split(',')[0] || 'unknown';

  // Parse user agent
  const parser = new UAParser(userAgent);
  const browser = parser.getBrowser();
  const os = parser.getOS();
  const device = parser.getDevice();

  // Get location from IP
  const geo = geoip.lookup(ip);
  const location = geo
    ? `${geo.city || 'Unknown'}, ${geo.country}`
    : 'Unknown location';

  // Generate session token
  const token = randomBytes(32).toString('hex');
  const tokenHash = createHash('sha256').update(token).digest('hex');

  const session = await db.userSession.create({
    data: {
      userId: user.id,
      tokenHash,
      deviceName: device.model || `${browser.name} on ${os.name}`,
      deviceType: device.type || 'desktop',
      browser: browser.name,
      os: os.name,
      ipAddress: ip,
      location,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
    },
  });

  // Check for new device and alert user
  const existingSessions = await db.userSession.findMany({
    where: { userId: user.id },
  });

  const isNewDevice = !existingSessions.some(
    (s) =>
      s.browser === browser.name &&
      s.os === os.name &&
      s.deviceType === (device.type || 'desktop')
  );

  if (isNewDevice && existingSessions.length > 0) {
    await sendEmail({
      to: user.email,
      subject: 'New Device Login',
      template: 'new-device-login',
      data: {
        deviceName: session.deviceName,
        location,
        time: new Date().toISOString(),
      },
    });
  }

  return { ...session, token };
}
```

### List User Sessions

```typescript
export async function getUserSessions(userId: string) {
  return db.userSession.findMany({
    where: {
      userId,
      expiresAt: { gt: new Date() },
    },
    orderBy: { lastActiveAt: 'desc' },
    select: {
      id: true,
      deviceName: true,
      deviceType: true,
      browser: true,
      os: true,
      location: true,
      ipAddress: true,
      lastActiveAt: true,
      createdAt: true,
    },
  });
}
```

### Revoke Sessions

```typescript
// Revoke single session
export async function revokeSession(
  userId: string,
  sessionId: string
): Promise<void> {
  await db.userSession.deleteMany({
    where: {
      id: sessionId,
      userId, // Ensure user owns this session
    },
  });
}

// Revoke all sessions except current
export async function revokeOtherSessions(
  userId: string,
  currentSessionId: string
): Promise<number> {
  const result = await db.userSession.deleteMany({
    where: {
      userId,
      id: { not: currentSessionId },
    },
  });

  return result.count;
}

// Revoke all sessions (password change, security concern)
export async function revokeAllSessions(userId: string): Promise<void> {
  await db.userSession.deleteMany({
    where: { userId },
  });

  // Also increment token version to invalidate any JWTs
  await db.user.update({
    where: { id: userId },
    data: { tokenVersion: { increment: 1 } },
  });
}
```

### Session Heartbeat

```typescript
// Update session activity on each request
export async function updateSessionActivity(tokenHash: string): Promise<void> {
  await db.userSession.update({
    where: { tokenHash },
    data: { lastActiveAt: new Date() },
  });
}

// Middleware to track activity
export async function sessionMiddleware(req: Request, res: Response, next: NextFunction) {
  const token = req.cookies.session_token;

  if (token) {
    const tokenHash = createHash('sha256').update(token).digest('hex');

    // Update last active (debounced - only once per minute)
    const cacheKey = `session_activity:${tokenHash}`;
    if (!cache.get(cacheKey)) {
      cache.set(cacheKey, true, 60); // 60 second TTL
      updateSessionActivity(tokenHash).catch(console.error);
    }
  }

  next();
}
```

## Token Refresh Pattern

```typescript
// lib/tokens.ts
import jwt from 'jsonwebtoken';

const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY = '7d';

export function generateTokens(userId: string) {
  const accessToken = jwt.sign(
    { userId, type: 'access' },
    process.env.JWT_SECRET!,
    { expiresIn: ACCESS_TOKEN_EXPIRY }
  );

  const refreshToken = jwt.sign(
    { userId, type: 'refresh' },
    process.env.JWT_REFRESH_SECRET!,
    { expiresIn: REFRESH_TOKEN_EXPIRY }
  );

  return { accessToken, refreshToken };
}

export async function refreshAccessToken(refreshToken: string) {
  try {
    const payload = jwt.verify(
      refreshToken,
      process.env.JWT_REFRESH_SECRET!
    ) as { userId: string; type: string };

    if (payload.type !== 'refresh') {
      throw new UnauthorizedError('Invalid token type');
    }

    // Check if refresh token is revoked
    const isRevoked = await db.revokedToken.findUnique({
      where: { token: refreshToken },
    });

    if (isRevoked) {
      throw new UnauthorizedError('Token revoked');
    }

    // Generate new access token
    const accessToken = jwt.sign(
      { userId: payload.userId, type: 'access' },
      process.env.JWT_SECRET!,
      { expiresIn: ACCESS_TOKEN_EXPIRY }
    );

    return { accessToken };
  } catch (error) {
    throw new UnauthorizedError('Invalid refresh token');
  }
}
```

## Logout and Session Invalidation

```typescript
// Server action for logout
'use server';

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

export async function logout() {
  const cookieStore = cookies();

  // Clear session cookie
  cookieStore.delete('session');

  // If using refresh tokens, revoke them
  const refreshToken = cookieStore.get('refresh_token')?.value;
  if (refreshToken) {
    await db.revokedToken.create({
      data: {
        token: refreshToken,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });
    cookieStore.delete('refresh_token');
  }

  redirect('/login');
}

// Logout all sessions
export async function logoutAllSessions(userId: string) {
  // Increment token version to invalidate all existing tokens
  await db.user.update({
    where: { id: userId },
    data: { tokenVersion: { increment: 1 } },
  });

  // Delete all refresh tokens for user
  await db.refreshToken.deleteMany({
    where: { userId },
  });
}
```

## CSRF Protection

```typescript
// lib/csrf.ts
import { randomBytes } from 'crypto';

export function generateCsrfToken(): string {
  return randomBytes(32).toString('hex');
}

export function validateCsrfToken(
  sessionToken: string,
  requestToken: string
): boolean {
  return sessionToken === requestToken;
}

// Usage in form
<form action={submitAction}>
  <input type="hidden" name="csrf_token" value={csrfToken} />
  {/* form fields */}
</form>

// Validation in action
export async function submitAction(formData: FormData) {
  const csrfToken = formData.get('csrf_token');
  const sessionCsrf = cookies().get('csrf_token')?.value;

  if (!validateCsrfToken(sessionCsrf!, csrfToken as string)) {
    throw new ForbiddenError('Invalid CSRF token');
  }

  // Process form
}
```

## Troubleshooting

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `Account locked` | Too many failed attempts | Wait for lockout period or admin unlock |
| `Invalid MFA code` | Wrong code or clock drift | Sync device time, try backup code |
| `Session expired` | Token TTL exceeded | Re-authenticate |
| `Invalid refresh token` | Token revoked or expired | Full re-authentication required |
| `CSRF token invalid` | Token mismatch or missing | Refresh page, check cookie settings |

### Security Audit Checklist

```sql
-- Check for accounts without MFA
SELECT id, email FROM users WHERE mfa_enabled = FALSE;

-- Check for locked accounts
SELECT id, email, locked_until FROM users WHERE locked_until > NOW();

-- Check for suspicious login patterns
SELECT email, COUNT(*) as failed_attempts
FROM login_attempts
WHERE success = FALSE AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY email
HAVING COUNT(*) > 5
ORDER BY failed_attempts DESC;

-- Check for sessions from unusual locations
SELECT u.email, s.location, s.ip_address, s.last_active_at
FROM user_sessions s
JOIN users u ON s.user_id = u.id
WHERE s.location NOT IN (SELECT DISTINCT location FROM user_sessions WHERE user_id = s.user_id ORDER BY created_at LIMIT 3)
ORDER BY s.last_active_at DESC;
```

## Related Templates

- See `rls-security` for database-level access control
- See `api-patterns` for protected API routes
- See `logging-patterns` for security event logging
- See `error-handling` for auth error management

## Checklist

### Authentication
- [ ] Secure password hashing (bcrypt with 12+ rounds)
- [ ] Session or JWT strategy chosen appropriately
- [ ] Token expiration configured
- [ ] Refresh token rotation implemented
- [ ] Logout invalidates tokens

### Password Security
- [ ] Password reset with secure, time-limited tokens
- [ ] Password strength requirements enforced
- [ ] Password change notifications sent
- [ ] Bcrypt or Argon2 for hashing

### Account Protection
- [ ] Account lockout after failed attempts (5 attempts)
- [ ] IP-based rate limiting
- [ ] Login attempt logging
- [ ] Security alert emails for suspicious activity

### Multi-Factor Authentication
- [ ] TOTP-based MFA option
- [ ] Backup codes generated and hashed
- [ ] MFA required for sensitive operations
- [ ] MFA setup requires password verification

### Session Management
- [ ] Device tracking and identification
- [ ] New device login alerts
- [ ] View and revoke active sessions
- [ ] Session activity tracking

### Authorization
- [ ] Role-based access control defined
- [ ] Permission checks on all protected routes
- [ ] Server-side validation (not just client)
- [ ] Admin routes protected

### Security
- [ ] CSRF protection enabled
- [ ] Secure cookies (HttpOnly, Secure, SameSite)
- [ ] Rate limiting on auth endpoints
- [ ] Security headers configured
- [ ] Audit logging for auth events

### OAuth
- [ ] State parameter for CSRF
- [ ] PKCE for public clients
- [ ] Scope minimized
- [ ] Token storage secure

## Rules

1. **Hash Everything**: Never store plaintext passwords, tokens, or secrets
2. **Time-Limit Tokens**: All tokens must expire - reset tokens: 1 hour, sessions: 30 days max
3. **Log Security Events**: Log all auth attempts, password changes, session changes
4. **Alert Users**: Email on password change, new device, account lock
5. **Defense in Depth**: Multiple layers - rate limiting + lockout + MFA
6. **Fail Secure**: On error, deny access rather than grant it

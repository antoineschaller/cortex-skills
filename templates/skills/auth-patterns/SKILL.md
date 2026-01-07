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

## Checklist

### Authentication
- [ ] Secure password hashing (bcrypt, argon2)
- [ ] Session or JWT strategy chosen appropriately
- [ ] Token expiration configured
- [ ] Refresh token rotation implemented
- [ ] Logout invalidates tokens

### Authorization
- [ ] Role-based access control defined
- [ ] Permission checks on all protected routes
- [ ] Server-side validation (not just client)
- [ ] Admin routes protected

### Security
- [ ] CSRF protection enabled
- [ ] Secure cookies (HttpOnly, Secure, SameSite)
- [ ] Rate limiting on auth endpoints
- [ ] Account lockout after failed attempts
- [ ] Password strength requirements

### OAuth
- [ ] State parameter for CSRF
- [ ] PKCE for public clients
- [ ] Scope minimized
- [ ] Token storage secure

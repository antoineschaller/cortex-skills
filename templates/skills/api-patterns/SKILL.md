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

## Checklist

- [ ] Input validated with schema
- [ ] Auth check before business logic
- [ ] Proper error handling
- [ ] Consistent response format
- [ ] Path revalidation after mutations
- [ ] Logging for debugging
- [ ] Rate limiting for public endpoints

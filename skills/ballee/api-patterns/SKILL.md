---
description: Server action patterns for Ballee with auth wrappers, Zod validation, error handling, and path revalidation. Use when creating server actions, implementing API endpoints, or handling form submissions.
---

# API Patterns (Server Actions)

## Basic Server Action

```typescript
'use server';

import { withAuthParams } from '@/lib/auth-wrappers';
import { revalidatePath } from 'next/cache';
import { z } from 'zod';

const CreateItemSchema = z.object({
  name: z.string().min(1).max(100).transform(v => v.trim()),
  email: z.string().email().toLowerCase(),
});

export const createItemAction = withAuthParams(async (params, formData: FormData) => {
  // 1. Validate input
  const validated = CreateItemSchema.safeParse(Object.fromEntries(formData));
  if (!validated.success) {
    return { success: false, error: validated.error.flatten() };
  }

  // 2. Call service
  const service = new ItemService(params.client);
  const result = await service.create(validated.data);

  // 3. Revalidate on success
  if (result.success) {
    revalidatePath('/items');
  }

  return result;
});
```

## Auth Wrappers

```typescript
import { withAuth, withAuthParams, withSuperAdmin } from '@/lib/auth-wrappers';

// Requires authentication
export const simpleAction = withAuth(async () => {
  // User is authenticated
});

// Provides user, client, accountId
export const actionWithContext = withAuthParams(async (params, data) => {
  const { user, client, accountId } = params;
  const service = new ItemService(client);
  // ...
});

// Requires super admin role
export const adminOnlyAction = withSuperAdmin(async (params) => {
  // Only super admins can call this
});
```

## Zod Validation Patterns

```typescript
import { z } from 'zod';

// Basic types
const schema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  age: z.coerce.number().int().positive(),
  date: z.coerce.date(),
  optional: z.string().optional(),
  nullable: z.string().nullable(),
});

// Transformations
const cleanSchema = z.object({
  name: z.string().transform(v => v.trim()),
  email: z.string().email().toLowerCase(),
  phone: z.string().transform(v => v.replace(/\D/g, '')),
});

// Enums
const statusSchema = z.enum(['draft', 'published', 'archived']);

// Arrays
const tagsSchema = z.array(z.string()).min(1).max(10);

// Nested objects
const addressSchema = z.object({
  street: z.string(),
  city: z.string(),
  country: z.string(),
});
```

## Error Handling

```typescript
export const myAction = withAuthParams(async (params, data) => {
  // 1. Validation errors - return directly
  const validated = Schema.safeParse(data);
  if (!validated.success) {
    return { success: false, error: validated.error.flatten() };
  }

  // 2. Expected business errors - return { error }
  const service = new ItemService(params.client);
  const result = await service.create(validated.data);

  if (!result.success) {
    // Log as warning (expected)
    console.warn('Failed to create item', result.error);
    return { success: false, error: result.error.message };
  }

  // 3. Unexpected errors - let bubble up (for Sentry)
  // Don't catch unexpected errors!

  return result;
});
```

## Path Revalidation (CRITICAL)

**MANDATORY**: All server actions that mutate data MUST call `revalidatePath()` on success. This is the ONLY way to sync Server Component data after mutations.

### Why revalidatePath is Required

In Next.js App Router with Server Components:
- Pages load data via Server Components (RSC)
- Client-side TanStack Query cache is SEPARATE from RSC cache
- `queryClient.invalidateQueries()` only affects client cache
- `router.refresh()` works but causes full page re-render (700ms+)
- `revalidatePath()` invalidates RSC cache at the source (fastest, cleanest)

### Standard Pattern

```typescript
import { revalidatePath } from 'next/cache';

// After mutation, revalidate affected paths
export const updateItemAction = withAuthParams(async (params, id, data) => {
  const result = await service.update(id, data);

  if (result.success) {
    revalidatePath('/items');           // List page
    revalidatePath(`/items/${id}`);     // Detail page
  }

  return result;
});
```

### Revalidation Patterns by Entity Type

```typescript
// Admin CRUD entities (venues, clients, productions, etc.)
if (result.success) {
  revalidatePath('/admin/venues');              // List page
  revalidatePath(`/admin/venues/${id}`);        // Detail page
  revalidatePath('/admin/venues', 'layout');    // Force layout refresh if needed
}

// User-facing entities (events, assignments, etc.)
if (result.success) {
  revalidatePath('/home/events');               // User events list
  revalidatePath(`/home/events/${id}`);         // Event detail
}

// Delete operations - only list page
if (result.success) {
  revalidatePath('/admin/items');  // List page only (detail no longer exists)
}
```

### Integration with TanStack Query Mutations

When server actions use `revalidatePath()`, client-side TanStack Query hooks become simpler:

```typescript
// ✅ CORRECT - Server action handles revalidation
// apps/web/app/admin/items/_lib/server/actions.ts
export const createItemAction = withAuthParams(async (params, data) => {
  const result = await service.create(data);
  if (result.success) {
    revalidatePath('/admin/items');  // RSC cache invalidated at source
  }
  return result;
});

// ✅ CORRECT - Hook for optimistic UI only, no router.refresh() needed
// apps/web/app/admin/items/_lib/hooks/use-item-mutations.ts
const createMutation = useMutation({
  mutationFn: createItemAction,
  onSuccess: () => {
    // Optional: Invalidate client cache for components using useQuery
    queryClient.invalidateQueries({ queryKey: ['items'] });
    toast.success('Created');
    // NO router.refresh() - server action already revalidated!
  },
});
```

### Anti-Patterns

```typescript
// ❌ WRONG - No revalidation in server action
export const createItemAction = withAuthParams(async (params, data) => {
  const result = await service.create(data);
  return result;  // Missing revalidatePath!
});

// ❌ WRONG - Using router.refresh() instead of revalidatePath
// in client hook
onSuccess: () => {
  router.refresh();  // 700ms+ full page reload, use revalidatePath in action instead
};

// ❌ WRONG - Relying only on queryClient.invalidateQueries()
onSuccess: () => {
  queryClient.invalidateQueries({ queryKey: ['items'] });  // Only affects client cache!
};
```

### Checklist for Server Actions

- [ ] Import `revalidatePath` from `'next/cache'`
- [ ] Call `revalidatePath()` after successful mutations (create, update, delete)
- [ ] Revalidate list page path
- [ ] Revalidate detail page path (for create/update)
- [ ] Test that UI updates without requiring `router.refresh()` in client

## Form Data Handling

```typescript
// From FormData
export const formAction = withAuthParams(async (params, formData: FormData) => {
  const data = Object.fromEntries(formData);
  const validated = Schema.safeParse(data);
  // ...
});

// From JSON (client component)
export const jsonAction = withAuthParams(async (params, data: ItemInput) => {
  const validated = Schema.safeParse(data);
  // ...
});

// File uploads
export const uploadAction = withAuthParams(async (params, formData: FormData) => {
  const file = formData.get('file') as File;
  if (!file) {
    return { success: false, error: 'No file provided' };
  }

  const { data, error } = await params.client.storage
    .from('uploads')
    .upload(`${params.user.id}/${file.name}`, file);

  if (error) {
    return { success: false, error: error.message };
  }

  return { success: true, data: { path: data.path } };
});
```

## Action Response Types

```typescript
// Success with data
return { success: true, data: result };

// Error with message
return { success: false, error: 'Something went wrong' };

// Validation errors (Zod)
return { success: false, error: validated.error.flatten() };

// Redirect (use with caution)
import { redirect } from 'next/navigation';
redirect('/success'); // Throws - handle with isRedirectError
```

## Using Actions in Components

```typescript
'use client';

import { createItemAction } from './actions';
import { toast } from '@kit/ui/sonner';

export function CreateForm() {
  const handleSubmit = async (formData: FormData) => {
    const result = await createItemAction(formData);

    if (result.success) {
      toast.success('Created');
    } else {
      toast.error(result.error);
    }
  };

  return (
    <form action={handleSubmit}>
      <input name="name" />
      <button type="submit">Create</button>
    </form>
  );
}
```

## PDF Generation (API Routes)

**CRITICAL**: Never use Server Actions for PDF generation with `@react-pdf/renderer`. Use API Routes instead.

### Why API Routes for PDFs?

Server Actions with `@react-pdf/renderer` cause `hasOwnProperty` errors in React 19 due to how Supabase objects are serialized. API Routes isolate PDF rendering and stream binary data directly.

### PDF API Route Pattern

```typescript
// app/api/pdf/[type]/route.ts
import React from 'react';
import { NextRequest, NextResponse } from 'next/server';
import type { DocumentProps } from '@react-pdf/renderer';
import { renderToStream } from '@react-pdf/renderer';
import { z } from 'zod';

import { getLogger } from '@kit/shared/logger';
import { getSupabaseServerClient } from '@kit/supabase/server-client';

import { MyPdfTemplate } from '@kit/my-feature/templates/pdf/my-template';

/**
 * Convert Node.js ReadableStream to Web ReadableStream
 * Required for Next.js API routes to stream responses
 */
function nodeStreamToWebStream(
  nodeStream: NodeJS.ReadableStream,
): ReadableStream<Uint8Array> {
  return new ReadableStream({
    start(controller) {
      nodeStream.on('data', (chunk: Buffer) => {
        controller.enqueue(new Uint8Array(chunk));
      });
      nodeStream.on('end', () => {
        controller.close();
      });
      nodeStream.on('error', (error) => {
        controller.error(error);
      });
    },
  });
}

/**
 * Deep sanitize objects for @react-pdf/renderer
 * Removes undefined values and converts to plain objects
 */
function sanitizeForPdf<T>(obj: T): T {
  if (obj === undefined) return null as T;
  if (obj === null) return null as T;
  if (typeof obj !== 'object') return obj;
  if (obj instanceof Date) return obj.toISOString() as T;

  if (Array.isArray(obj)) {
    return obj
      .filter((item) => item != null)
      .map((item) => sanitizeForPdf(item)) as T;
  }

  try {
    const cleaned: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
      if (value !== undefined) {
        cleaned[key] = sanitizeForPdf(value);
      }
    }
    return JSON.parse(JSON.stringify(cleaned)) as T;
  } catch {
    return {} as T;
  }
}

export async function GET(request: NextRequest) {
  const logger = await getLogger();

  try {
    // 1. Authenticate
    const client = getSupabaseServerClient();
    const { data: { user }, error: authError } = await client.auth.getUser();

    if (authError || !user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // 2. Validate input
    const { searchParams } = new URL(request.url);
    const id = searchParams.get('id');
    // ... validation

    // 3. Fetch data
    const data = await fetchData(client, id);

    // 4. Sanitize for PDF (CRITICAL!)
    const safeData = sanitizeForPdf(data);

    // 5. Create PDF document
    const document = MyPdfTemplate({ data: safeData });

    // 6. Render to stream (memory efficient)
    const pdfStream = await renderToStream(
      document as React.ReactElement<DocumentProps>,
    );

    // 7. Convert Node stream to Web stream
    const webStream = nodeStreamToWebStream(pdfStream);

    // 8. Return streaming response
    return new Response(webStream, {
      status: 200,
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Cache-Control': 'private, no-cache, no-store, must-revalidate',
      },
    });
  } catch (error) {
    logger.error({ error }, 'PDF generation failed');
    return NextResponse.json(
      { error: 'Failed to generate PDF' },
      { status: 500 },
    );
  }
}
```

### Client-Side PDF Download

```typescript
// lib/pdf-download.ts
export async function downloadPDF(url: string): Promise<DownloadResult> {
  const response = await fetch(url, {
    method: 'GET',
    credentials: 'include',
  });

  if (!response.ok) {
    const contentType = response.headers.get('content-type');
    if (contentType?.includes('application/json')) {
      const errorData = await response.json();
      return { success: false, error: errorData.error };
    }
    return { success: false, error: `HTTP ${response.status}` };
  }

  // Get filename from header
  let filename = 'document.pdf';
  const contentDisposition = response.headers.get('content-disposition');
  if (contentDisposition) {
    const match = contentDisposition.match(/filename="?([^";\n]+)"?/);
    if (match) filename = match[1] ?? filename;
  }

  // Trigger download
  const blob = await response.blob();
  const blobUrl = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = blobUrl;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(blobUrl);

  return { success: true, filename };
}
```

### PDF Architecture Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| **Streaming API Route** | Direct download | Hire orders, resumes |
| **Storage-based** | Save for later access | Invoices |

### Existing PDF Routes

- `/api/pdf/hire-order` - Admin hire order PDFs
- `/api/pdf/resume` - Dancer resume/CV PDFs

### Anti-Patterns

```typescript
// ❌ WRONG - Server Action with @react-pdf/renderer
'use server';
import { renderToBuffer } from '@react-pdf/renderer';
export async function generatePdfAction() {
  const buffer = await renderToBuffer(<MyPdf data={supabaseData} />);
  return buffer.toString('base64'); // hasOwnProperty error!
}

// ✅ CORRECT - API Route with sanitization
export async function GET() {
  const safeData = sanitizeForPdf(supabaseData);
  const stream = await renderToStream(<MyPdf data={safeData} />);
  return new Response(nodeStreamToWebStream(stream));
}
```

## Rules

1. **'use server'** - Always at top of file
2. **Auth wrapper** - Always use appropriate wrapper
3. **Validate first** - Zod validation before business logic
4. **Return errors** - Don't throw expected errors
5. **Revalidate paths** - After successful mutations
6. **Log appropriately** - warn for expected, error for unexpected
7. **API Routes for PDFs** - Never use Server Actions with @react-pdf/renderer
8. **Sanitize for PDF** - Always use `sanitizeForPdf()` on Supabase data

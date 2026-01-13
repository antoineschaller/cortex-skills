# Patterns Library

Common architectural patterns for building production-grade applications, covering service layer, server actions, component architecture, data access, and performance optimization.

## Table of Contents

- [Service Layer Patterns](#service-layer-patterns)
- [Server Actions](#server-actions)
- [Component Architecture](#component-architecture)
- [Data Access Patterns](#data-access-patterns)
- [Performance Patterns](#performance-patterns)
- [Error Handling](#error-handling)

## Service Layer Patterns

### Result Pattern (No Exceptions)

**Purpose**: Explicit error handling without throwing exceptions.

```typescript
// types/result.ts
export type Result<T, E = Error> =
  | { success: true; data: T }
  | { success: false; error: E };

export type ServiceError = {
  code: string;
  message: string;
  details?: Record<string, any>;
};
```

**BaseService Implementation**:
```typescript
// lib/services/base-service.ts
import { SupabaseClient } from '@supabase/supabase-js';
import { Result, ServiceError } from '@/types/result';
import { Logger } from '@kit/shared/logger';

export abstract class BaseService<TRow, TInsert, TUpdate> {
  protected readonly client: SupabaseClient;
  protected readonly logger: Logger;
  protected abstract readonly tableName: string;

  constructor(client: SupabaseClient) {
    this.client = client;
    this.logger = new Logger(this.constructor.name);
  }

  async findById(id: string): Promise<Result<TRow | null, ServiceError>> {
    try {
      const { data, error } = await this.client
        .from(this.tableName)
        .select('*')
        .eq('id', id)
        .maybeSingle();

      if (error) {
        this.logger.error('findById failed', { error, id });
        return {
          success: false,
          error: { code: 'FIND_BY_ID_FAILED', message: error.message },
        };
      }

      return { success: true, data };
    } catch (error) {
      this.logger.error('findById exception', { error, id });
      return {
        success: false,
        error: { code: 'UNEXPECTED_ERROR', message: 'An unexpected error occurred' },
      };
    }
  }

  async findMany(filters?: Record<string, any>): Promise<Result<TRow[], ServiceError>> {
    try {
      let query = this.client.from(this.tableName).select('*');

      if (filters) {
        Object.entries(filters).forEach(([key, value]) => {
          query = query.eq(key, value);
        });
      }

      const { data, error } = await query;

      if (error) {
        this.logger.error('findMany failed', { error, filters });
        return {
          success: false,
          error: { code: 'FIND_MANY_FAILED', message: error.message },
        };
      }

      return { success: true, data: data || [] };
    } catch (error) {
      this.logger.error('findMany exception', { error, filters });
      return {
        success: false,
        error: { code: 'UNEXPECTED_ERROR', message: 'An unexpected error occurred' },
      };
    }
  }

  async create(data: TInsert): Promise<Result<TRow, ServiceError>> {
    try {
      const { data: result, error } = await this.client
        .from(this.tableName)
        .insert(data)
        .select()
        .single();

      if (error) {
        this.logger.error('create failed', { error, data });
        return {
          success: false,
          error: { code: 'CREATE_FAILED', message: error.message },
        };
      }

      this.logger.info('create succeeded', { id: result.id });
      return { success: true, data: result };
    } catch (error) {
      this.logger.error('create exception', { error, data });
      return {
        success: false,
        error: { code: 'UNEXPECTED_ERROR', message: 'An unexpected error occurred' },
      };
    }
  }

  async update(id: string, data: TUpdate): Promise<Result<TRow, ServiceError>> {
    try {
      const { data: result, error } = await this.client
        .from(this.tableName)
        .update(data)
        .eq('id', id)
        .select()
        .single();

      if (error) {
        this.logger.error('update failed', { error, id, data });
        return {
          success: false,
          error: { code: 'UPDATE_FAILED', message: error.message },
        };
      }

      this.logger.info('update succeeded', { id });
      return { success: true, data: result };
    } catch (error) {
      this.logger.error('update exception', { error, id, data });
      return {
        success: false,
        error: { code: 'UNEXPECTED_ERROR', message: 'An unexpected error occurred' },
      };
    }
  }

  async delete(id: string): Promise<Result<void, ServiceError>> {
    try {
      const { error } = await this.client
        .from(this.tableName)
        .delete()
        .eq('id', id);

      if (error) {
        this.logger.error('delete failed', { error, id });
        return {
          success: false,
          error: { code: 'DELETE_FAILED', message: error.message },
        };
      }

      this.logger.info('delete succeeded', { id });
      return { success: true, data: undefined };
    } catch (error) {
      this.logger.error('delete exception', { error, id });
      return {
        success: false,
        error: { code: 'UNEXPECTED_ERROR', message: 'An unexpected error occurred' },
      };
    }
  }
}
```

**Concrete Service**:
```typescript
// lib/services/event-service.ts
import { BaseService } from './base-service';
import type { Database } from '@/lib/database.types';

type EventRow = Database['public']['Tables']['events']['Row'];
type EventInsert = Database['public']['Tables']['events']['Insert'];
type EventUpdate = Database['public']['Tables']['events']['Update'];

export class EventService extends BaseService<EventRow, EventInsert, EventUpdate> {
  protected readonly tableName = 'events';

  async findByAccountId(accountId: string) {
    return this.findMany({ account_id: accountId });
  }

  async findUpcoming() {
    try {
      const { data, error } = await this.client
        .from(this.tableName)
        .select('*')
        .gte('start_date', new Date().toISOString())
        .order('start_date', { ascending: true });

      if (error) {
        return { success: false, error: { code: 'FIND_UPCOMING_FAILED', message: error.message } };
      }

      return { success: true, data: data || [] };
    } catch (error) {
      return { success: false, error: { code: 'UNEXPECTED_ERROR', message: 'An unexpected error occurred' } };
    }
  }
}
```

**Usage**:
```typescript
export async function getEvents(accountId: string) {
  const client = getSupabaseServerClient();
  const service = new EventService(client);

  const result = await service.findByAccountId(accountId);

  if (!result.success) {
    // Handle error gracefully
    return { events: [], error: result.error.message };
  }

  return { events: result.data };
}
```

## Server Actions

### withAuthParams Pattern

**Purpose**: Inject auth context into server actions with type safety.

```typescript
'use server';

import { withAuthParams } from '@/lib/auth-wrappers';
import { revalidatePath } from 'next/cache';
import { z } from 'zod';

const CreateEventSchema = z.object({
  name: z.string().min(1).max(200).transform(v => v.trim()),
  start_date: z.coerce.date(),
  end_date: z.coerce.date(),
  location: z.string().min(1),
  description: z.string().optional(),
});

export const createEventAction = withAuthParams(async (params, formData: FormData) => {
  // 1. Validate input
  const validated = CreateEventSchema.safeParse(Object.fromEntries(formData));

  if (!validated.success) {
    return {
      success: false,
      error: validated.error.flatten().fieldErrors,
    };
  }

  // 2. Business logic validation
  if (validated.data.end_date <= validated.data.start_date) {
    return {
      success: false,
      error: { end_date: ['End date must be after start date'] },
    };
  }

  // 3. Create via service
  const service = new EventService(params.client);

  const result = await service.create({
    ...validated.data,
    account_id: params.accountId,
    created_by: params.user.id,
  });

  if (!result.success) {
    return { success: false, error: { _form: [result.error.message] } };
  }

  // 4. Revalidate cache
  revalidatePath('/events');
  revalidatePath(`/events/${result.data.id}`);

  // 5. Return success
  return { success: true, data: result.data };
});
```

### Optimistic Updates

**Pattern for instant UI feedback**:

```typescript
'use client';

import { useOptimistic } from 'react';
import { toggleEventStatusAction } from './actions';

export function EventCard({ event }: { event: Event }) {
  const [optimisticEvent, setOptimisticEvent] = useOptimistic(
    event,
    (state, newStatus: 'published' | 'draft') => ({
      ...state,
      status: newStatus,
    })
  );

  async function handleToggle() {
    // Optimistic update (instant UI feedback)
    setOptimisticEvent(optimisticEvent.status === 'published' ? 'draft' : 'published');

    // Server action
    await toggleEventStatusAction(event.id);
  }

  return (
    <div>
      <h3>{optimisticEvent.name}</h3>
      <p>Status: {optimisticEvent.status}</p>
      <button onClick={handleToggle}>Toggle Status</button>
    </div>
  );
}
```

### Pagination Pattern

```typescript
'use server';

import { withAuthParams } from '@/lib/auth-wrappers';

export const getEventsPaginated = withAuthParams(
  async (params, page: number = 1, pageSize: number = 10) => {
    const offset = (page - 1) * pageSize;

    const service = new EventService(params.client);

    // Get total count
    const { count } = await params.client
      .from('events')
      .select('*', { count: 'exact', head: true })
      .eq('account_id', params.accountId);

    // Get paginated data
    const { data, error } = await params.client
      .from('events')
      .select('*')
      .eq('account_id', params.accountId)
      .range(offset, offset + pageSize - 1)
      .order('created_at', { ascending: false });

    if (error) {
      return { success: false, error: error.message };
    }

    return {
      success: true,
      data: {
        events: data,
        pagination: {
          page,
          pageSize,
          totalCount: count || 0,
          totalPages: Math.ceil((count || 0) / pageSize),
        },
      },
    };
  }
);
```

## Component Architecture

### Server vs Client Components

**Decision Tree**:
```
Does component need interactivity (onClick, useState)?
├─ Yes → Client Component ('use client')
└─ No → Continue...

Does component fetch data from database?
├─ Yes → Server Component (default)
└─ No → Continue...

Does component use browser APIs (localStorage, window)?
├─ Yes → Client Component
└─ No → Server Component (default, better performance)
```

**Server Component** (default):
```typescript
// app/events/page.tsx
import { getSupabaseServerClient } from '@kit/supabase/server-client';
import { EventList } from './_components/event-list';

export default async function EventsPage() {
  const client = getSupabaseServerClient();

  // Direct data fetching (RLS protects data)
  const { data: events } = await client
    .from('events')
    .select('*')
    .order('start_date', { ascending: true });

  return (
    <div>
      <h1>Events</h1>
      <EventList events={events || []} />
    </div>
  );
}
```

**Client Component** (with interactivity):
```typescript
'use client';

import { useState } from 'react';
import { Button } from '@kit/ui/button';

export function EventList({ events }: { events: Event[] }) {
  const [filter, setFilter] = useState<'all' | 'upcoming'>('all');

  const filteredEvents = events.filter(event => {
    if (filter === 'upcoming') {
      return new Date(event.start_date) > new Date();
    }
    return true;
  });

  return (
    <div>
      <div className="flex gap-2 mb-4">
        <Button onClick={() => setFilter('all')}>All</Button>
        <Button onClick={() => setFilter('upcoming')}>Upcoming</Button>
      </div>

      {filteredEvents.map(event => (
        <EventCard key={event.id} event={event} />
      ))}
    </div>
  );
}
```

### Async Params (Next.js 15+)

**Pattern**: Await params directly in async functions.

✅ **Correct**:
```typescript
// app/events/[id]/page.tsx
type Props = {
  params: Promise<{ id: string }>;
};

export default async function EventPage({ params }: Props) {
  const { id } = await params; // Await params directly

  const event = await getEvent(id);

  return <EventDetails event={event} />;
}
```

❌ **Wrong**:
```typescript
import { use } from 'react';

export default async function EventPage({ params }: Props) {
  const { id } = use(params); // Don't use React.use() in async functions
  // ...
}
```

### Component Composition

**Pattern**: Small, focused components with composition.

```typescript
// components/event-card.tsx
export function EventCard({ event }: { event: Event }) {
  return (
    <Card>
      <EventCard.Header event={event} />
      <EventCard.Body event={event} />
      <EventCard.Footer event={event} />
    </Card>
  );
}

EventCard.Header = function EventCardHeader({ event }: { event: Event }) {
  return (
    <CardHeader>
      <CardTitle>{event.name}</CardTitle>
      <CardDescription>{formatDate(event.start_date)}</CardDescription>
    </CardHeader>
  );
};

EventCard.Body = function EventCardBody({ event }: { event: Event }) {
  return (
    <CardContent>
      <p>{event.description}</p>
      <EventCard.Tags tags={event.tags} />
    </CardContent>
  );
};

EventCard.Footer = function EventCardFooter({ event }: { event: Event }) {
  return (
    <CardFooter>
      <EventCard.Actions eventId={event.id} />
    </CardFooter>
  );
};

EventCard.Tags = function EventCardTags({ tags }: { tags: string[] }) {
  return (
    <div className="flex gap-2">
      {tags.map(tag => (
        <Badge key={tag}>{tag}</Badge>
      ))}
    </div>
  );
};

EventCard.Actions = function EventCardActions({ eventId }: { eventId: string }) {
  return (
    <div className="flex gap-2">
      <Button variant="outline" asChild>
        <Link href={`/events/${eventId}`}>View</Link>
      </Button>
      <Button variant="outline" asChild>
        <Link href={`/events/${eventId}/edit`}>Edit</Link>
      </Button>
    </div>
  );
};
```

## Data Access Patterns

### Data Isolation

**account_id vs client_id**:

```typescript
// Workspace-based (team collaboration)
// Use account_id for data owned by a team/workspace
type Event = {
  id: string;
  account_id: string; // Multiple users can access
  name: string;
};

// Client-based (external organizations)
// Use client_id for data owned by external entities
type Production = {
  id: string;
  client_id: string; // Fever, other partners
  name: string;
};

// User-based (personal data)
// Use user_id for data owned by individual users
type Profile = {
  id: string;
  user_id: string; // Only this user can access
  bio: string;
};
```

**RLS Policies**:
```sql
-- Account-based (users in account can access)
CREATE POLICY "Users can access account events"
ON events FOR SELECT
USING (
  account_id IN (
    SELECT account_id FROM account_users WHERE user_id = auth.uid()
  )
);

-- Client-based (super admin only)
CREATE POLICY "Super admin can access client data"
ON productions FOR SELECT
USING (is_super_admin());

-- User-based (only owner)
CREATE POLICY "Users can access own profile"
ON profiles FOR SELECT
USING (user_id = auth.uid());
```

### Soft Delete Pattern

**Schema**:
```sql
ALTER TABLE events ADD COLUMN deleted_at TIMESTAMPTZ;

CREATE INDEX idx_events_not_deleted ON events(id) WHERE deleted_at IS NULL;
```

**Service Method**:
```typescript
export class EventService extends BaseService<EventRow, EventInsert, EventUpdate> {
  // Override delete to use soft delete
  async delete(id: string): Promise<Result<void, ServiceError>> {
    return this.update(id, {
      deleted_at: new Date().toISOString(),
    } as EventUpdate);
  }

  // Add method to exclude soft deleted
  async findManyActive(filters?: Record<string, any>) {
    try {
      let query = this.client
        .from(this.tableName)
        .select('*')
        .is('deleted_at', null); // Only active records

      if (filters) {
        Object.entries(filters).forEach(([key, value]) => {
          query = query.eq(key, value);
        });
      }

      const { data, error } = await query;

      if (error) {
        return { success: false, error: { code: 'FIND_MANY_FAILED', message: error.message } };
      }

      return { success: true, data: data || [] };
    } catch (error) {
      return { success: false, error: { code: 'UNEXPECTED_ERROR', message: 'An unexpected error occurred' } };
    }
  }

  // Hard delete (admin only)
  async hardDelete(id: string): Promise<Result<void, ServiceError>> {
    return super.delete(id);
  }
}
```

### Batch Operations

**Avoid N+1 Queries**:

❌ **Bad** (N+1 queries):
```typescript
const events = await getEvents();

for (const event of events) {
  const attendees = await getAttendees(event.id); // N queries!
  event.attendeeCount = attendees.length;
}
```

✅ **Good** (batch query):
```typescript
const events = await getEvents();
const eventIds = events.map(e => e.id);

// Single query for all attendees
const { data: attendees } = await client
  .from('attendees')
  .select('event_id')
  .in('event_id', eventIds);

// In-memory aggregation
const attendeeCounts = attendees.reduce((acc, a) => {
  acc[a.event_id] = (acc[a.event_id] || 0) + 1;
  return acc;
}, {} as Record<string, number>);

// Attach counts
events.forEach(event => {
  event.attendeeCount = attendeeCounts[event.id] || 0;
});
```

## Performance Patterns

### Parallel Data Fetching

❌ **Sequential** (slow):
```typescript
const user = await getUser();
const events = await getEvents();
const notifications = await getNotifications();
// Total: time(user) + time(events) + time(notifications)
```

✅ **Parallel** (fast):
```typescript
const [user, events, notifications] = await Promise.all([
  getUser(),
  getEvents(),
  getNotifications(),
]);
// Total: max(time(user), time(events), time(notifications))
```

### Query Optimization

**Select Only Needed Columns**:
```typescript
// ❌ Bad: Select all columns
const { data } = await client.from('events').select('*');

// ✅ Good: Select only needed columns
const { data } = await client
  .from('events')
  .select('id, name, start_date, location');
```

**Use Indexes**:
```sql
-- Frequent query: events by account and date range
CREATE INDEX idx_events_account_date
ON events(account_id, start_date)
WHERE deleted_at IS NULL;
```

### Caching with React Cache

```typescript
import { cache } from 'react';

export const getEvent = cache(async (id: string) => {
  const client = getSupabaseServerClient();

  const { data } = await client
    .from('events')
    .select('*')
    .eq('id', id)
    .single();

  return data;
});

// Called multiple times in same request, but only executes once
```

### Memoization for Expensive Calculations

```typescript
import { useMemo } from 'react';

export function EventStats({ events }: { events: Event[] }) {
  const stats = useMemo(() => {
    return {
      total: events.length,
      upcoming: events.filter(e => new Date(e.start_date) > new Date()).length,
      past: events.filter(e => new Date(e.start_date) <= new Date()).length,
      revenue: events.reduce((sum, e) => sum + (e.revenue || 0), 0),
    };
  }, [events]); // Only recalculate when events change

  return (
    <div>
      <p>Total: {stats.total}</p>
      <p>Upcoming: {stats.upcoming}</p>
      <p>Past: {stats.past}</p>
      <p>Revenue: ${stats.revenue}</p>
    </div>
  );
}
```

## Error Handling

### Global Error Boundary

```typescript
// app/error.tsx
'use client';

import { useEffect } from 'react';
import { Button } from '@kit/ui/button';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error('Error:', error);
  }, [error]);

  return (
    <div className="flex flex-col items-center justify-center min-h-screen">
      <h2 className="text-2xl font-bold mb-4">Something went wrong!</h2>
      <p className="text-gray-600 mb-4">{error.message}</p>
      <Button onClick={reset}>Try again</Button>
    </div>
  );
}
```

### Form Error Handling

```typescript
'use client';

import { useFormState } from 'react-dom';
import { createEventAction } from './actions';

export function CreateEventForm() {
  const [state, formAction] = useFormState(createEventAction, null);

  return (
    <form action={formAction}>
      <input name="name" required />
      {state?.error?.name && (
        <p className="text-red-500 text-sm">{state.error.name[0]}</p>
      )}

      <input name="start_date" type="date" required />
      {state?.error?.start_date && (
        <p className="text-red-500 text-sm">{state.error.start_date[0]}</p>
      )}

      {state?.error?._form && (
        <p className="text-red-500">{state.error._form[0]}</p>
      )}

      <button type="submit">Create Event</button>
    </form>
  );
}
```

### Toast Notifications for Errors

```typescript
'use client';

import { toast } from 'sonner';
import { deleteEventAction } from './actions';

export function DeleteButton({ eventId }: { eventId: string }) {
  async function handleDelete() {
    const result = await deleteEventAction(eventId);

    if (!result.success) {
      toast.error('Failed to delete event', {
        description: result.error,
      });
      return;
    }

    toast.success('Event deleted successfully');
  }

  return (
    <button onClick={handleDelete} className="text-red-600">
      Delete
    </button>
  );
}
```

---

**Last Updated**: 2026-01-13
**Related**: [SERVICE_PATTERNS](https://github.com/antoineschaller/cortex-skills/tree/main/skills/ballee/service-patterns), [SECURITY_GUIDE.md](SECURITY_GUIDE.md)

# State Management Patterns

Client-side state management patterns for modern applications.

> **Template Usage:** Customize for your state library (React Query, Zustand, Jotai, Redux, etc.).

## State Categories

| Type | Description | Solution |
|------|-------------|----------|
| **Server State** | Data from API/database | React Query, SWR |
| **Client State** | UI state, user preferences | Zustand, Jotai, useState |
| **Form State** | Form inputs, validation | React Hook Form, Formik |
| **URL State** | Search params, filters | nuqs, useSearchParams |

## Server State (React Query)

```typescript
// lib/queries.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

// Query keys factory
export const queryKeys = {
  users: {
    all: ['users'] as const,
    lists: () => [...queryKeys.users.all, 'list'] as const,
    list: (filters: UserFilters) => [...queryKeys.users.lists(), filters] as const,
    details: () => [...queryKeys.users.all, 'detail'] as const,
    detail: (id: string) => [...queryKeys.users.details(), id] as const,
  },
  posts: {
    all: ['posts'] as const,
    byUser: (userId: string) => [...queryKeys.posts.all, 'user', userId] as const,
  },
};

// Fetch hook
export function useUser(id: string) {
  return useQuery({
    queryKey: queryKeys.users.detail(id),
    queryFn: () => fetchUser(id),
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 30 * 60 * 1000,   // 30 minutes (formerly cacheTime)
  });
}

// List with filters
export function useUsers(filters: UserFilters) {
  return useQuery({
    queryKey: queryKeys.users.list(filters),
    queryFn: () => fetchUsers(filters),
    placeholderData: (previousData) => previousData, // Keep previous while loading
  });
}

// Mutation with optimistic update
export function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: UpdateUserInput) => updateUser(data),

    // Optimistic update
    onMutate: async (newData) => {
      await queryClient.cancelQueries({
        queryKey: queryKeys.users.detail(newData.id)
      });

      const previousUser = queryClient.getQueryData(
        queryKeys.users.detail(newData.id)
      );

      queryClient.setQueryData(
        queryKeys.users.detail(newData.id),
        (old: User) => ({ ...old, ...newData })
      );

      return { previousUser };
    },

    // Rollback on error
    onError: (err, newData, context) => {
      queryClient.setQueryData(
        queryKeys.users.detail(newData.id),
        context?.previousUser
      );
    },

    // Refetch on success
    onSettled: (data, error, variables) => {
      queryClient.invalidateQueries({
        queryKey: queryKeys.users.detail(variables.id)
      });
    },
  });
}
```

## Client State (Zustand)

```typescript
// stores/ui-store.ts
import { create } from 'zustand';
import { persist, devtools } from 'zustand/middleware';

interface UIState {
  // State
  sidebarOpen: boolean;
  theme: 'light' | 'dark' | 'system';
  notifications: Notification[];

  // Actions
  toggleSidebar: () => void;
  setTheme: (theme: UIState['theme']) => void;
  addNotification: (notification: Notification) => void;
  removeNotification: (id: string) => void;
}

export const useUIStore = create<UIState>()(
  devtools(
    persist(
      (set) => ({
        // Initial state
        sidebarOpen: true,
        theme: 'system',
        notifications: [],

        // Actions
        toggleSidebar: () =>
          set((state) => ({ sidebarOpen: !state.sidebarOpen })),

        setTheme: (theme) => set({ theme }),

        addNotification: (notification) =>
          set((state) => ({
            notifications: [...state.notifications, notification],
          })),

        removeNotification: (id) =>
          set((state) => ({
            notifications: state.notifications.filter((n) => n.id !== id),
          })),
      }),
      {
        name: 'ui-store', // localStorage key
        partialize: (state) => ({
          // Only persist these
          theme: state.theme,
          sidebarOpen: state.sidebarOpen,
        }),
      }
    ),
    { name: 'UI Store' } // DevTools name
  )
);

// Usage
function Sidebar() {
  const { sidebarOpen, toggleSidebar } = useUIStore();

  return (
    <aside className={sidebarOpen ? 'w-64' : 'w-16'}>
      <button onClick={toggleSidebar}>Toggle</button>
    </aside>
  );
}

// Selectors for performance
const selectTheme = (state: UIState) => state.theme;

function ThemeToggle() {
  const theme = useUIStore(selectTheme);
  const setTheme = useUIStore((state) => state.setTheme);

  return (
    <select value={theme} onChange={(e) => setTheme(e.target.value)}>
      <option value="light">Light</option>
      <option value="dark">Dark</option>
      <option value="system">System</option>
    </select>
  );
}
```

## Atomic State (Jotai)

```typescript
// atoms/user.ts
import { atom } from 'jotai';
import { atomWithStorage } from 'jotai/utils';

// Basic atom
export const userAtom = atom<User | null>(null);

// Derived atom (computed)
export const isLoggedInAtom = atom(
  (get) => get(userAtom) !== null
);

// Writable derived atom
export const userNameAtom = atom(
  (get) => get(userAtom)?.name ?? '',
  (get, set, newName: string) => {
    const user = get(userAtom);
    if (user) {
      set(userAtom, { ...user, name: newName });
    }
  }
);

// Persisted atom
export const themeAtom = atomWithStorage<'light' | 'dark'>('theme', 'light');

// Async atom
export const userDataAtom = atom(async (get) => {
  const user = get(userAtom);
  if (!user) return null;
  return fetchUserData(user.id);
});

// Usage
import { useAtom, useAtomValue, useSetAtom } from 'jotai';

function UserProfile() {
  const user = useAtomValue(userAtom);          // Read only
  const setUser = useSetAtom(userAtom);         // Write only
  const [name, setName] = useAtom(userNameAtom); // Read + Write

  return (
    <div>
      <p>{user?.email}</p>
      <input value={name} onChange={(e) => setName(e.target.value)} />
    </div>
  );
}
```

## Form State (React Hook Form)

```typescript
import { useForm, useFieldArray } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1, 'Required'),
  email: z.string().email('Invalid email'),
  addresses: z.array(z.object({
    street: z.string().min(1),
    city: z.string().min(1),
  })).min(1, 'At least one address required'),
});

type FormData = z.infer<typeof schema>;

function ProfileForm() {
  const {
    register,
    handleSubmit,
    control,
    formState: { errors, isSubmitting, isDirty },
    reset,
  } = useForm<FormData>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: '',
      email: '',
      addresses: [{ street: '', city: '' }],
    },
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: 'addresses',
  });

  const onSubmit = async (data: FormData) => {
    await saveProfile(data);
    reset(data); // Reset dirty state
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('name')} />
      {errors.name && <span>{errors.name.message}</span>}

      <input {...register('email')} />
      {errors.email && <span>{errors.email.message}</span>}

      {fields.map((field, index) => (
        <div key={field.id}>
          <input {...register(`addresses.${index}.street`)} />
          <input {...register(`addresses.${index}.city`)} />
          <button type="button" onClick={() => remove(index)}>
            Remove
          </button>
        </div>
      ))}

      <button type="button" onClick={() => append({ street: '', city: '' })}>
        Add Address
      </button>

      <button type="submit" disabled={isSubmitting || !isDirty}>
        {isSubmitting ? 'Saving...' : 'Save'}
      </button>
    </form>
  );
}
```

## URL State

```typescript
// Using nuqs (type-safe URL state)
import { useQueryState, parseAsInteger, parseAsString } from 'nuqs';

function ProductList() {
  const [search, setSearch] = useQueryState('q', parseAsString.withDefault(''));
  const [page, setPage] = useQueryState('page', parseAsInteger.withDefault(1));
  const [sort, setSort] = useQueryState('sort', parseAsString.withDefault('newest'));

  // URL: /products?q=shoes&page=2&sort=price

  return (
    <div>
      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search..."
      />

      <select value={sort} onChange={(e) => setSort(e.target.value)}>
        <option value="newest">Newest</option>
        <option value="price">Price</option>
      </select>

      <ProductGrid search={search} page={page} sort={sort} />

      <Pagination
        page={page}
        onPageChange={setPage}
      />
    </div>
  );
}

// Using native useSearchParams
import { useSearchParams } from 'next/navigation';

function Filters() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  const updateParam = (key: string, value: string) => {
    const params = new URLSearchParams(searchParams);
    if (value) {
      params.set(key, value);
    } else {
      params.delete(key);
    }
    router.push(`${pathname}?${params.toString()}`);
  };

  return (
    <select
      value={searchParams.get('category') || ''}
      onChange={(e) => updateParam('category', e.target.value)}
    >
      <option value="">All Categories</option>
      <option value="electronics">Electronics</option>
    </select>
  );
}
```

## Optimistic Updates

```typescript
// With React Query
function useToggleLike(postId: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () => toggleLike(postId),

    onMutate: async () => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['post', postId] });

      // Snapshot previous value
      const previousPost = queryClient.getQueryData(['post', postId]);

      // Optimistically update
      queryClient.setQueryData(['post', postId], (old: Post) => ({
        ...old,
        isLiked: !old.isLiked,
        likeCount: old.isLiked ? old.likeCount - 1 : old.likeCount + 1,
      }));

      return { previousPost };
    },

    onError: (err, variables, context) => {
      // Rollback on error
      queryClient.setQueryData(['post', postId], context?.previousPost);
      toast.error('Failed to update');
    },
  });
}

// Usage
function LikeButton({ post }: { post: Post }) {
  const { mutate: toggleLike, isPending } = useToggleLike(post.id);

  return (
    <button
      onClick={() => toggleLike()}
      disabled={isPending}
      className={post.isLiked ? 'text-red-500' : ''}
    >
      ❤️ {post.likeCount}
    </button>
  );
}
```

## Hydration (SSR)

```typescript
// React Query hydration
// app/providers.tsx
'use client';

import { QueryClient, QueryClientProvider, HydrationBoundary } from '@tanstack/react-query';
import { useState } from 'react';

export function Providers({
  children,
  dehydratedState,
}: {
  children: React.ReactNode;
  dehydratedState?: unknown;
}) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000, // 1 minute
      },
    },
  }));

  return (
    <QueryClientProvider client={queryClient}>
      <HydrationBoundary state={dehydratedState}>
        {children}
      </HydrationBoundary>
    </QueryClientProvider>
  );
}

// Server component prefetching
// app/users/page.tsx
import { dehydrate, QueryClient } from '@tanstack/react-query';

export default async function UsersPage() {
  const queryClient = new QueryClient();

  await queryClient.prefetchQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
  });

  return (
    <Providers dehydratedState={dehydrate(queryClient)}>
      <UsersList />
    </Providers>
  );
}
```

## When to Use What

| Scenario | Solution |
|----------|----------|
| Data from API | React Query / SWR |
| UI toggles, modals | useState or Zustand |
| Theme, user preferences | Zustand with persist |
| Complex forms | React Hook Form |
| Filters, pagination | URL state (nuqs) |
| Shared across app | Zustand / Jotai |
| Component-local | useState |

## Checklist

### Server State
- [ ] Query keys organized in factory
- [ ] Stale time configured appropriately
- [ ] Error handling in place
- [ ] Loading states shown

### Client State
- [ ] Minimal global state
- [ ] Selectors used for performance
- [ ] Persistence where needed
- [ ] DevTools enabled in development

### Forms
- [ ] Validation with Zod/Yup
- [ ] Error messages displayed
- [ ] Loading state during submit
- [ ] Dirty state tracked

### URL State
- [ ] Shareable URLs work
- [ ] Back/forward navigation works
- [ ] Default values handled
- [ ] Type-safe params

### Performance
- [ ] Optimistic updates for interactions
- [ ] Proper hydration for SSR
- [ ] No unnecessary re-renders
- [ ] Memoization where needed

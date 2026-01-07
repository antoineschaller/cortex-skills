# UI Patterns

Component architecture, accessibility, and design system patterns.

> **Template Usage:** Customize for your UI framework (React, Vue, Svelte) and component library (shadcn, Radix, Chakra, etc.).

## Component Organization

### Atomic Design Structure

```
components/
├── ui/                    # Primitive/atomic components
│   ├── button.tsx
│   ├── input.tsx
│   └── card.tsx
├── forms/                 # Form-specific components
│   ├── form-field.tsx
│   └── form-select.tsx
├── layouts/               # Layout components
│   ├── page-header.tsx
│   └── sidebar.tsx
└── features/              # Feature-specific composites
    ├── user-profile/
    └── dashboard/
```

### Component Template

```typescript
// components/ui/button.tsx
import { forwardRef } from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

const buttonVariants = cva(
  // Base styles
  'inline-flex items-center justify-center rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-input bg-background hover:bg-accent',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 px-3',
        lg: 'h-11 px-8',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
);

interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  isLoading?: boolean;
}

const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, isLoading, children, disabled, ...props }, ref) => {
    return (
      <button
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        disabled={disabled || isLoading}
        {...props}
      >
        {isLoading ? (
          <span className="mr-2 h-4 w-4 animate-spin">⏳</span>
        ) : null}
        {children}
      </button>
    );
  }
);
Button.displayName = 'Button';

export { Button, buttonVariants };
```

## Server vs Client Components

```typescript
// Server Component (default) - no 'use client'
// Can: fetch data, access backend, use async/await
// Cannot: useState, useEffect, onClick, browser APIs
async function UserList() {
  const users = await db.user.findMany(); // Direct DB access

  return (
    <ul>
      {users.map(user => (
        <UserCard key={user.id} user={user} />
      ))}
    </ul>
  );
}

// Client Component - add 'use client'
// Can: useState, useEffect, onClick, browser APIs
// Cannot: async component, direct DB access
'use client';

import { useState } from 'react';

function Counter() {
  const [count, setCount] = useState(0);

  return (
    <button onClick={() => setCount(c => c + 1)}>
      Count: {count}
    </button>
  );
}
```

### When to Use Client Components

```typescript
'use client'; // Required when using:

// 1. Event handlers
<button onClick={handleClick}>

// 2. State
const [value, setValue] = useState();

// 3. Effects
useEffect(() => { ... }, []);

// 4. Browser APIs
window.localStorage.getItem('key');

// 5. Custom hooks with state
const { data } = useQuery();
```

## Accessibility Patterns

### Buttons and Links

```typescript
// Button for actions
<button
  type="button"
  onClick={handleAction}
  aria-label="Close dialog"  // When text isn't descriptive
  aria-pressed={isActive}    // For toggle buttons
  aria-expanded={isOpen}     // For expandable content
  disabled={isDisabled}
>
  <IconX aria-hidden="true" /> {/* Decorative icons */}
  <span className="sr-only">Close</span> {/* Screen reader only */}
</button>

// Link for navigation
<a
  href="/page"
  aria-current={isCurrentPage ? 'page' : undefined}
>
  Page Name
</a>

// Button that looks like link
<button type="button" className="link-styles">
  Not a navigation, but an action
</button>
```

### Forms

```typescript
<form onSubmit={handleSubmit}>
  {/* Always associate labels with inputs */}
  <div>
    <label htmlFor="email">Email address</label>
    <input
      id="email"
      type="email"
      aria-describedby="email-error email-hint"
      aria-invalid={hasError}
      required
    />
    <p id="email-hint" className="text-sm text-muted">
      We'll never share your email.
    </p>
    {hasError && (
      <p id="email-error" className="text-sm text-destructive" role="alert">
        Please enter a valid email address.
      </p>
    )}
  </div>

  <button type="submit" aria-busy={isSubmitting}>
    {isSubmitting ? 'Submitting...' : 'Submit'}
  </button>
</form>
```

### Focus Management

```typescript
'use client';

import { useRef, useEffect } from 'react';

function Dialog({ isOpen, onClose, children }) {
  const dialogRef = useRef<HTMLDivElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      // Save current focus
      previousFocus.current = document.activeElement as HTMLElement;
      // Focus dialog
      dialogRef.current?.focus();
    } else {
      // Restore focus when closed
      previousFocus.current?.focus();
    }
  }, [isOpen]);

  // Trap focus inside dialog
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      onClose();
    }
    if (e.key === 'Tab') {
      // Implement focus trap logic
    }
  };

  if (!isOpen) return null;

  return (
    <div
      ref={dialogRef}
      role="dialog"
      aria-modal="true"
      aria-labelledby="dialog-title"
      tabIndex={-1}
      onKeyDown={handleKeyDown}
    >
      <h2 id="dialog-title">Dialog Title</h2>
      {children}
    </div>
  );
}
```

## Loading States

```typescript
// Skeleton loader
function UserCardSkeleton() {
  return (
    <div className="animate-pulse">
      <div className="h-4 w-3/4 bg-muted rounded" />
      <div className="h-3 w-1/2 bg-muted rounded mt-2" />
    </div>
  );
}

// Loading with Suspense
import { Suspense } from 'react';

function Page() {
  return (
    <Suspense fallback={<UserCardSkeleton />}>
      <UserCard />
    </Suspense>
  );
}

// Button loading state
<Button isLoading={isPending} disabled={isPending}>
  {isPending ? 'Saving...' : 'Save'}
</Button>
```

## Error States

```typescript
// Error boundary
'use client';

import { Component, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error caught:', error, errorInfo);
    // Send to error tracking service
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || (
        <div role="alert" className="p-4 border border-destructive rounded">
          <h2>Something went wrong</h2>
          <button onClick={() => this.setState({ hasError: false })}>
            Try again
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
```

## Form Patterns

```typescript
'use client';

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const schema = z.object({
  name: z.string().min(1, 'Required'),
  email: z.string().email('Invalid email'),
});

type FormData = z.infer<typeof schema>;

function ContactForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<FormData>({
    resolver: zodResolver(schema),
  });

  const onSubmit = async (data: FormData) => {
    await submitForm(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div>
        <label htmlFor="name">Name</label>
        <input
          id="name"
          {...register('name')}
          aria-invalid={!!errors.name}
        />
        {errors.name && (
          <p role="alert">{errors.name.message}</p>
        )}
      </div>

      <div>
        <label htmlFor="email">Email</label>
        <input
          id="email"
          type="email"
          {...register('email')}
          aria-invalid={!!errors.email}
        />
        {errors.email && (
          <p role="alert">{errors.email.message}</p>
        )}
      </div>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Submitting...' : 'Submit'}
      </button>
    </form>
  );
}
```

## Responsive Patterns

```typescript
// Tailwind responsive classes
<div className="
  grid
  grid-cols-1      // Mobile: 1 column
  sm:grid-cols-2   // Small: 2 columns
  lg:grid-cols-3   // Large: 3 columns
  gap-4
">

// Conditional rendering by breakpoint
'use client';

import { useMediaQuery } from '@/hooks/use-media-query';

function Navigation() {
  const isDesktop = useMediaQuery('(min-width: 768px)');

  return isDesktop ? <DesktopNav /> : <MobileNav />;
}

// useMediaQuery hook
function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const media = window.matchMedia(query);
    setMatches(media.matches);

    const listener = (e: MediaQueryListEvent) => setMatches(e.matches);
    media.addEventListener('change', listener);
    return () => media.removeEventListener('change', listener);
  }, [query]);

  return matches;
}
```

## Checklist

### Component Quality
- [ ] Uses TypeScript with proper prop types
- [ ] Supports ref forwarding where needed
- [ ] Has sensible defaults
- [ ] Supports className override for styling

### Accessibility
- [ ] Images have alt text
- [ ] Buttons have accessible names
- [ ] Form inputs have labels
- [ ] Focus is visible and managed
- [ ] Keyboard navigation works
- [ ] ARIA attributes used correctly
- [ ] Color contrast meets WCAG AA

### Performance
- [ ] Server components where possible
- [ ] Client components only when needed
- [ ] Proper loading states
- [ ] Error boundaries in place
- [ ] No unnecessary re-renders

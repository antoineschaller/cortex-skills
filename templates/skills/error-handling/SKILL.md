# Error Handling Patterns

Comprehensive error handling for robust applications.

> **Template Usage:** Customize for your framework (React, Vue, Express) and error tracking service (Sentry, Bugsnag, etc.).

## Error Class Hierarchy

```typescript
// lib/errors.ts

// Base application error
export class AppError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode: number = 500,
    public isOperational: boolean = true
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

// Specific error types
export class ValidationError extends AppError {
  constructor(message: string, public fields?: Record<string, string[]>) {
    super(message, 'VALIDATION_ERROR', 400);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id?: string) {
    super(
      id ? `${resource} with id ${id} not found` : `${resource} not found`,
      'NOT_FOUND',
      404
    );
  }
}

export class UnauthorizedError extends AppError {
  constructor(message: string = 'Unauthorized') {
    super(message, 'UNAUTHORIZED', 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message: string = 'Forbidden') {
    super(message, 'FORBIDDEN', 403);
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super(message, 'CONFLICT', 409);
  }
}

export class RateLimitError extends AppError {
  constructor(retryAfter?: number) {
    super('Too many requests', 'RATE_LIMIT', 429);
  }
}
```

## Error Boundaries (React)

```typescript
// components/error-boundary.tsx
'use client';

import { Component, ReactNode } from 'react';
import * as Sentry from '@sentry/nextjs'; // or your error tracker

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
  onError?: (error: Error, errorInfo: React.ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    // Log to error tracking service
    Sentry.captureException(error, {
      extra: { componentStack: errorInfo.componentStack }
    });

    // Call custom handler
    this.props.onError?.(error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || <DefaultErrorFallback error={this.state.error} />;
    }
    return this.props.children;
  }
}

function DefaultErrorFallback({ error }: { error?: Error }) {
  return (
    <div role="alert" className="p-6 rounded-lg border border-destructive bg-destructive/10">
      <h2 className="text-lg font-semibold text-destructive">Something went wrong</h2>
      <p className="mt-2 text-sm text-muted-foreground">
        We've been notified and are working on a fix.
      </p>
      {process.env.NODE_ENV === 'development' && error && (
        <pre className="mt-4 p-2 bg-muted rounded text-xs overflow-auto">
          {error.message}
        </pre>
      )}
      <button
        onClick={() => window.location.reload()}
        className="mt-4 px-4 py-2 bg-primary text-primary-foreground rounded"
      >
        Reload page
      </button>
    </div>
  );
}

// Usage
function App() {
  return (
    <ErrorBoundary fallback={<ErrorPage />}>
      <MainContent />
    </ErrorBoundary>
  );
}
```

## Next.js Error Handling

```typescript
// app/error.tsx - Error boundary for route segment
'use client';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Log to error tracking
    Sentry.captureException(error);
  }, [error]);

  return (
    <div className="flex flex-col items-center justify-center min-h-screen">
      <h2 className="text-2xl font-bold">Something went wrong!</h2>
      <button
        onClick={reset}
        className="mt-4 px-4 py-2 bg-primary text-white rounded"
      >
        Try again
      </button>
    </div>
  );
}

// app/global-error.tsx - Root error boundary
'use client';

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html>
      <body>
        <h2>Something went wrong!</h2>
        <button onClick={reset}>Try again</button>
      </body>
    </html>
  );
}

// app/not-found.tsx - 404 page
export default function NotFound() {
  return (
    <div>
      <h2>Not Found</h2>
      <p>Could not find requested resource</p>
    </div>
  );
}
```

## API Error Handling

```typescript
// Server action error handling
'use server';

import { AppError, ValidationError } from '@/lib/errors';

export async function createItem(formData: FormData) {
  try {
    const data = parseFormData(formData);

    // Validation
    const validated = schema.safeParse(data);
    if (!validated.success) {
      return {
        success: false,
        error: 'Validation failed',
        fields: validated.error.flatten().fieldErrors,
      };
    }

    // Business logic
    const result = await db.item.create({ data: validated.data });

    return { success: true, data: result };
  } catch (error) {
    // Log error with context
    console.error('createItem failed:', {
      error,
      formData: Object.fromEntries(formData),
    });

    // Return user-friendly error
    if (error instanceof AppError) {
      return {
        success: false,
        error: error.message,
        code: error.code,
      };
    }

    return {
      success: false,
      error: 'An unexpected error occurred',
    };
  }
}

// Express/API route error handling
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  // Log error
  console.error('API Error:', {
    error: err,
    path: req.path,
    method: req.method,
    body: req.body,
    user: req.user?.id,
  });

  // Send to error tracking
  Sentry.captureException(err);

  // Respond based on error type
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      error: err.message,
      code: err.code,
      ...(err instanceof ValidationError && { fields: err.fields }),
    });
  }

  // Don't leak internal errors
  return res.status(500).json({
    success: false,
    error: 'Internal server error',
  });
});
```

## Async Error Handling

```typescript
// Wrap async functions for consistent error handling
export function withErrorHandling<T extends any[], R>(
  fn: (...args: T) => Promise<R>,
  options?: {
    onError?: (error: Error) => void;
    fallback?: R;
  }
) {
  return async (...args: T): Promise<R> => {
    try {
      return await fn(...args);
    } catch (error) {
      options?.onError?.(error as Error);

      if (options?.fallback !== undefined) {
        return options.fallback;
      }

      throw error;
    }
  };
}

// React Query error handling
const { data, error, isError } = useQuery({
  queryKey: ['user', id],
  queryFn: () => fetchUser(id),
  retry: (failureCount, error) => {
    // Don't retry on 4xx errors
    if (error instanceof AppError && error.statusCode < 500) {
      return false;
    }
    return failureCount < 3;
  },
  onError: (error) => {
    toast.error(getUserFriendlyMessage(error));
  },
});
```

## User-Friendly Error Messages

```typescript
// lib/error-messages.ts

const ERROR_MESSAGES: Record<string, string> = {
  // Auth errors
  UNAUTHORIZED: 'Please log in to continue',
  FORBIDDEN: 'You don\'t have permission to do this',
  SESSION_EXPIRED: 'Your session has expired. Please log in again.',

  // Validation errors
  VALIDATION_ERROR: 'Please check your input and try again',
  INVALID_EMAIL: 'Please enter a valid email address',
  PASSWORD_TOO_WEAK: 'Password must be at least 8 characters',

  // Resource errors
  NOT_FOUND: 'The requested item could not be found',
  ALREADY_EXISTS: 'This item already exists',
  CONFLICT: 'This action conflicts with existing data',

  // Network/server errors
  NETWORK_ERROR: 'Unable to connect. Please check your internet connection.',
  TIMEOUT: 'The request took too long. Please try again.',
  RATE_LIMIT: 'Too many requests. Please wait a moment and try again.',
  SERVER_ERROR: 'Something went wrong on our end. We\'ve been notified.',

  // Default
  UNKNOWN: 'An unexpected error occurred. Please try again.',
};

export function getUserFriendlyMessage(error: unknown): string {
  if (error instanceof AppError) {
    return ERROR_MESSAGES[error.code] || error.message;
  }

  if (error instanceof Error) {
    // Check for network errors
    if (error.message.includes('fetch') || error.message.includes('network')) {
      return ERROR_MESSAGES.NETWORK_ERROR;
    }
  }

  return ERROR_MESSAGES.UNKNOWN;
}
```

## Logging with Context

```typescript
// lib/logger.ts
import * as Sentry from '@sentry/nextjs';

type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface LogContext {
  userId?: string;
  requestId?: string;
  [key: string]: unknown;
}

class Logger {
  constructor(private service: string) {}

  private log(level: LogLevel, message: string, context?: LogContext) {
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      level,
      service: this.service,
      message,
      ...context,
    };

    // Console output (structured for production log aggregation)
    console[level](JSON.stringify(logEntry));

    // Send errors to tracking service
    if (level === 'error' && context?.error) {
      Sentry.captureException(context.error, {
        extra: context,
        tags: { service: this.service },
      });
    }
  }

  debug(message: string, context?: LogContext) {
    if (process.env.NODE_ENV === 'development') {
      this.log('debug', message, context);
    }
  }

  info(message: string, context?: LogContext) {
    this.log('info', message, context);
  }

  warn(message: string, context?: LogContext) {
    this.log('warn', message, context);
  }

  error(message: string, context?: LogContext) {
    this.log('error', message, context);
  }
}

export const createLogger = (service: string) => new Logger(service);

// Usage
const logger = createLogger('UserService');

logger.error('Failed to create user', {
  error: err,
  userId: user.id,
  email: input.email,
});
```

## Retry Pattern

```typescript
// lib/retry.ts

interface RetryOptions {
  maxAttempts?: number;
  delayMs?: number;
  backoff?: 'linear' | 'exponential';
  shouldRetry?: (error: Error) => boolean;
}

export async function withRetry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const {
    maxAttempts = 3,
    delayMs = 1000,
    backoff = 'exponential',
    shouldRetry = () => true,
  } = options;

  let lastError: Error;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      if (attempt === maxAttempts || !shouldRetry(lastError)) {
        throw lastError;
      }

      const delay = backoff === 'exponential'
        ? delayMs * Math.pow(2, attempt - 1)
        : delayMs * attempt;

      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }

  throw lastError!;
}

// Usage
const data = await withRetry(
  () => fetchExternalAPI(),
  {
    maxAttempts: 3,
    delayMs: 1000,
    backoff: 'exponential',
    shouldRetry: (error) => {
      // Only retry on network/server errors
      if (error instanceof AppError) {
        return error.statusCode >= 500;
      }
      return true;
    },
  }
);
```

## Checklist

### Error Types
- [ ] Custom error classes defined
- [ ] Errors have codes for identification
- [ ] Errors include appropriate status codes
- [ ] Operational vs programmer errors distinguished

### Error Boundaries
- [ ] React error boundaries in place
- [ ] Route-level error pages (error.tsx)
- [ ] Global error handler for uncaught errors
- [ ] 404 not found page

### User Experience
- [ ] User-friendly error messages
- [ ] Errors are translated (i18n)
- [ ] Recovery options provided (retry, go back)
- [ ] Loading states prevent premature errors

### Logging & Tracking
- [ ] Errors logged with context
- [ ] Error tracking service integrated
- [ ] Sensitive data not logged
- [ ] Request IDs for tracing

### Resilience
- [ ] Retry logic for transient failures
- [ ] Timeouts configured
- [ ] Graceful degradation where possible
- [ ] Circuit breakers for external services

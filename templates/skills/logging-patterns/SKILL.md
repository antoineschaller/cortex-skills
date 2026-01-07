# Logging & Observability Patterns

Structured logging, tracing, and metrics patterns for production applications.

> **Template Usage:** Customize for your logging library (Pino, Winston, Bunyan) and observability platform (Datadog, New Relic, Grafana).

## Logging Levels

| Level | Use Case | Example |
|-------|----------|---------|
| `fatal` | App cannot continue | Database connection lost |
| `error` | Operation failed | Payment processing failed |
| `warn` | Unexpected but handled | Rate limit approaching |
| `info` | Significant events | User logged in, order placed |
| `debug` | Diagnostic info | Function inputs/outputs |
| `trace` | Very detailed | Loop iterations, SQL queries |

## Structured Logging Setup

### Pino (Node.js)

```typescript
// lib/logger.ts
import pino from 'pino';

const isProduction = process.env.NODE_ENV === 'production';

export const logger = pino({
  level: process.env.LOG_LEVEL || (isProduction ? 'info' : 'debug'),

  // Pretty print in development
  transport: isProduction ? undefined : {
    target: 'pino-pretty',
    options: {
      colorize: true,
      translateTime: 'SYS:standard',
      ignore: 'pid,hostname',
    },
  },

  // Base context added to all logs
  base: {
    env: process.env.NODE_ENV,
    service: 'my-app',
    version: process.env.APP_VERSION,
  },

  // Redact sensitive fields
  redact: {
    paths: [
      'password',
      'token',
      'authorization',
      'cookie',
      'req.headers.authorization',
      'req.headers.cookie',
      '*.password',
      '*.token',
      '*.secret',
    ],
    censor: '[REDACTED]',
  },

  // Custom serializers
  serializers: {
    err: pino.stdSerializers.err,
    req: (req) => ({
      method: req.method,
      url: req.url,
      path: req.path,
      query: req.query,
      userAgent: req.headers['user-agent'],
    }),
    res: (res) => ({
      statusCode: res.statusCode,
    }),
  },
});

// Child loggers for modules
export const createLogger = (module: string) => {
  return logger.child({ module });
};
```

### Winston Alternative

```typescript
// lib/logger.ts
import winston from 'winston';

const { combine, timestamp, json, errors, printf, colorize } = winston.format;

const devFormat = combine(
  colorize(),
  timestamp({ format: 'HH:mm:ss' }),
  errors({ stack: true }),
  printf(({ level, message, timestamp, module, ...meta }) => {
    const metaStr = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
    return `${timestamp} [${module || 'app'}] ${level}: ${message} ${metaStr}`;
  })
);

const prodFormat = combine(
  timestamp(),
  errors({ stack: true }),
  json()
);

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: process.env.NODE_ENV === 'production' ? prodFormat : devFormat,
  defaultMeta: {
    service: 'my-app',
    version: process.env.APP_VERSION,
  },
  transports: [
    new winston.transports.Console(),
    // Add file transport in production
    ...(process.env.NODE_ENV === 'production' ? [
      new winston.transports.File({ filename: 'error.log', level: 'error' }),
      new winston.transports.File({ filename: 'combined.log' }),
    ] : []),
  ],
});

export const createLogger = (module: string) => {
  return logger.child({ module });
};
```

## Context Propagation

### Request Context

```typescript
// lib/context.ts
import { AsyncLocalStorage } from 'async_hooks';
import { randomUUID } from 'crypto';

interface RequestContext {
  requestId: string;
  userId?: string;
  accountId?: string;
  traceId?: string;
  spanId?: string;
  startTime: number;
}

export const asyncLocalStorage = new AsyncLocalStorage<RequestContext>();

export const getContext = (): RequestContext | undefined => {
  return asyncLocalStorage.getStore();
};

export const withContext = <T>(
  context: Partial<RequestContext>,
  fn: () => T
): T => {
  const fullContext: RequestContext = {
    requestId: context.requestId || randomUUID(),
    startTime: context.startTime || Date.now(),
    ...context,
  };
  return asyncLocalStorage.run(fullContext, fn);
};

// Middleware
export const contextMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const context: RequestContext = {
    requestId: req.headers['x-request-id'] as string || randomUUID(),
    traceId: req.headers['x-trace-id'] as string,
    userId: req.user?.id,
    accountId: req.user?.accountId,
    startTime: Date.now(),
  };

  // Add request ID to response
  res.setHeader('x-request-id', context.requestId);

  withContext(context, () => next());
};
```

### Context-Aware Logger

```typescript
// lib/logger.ts
import { getContext } from './context';

export const log = {
  info: (message: string, data?: object) => {
    const ctx = getContext();
    logger.info({
      message,
      ...data,
      requestId: ctx?.requestId,
      userId: ctx?.userId,
      traceId: ctx?.traceId,
    });
  },

  error: (message: string, error: Error, data?: object) => {
    const ctx = getContext();
    logger.error({
      message,
      error: {
        name: error.name,
        message: error.message,
        stack: error.stack,
      },
      ...data,
      requestId: ctx?.requestId,
      userId: ctx?.userId,
      traceId: ctx?.traceId,
    });
  },

  // ... other levels
};
```

## Logging Patterns

### Service Method Logging

```typescript
// services/order.service.ts
import { createLogger } from '@/lib/logger';

const logger = createLogger('order-service');

export class OrderService {
  async createOrder(input: CreateOrderInput): Promise<Result<Order>> {
    const startTime = Date.now();

    logger.info('Creating order', {
      userId: input.userId,
      itemCount: input.items.length,
      total: input.total,
    });

    try {
      const order = await this.repository.create(input);

      logger.info('Order created', {
        orderId: order.id,
        duration: Date.now() - startTime,
      });

      return { success: true, data: order };
    } catch (error) {
      logger.error('Failed to create order', {
        error: error instanceof Error ? error.message : 'Unknown error',
        stack: error instanceof Error ? error.stack : undefined,
        input: { userId: input.userId, itemCount: input.items.length },
        duration: Date.now() - startTime,
      });

      return { success: false, error: new ServiceError('Order creation failed') };
    }
  }
}
```

### API Route Logging

```typescript
// app/api/orders/route.ts
import { createLogger } from '@/lib/logger';

const logger = createLogger('api:orders');

export async function POST(request: Request) {
  const startTime = Date.now();

  logger.info('POST /api/orders - Request received');

  try {
    const body = await request.json();
    const result = await orderService.createOrder(body);

    if (result.success) {
      logger.info('POST /api/orders - Success', {
        orderId: result.data.id,
        duration: Date.now() - startTime,
      });
      return Response.json(result.data, { status: 201 });
    }

    logger.warn('POST /api/orders - Business error', {
      error: result.error.message,
      duration: Date.now() - startTime,
    });
    return Response.json({ error: result.error.message }, { status: 400 });

  } catch (error) {
    logger.error('POST /api/orders - Unexpected error', {
      error: error instanceof Error ? error.message : 'Unknown',
      stack: error instanceof Error ? error.stack : undefined,
      duration: Date.now() - startTime,
    });
    return Response.json({ error: 'Internal server error' }, { status: 500 });
  }
}
```

### Database Query Logging

```typescript
// lib/db.ts
import { PrismaClient } from '@prisma/client';
import { createLogger } from '@/lib/logger';

const logger = createLogger('database');

export const prisma = new PrismaClient({
  log: [
    { level: 'query', emit: 'event' },
    { level: 'error', emit: 'event' },
    { level: 'warn', emit: 'event' },
  ],
});

// Log slow queries (> 100ms)
prisma.$on('query', (e) => {
  if (e.duration > 100) {
    logger.warn('Slow query detected', {
      query: e.query,
      params: e.params,
      duration: e.duration,
    });
  } else if (process.env.LOG_QUERIES === 'true') {
    logger.debug('Query executed', {
      query: e.query,
      duration: e.duration,
    });
  }
});

prisma.$on('error', (e) => {
  logger.error('Database error', { error: e.message });
});
```

## Metrics

### Counter and Histogram

```typescript
// lib/metrics.ts
import { Counter, Histogram, Registry } from 'prom-client';

export const register = new Registry();

// Request counter
export const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [register],
});

// Response time histogram
export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'path', 'status'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register],
});

// Business metrics
export const ordersCreated = new Counter({
  name: 'orders_created_total',
  help: 'Total orders created',
  labelNames: ['status'],
  registers: [register],
});

export const orderValue = new Histogram({
  name: 'order_value_dollars',
  help: 'Order value in dollars',
  buckets: [10, 50, 100, 500, 1000, 5000],
  registers: [register],
});

// Metrics middleware
export const metricsMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const start = Date.now();

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const path = req.route?.path || req.path;

    httpRequestsTotal.inc({
      method: req.method,
      path,
      status: res.statusCode,
    });

    httpRequestDuration.observe(
      { method: req.method, path, status: res.statusCode },
      duration
    );
  });

  next();
};

// Metrics endpoint
export async function GET() {
  const metrics = await register.metrics();
  return new Response(metrics, {
    headers: { 'Content-Type': register.contentType },
  });
}
```

## Distributed Tracing

### OpenTelemetry Setup

```typescript
// lib/tracing.ts
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'my-app',
    [SemanticResourceAttributes.SERVICE_VERSION]: process.env.APP_VERSION,
    [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV,
  }),
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': { enabled: true },
      '@opentelemetry/instrumentation-express': { enabled: true },
      '@opentelemetry/instrumentation-pg': { enabled: true },
    }),
  ],
});

sdk.start();

process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('Tracing terminated'))
    .catch((error) => console.error('Error terminating tracing', error))
    .finally(() => process.exit(0));
});
```

### Manual Spans

```typescript
import { trace, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('my-app');

async function processOrder(orderId: string) {
  return tracer.startActiveSpan('processOrder', async (span) => {
    try {
      span.setAttribute('order.id', orderId);

      // Child span for payment
      await tracer.startActiveSpan('processPayment', async (paymentSpan) => {
        const payment = await paymentService.process(orderId);
        paymentSpan.setAttribute('payment.amount', payment.amount);
        paymentSpan.end();
      });

      // Child span for inventory
      await tracer.startActiveSpan('updateInventory', async (inventorySpan) => {
        await inventoryService.update(orderId);
        inventorySpan.end();
      });

      span.setStatus({ code: SpanStatusCode.OK });
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error instanceof Error ? error.message : 'Unknown error',
      });
      span.recordException(error as Error);
      throw error;
    } finally {
      span.end();
    }
  });
}
```

## Log Aggregation

### Datadog Integration

```typescript
// lib/logger.ts
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => {
      // Datadog expects 'status' field
      return { status: label };
    },
  },
  messageKey: 'message', // Datadog expects 'message'
  base: {
    service: process.env.DD_SERVICE,
    env: process.env.DD_ENV,
    version: process.env.DD_VERSION,
  },
});
```

### Sentry Integration

```typescript
// lib/sentry.ts
import * as Sentry from '@sentry/nextjs';
import { createLogger } from './logger';

const logger = createLogger('sentry');

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.APP_VERSION,

  beforeSend(event, hint) {
    // Log to structured logger as well
    logger.error('Sentry event captured', {
      eventId: event.event_id,
      message: event.message,
      exception: hint.originalException,
    });
    return event;
  },

  integrations: [
    new Sentry.Integrations.Http({ tracing: true }),
    new Sentry.Integrations.Prisma({ client: prisma }),
  ],

  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
});
```

## What NOT to Log

```typescript
// NEVER log these:
const NEVER_LOG = [
  'passwords',
  'tokens',
  'API keys',
  'credit card numbers',
  'SSN',
  'full request bodies with PII',
  'session IDs (without masking)',
];

// Sanitize before logging
function sanitize(obj: Record<string, unknown>): Record<string, unknown> {
  const sensitiveKeys = ['password', 'token', 'secret', 'key', 'authorization'];

  return Object.fromEntries(
    Object.entries(obj).map(([key, value]) => {
      if (sensitiveKeys.some(k => key.toLowerCase().includes(k))) {
        return [key, '[REDACTED]'];
      }
      if (typeof value === 'object' && value !== null) {
        return [key, sanitize(value as Record<string, unknown>)];
      }
      return [key, value];
    })
  );
}
```

## Checklist

### Setup
- [ ] Structured JSON logging in production
- [ ] Pretty logging in development
- [ ] Log levels configurable via env var
- [ ] Sensitive data redaction configured

### Context
- [ ] Request ID propagated
- [ ] User context attached
- [ ] Trace ID for distributed tracing
- [ ] Duration tracked for operations

### Integration
- [ ] Logs shipped to aggregator (Datadog, Loki, etc.)
- [ ] Metrics exposed (/metrics endpoint)
- [ ] Sentry for error tracking
- [ ] Alerts configured for errors

### Best Practices
- [ ] Consistent log format across services
- [ ] No sensitive data in logs
- [ ] Slow query logging enabled
- [ ] Log rotation configured

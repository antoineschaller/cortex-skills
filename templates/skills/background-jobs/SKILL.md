# Background Jobs Patterns

Queue-based job processing, scheduled tasks, and worker patterns.

> **Template Usage:** Customize for your queue provider (BullMQ, Inngest, Trigger.dev, AWS SQS) and runtime.

## Job Types

| Type | Use Case | Example |
|------|----------|---------|
| **Async Tasks** | Deferred processing | Send email, process image |
| **Scheduled** | Recurring tasks | Daily reports, cleanup |
| **Delayed** | Future execution | Reminder after 24h |
| **Batch** | Process many items | Import CSV, bulk update |
| **Workflow** | Multi-step processes | Onboarding, order fulfillment |

## BullMQ Setup

### Queue Configuration

```typescript
// lib/queue/connection.ts
import { Queue, Worker, QueueEvents } from 'bullmq';
import IORedis from 'ioredis';

export const connection = new IORedis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379'),
  password: process.env.REDIS_PASSWORD,
  maxRetriesPerRequest: null, // Required for BullMQ
});

// Reusable queue factory
export function createQueue(name: string) {
  return new Queue(name, {
    connection,
    defaultJobOptions: {
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 1000,
      },
      removeOnComplete: {
        count: 1000, // Keep last 1000 completed
        age: 24 * 3600, // Or 24 hours
      },
      removeOnFail: {
        count: 5000, // Keep last 5000 failed
      },
    },
  });
}
```

### Queue Definitions

```typescript
// lib/queue/queues.ts
import { createQueue } from './connection';

// Define typed queues
export const emailQueue = createQueue('email');
export const imageQueue = createQueue('image-processing');
export const notificationQueue = createQueue('notifications');
export const reportQueue = createQueue('reports');

// Job type definitions
export interface EmailJob {
  to: string;
  subject: string;
  template: string;
  data: Record<string, unknown>;
}

export interface ImageProcessingJob {
  imageId: string;
  operations: Array<'resize' | 'compress' | 'watermark'>;
  outputPath: string;
}

export interface ReportJob {
  type: 'daily' | 'weekly' | 'monthly';
  accountId: string;
  startDate: string;
  endDate: string;
}
```

### Adding Jobs

```typescript
// lib/queue/producers.ts
import { emailQueue, imageQueue, reportQueue } from './queues';
import type { EmailJob, ImageProcessingJob, ReportJob } from './queues';

export const jobs = {
  // Immediate job
  async sendEmail(data: EmailJob) {
    return emailQueue.add('send', data, {
      priority: data.template === 'password-reset' ? 1 : 10,
    });
  },

  // Delayed job
  async sendReminderEmail(data: EmailJob, delayMs: number) {
    return emailQueue.add('send', data, {
      delay: delayMs,
    });
  },

  // Scheduled/recurring job
  async scheduleReport(data: ReportJob, cron: string) {
    return reportQueue.add('generate', data, {
      repeat: {
        pattern: cron, // e.g., '0 9 * * *' for 9 AM daily
      },
    });
  },

  // Bulk jobs
  async processImages(images: ImageProcessingJob[]) {
    return imageQueue.addBulk(
      images.map((data) => ({
        name: 'process',
        data,
      }))
    );
  },

  // Job with custom options
  async processImage(data: ImageProcessingJob) {
    return imageQueue.add('process', data, {
      attempts: 5,
      backoff: {
        type: 'fixed',
        delay: 5000,
      },
      timeout: 60000, // 1 minute timeout
    });
  },
};
```

### Workers

```typescript
// workers/email.worker.ts
import { Worker, Job } from 'bullmq';
import { connection } from '@/lib/queue/connection';
import { EmailJob } from '@/lib/queue/queues';
import { sendEmail } from '@/lib/email';
import { createLogger } from '@/lib/logger';

const logger = createLogger('email-worker');

export const emailWorker = new Worker<EmailJob>(
  'email',
  async (job: Job<EmailJob>) => {
    logger.info('Processing email job', {
      jobId: job.id,
      to: job.data.to,
      template: job.data.template,
    });

    try {
      await sendEmail(job.data);

      logger.info('Email sent successfully', {
        jobId: job.id,
        to: job.data.to,
      });

      return { sent: true, timestamp: new Date().toISOString() };
    } catch (error) {
      logger.error('Email sending failed', {
        jobId: job.id,
        error: error instanceof Error ? error.message : 'Unknown',
        attempt: job.attemptsMade,
      });
      throw error;
    }
  },
  {
    connection,
    concurrency: 5, // Process 5 jobs concurrently
    limiter: {
      max: 100, // Max 100 jobs
      duration: 60000, // Per minute (rate limiting)
    },
  }
);

// Event handlers
emailWorker.on('completed', (job) => {
  logger.info('Job completed', { jobId: job.id });
});

emailWorker.on('failed', (job, err) => {
  logger.error('Job failed', {
    jobId: job?.id,
    error: err.message,
    attempts: job?.attemptsMade,
  });
});

emailWorker.on('error', (err) => {
  logger.error('Worker error', { error: err.message });
});
```

### Worker with Progress

```typescript
// workers/image.worker.ts
import { Worker, Job } from 'bullmq';
import { ImageProcessingJob } from '@/lib/queue/queues';

export const imageWorker = new Worker<ImageProcessingJob>(
  'image-processing',
  async (job: Job<ImageProcessingJob>) => {
    const { imageId, operations, outputPath } = job.data;
    const totalSteps = operations.length;

    for (let i = 0; i < operations.length; i++) {
      const operation = operations[i];

      // Update progress
      await job.updateProgress({
        step: i + 1,
        totalSteps,
        currentOperation: operation,
        percent: Math.round(((i + 1) / totalSteps) * 100),
      });

      // Process operation
      switch (operation) {
        case 'resize':
          await resizeImage(imageId);
          break;
        case 'compress':
          await compressImage(imageId);
          break;
        case 'watermark':
          await addWatermark(imageId);
          break;
      }

      // Log for each step
      await job.log(`Completed ${operation} (${i + 1}/${totalSteps})`);
    }

    return { outputPath, processedAt: new Date().toISOString() };
  },
  {
    connection,
    concurrency: 2, // Image processing is CPU intensive
  }
);
```

## Inngest (Serverless)

### Setup

```typescript
// lib/inngest/client.ts
import { Inngest } from 'inngest';

export const inngest = new Inngest({
  id: 'my-app',
  eventKey: process.env.INNGEST_EVENT_KEY,
});

// Event types
export type Events = {
  'user/created': { data: { userId: string; email: string } };
  'order/placed': { data: { orderId: string; total: number } };
  'report/scheduled': { data: { accountId: string; type: string } };
};
```

### Functions

```typescript
// lib/inngest/functions.ts
import { inngest } from './client';

// Simple function
export const sendWelcomeEmail = inngest.createFunction(
  { id: 'send-welcome-email' },
  { event: 'user/created' },
  async ({ event, step }) => {
    await step.run('send-email', async () => {
      await emailService.send({
        to: event.data.email,
        template: 'welcome',
      });
    });
  }
);

// Multi-step workflow
export const onboardingWorkflow = inngest.createFunction(
  { id: 'onboarding-workflow' },
  { event: 'user/created' },
  async ({ event, step }) => {
    // Step 1: Send welcome email
    await step.run('send-welcome', async () => {
      await emailService.send({
        to: event.data.email,
        template: 'welcome',
      });
    });

    // Step 2: Wait 24 hours
    await step.sleep('wait-24h', '24 hours');

    // Step 3: Send tips email
    await step.run('send-tips', async () => {
      await emailService.send({
        to: event.data.email,
        template: 'getting-started-tips',
      });
    });

    // Step 4: Wait another 3 days
    await step.sleep('wait-3-days', '3 days');

    // Step 5: Check if user is active
    const isActive = await step.run('check-activity', async () => {
      const user = await db.user.findUnique({
        where: { id: event.data.userId },
        select: { lastActiveAt: true },
      });
      return user?.lastActiveAt && user.lastActiveAt > new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    });

    // Step 6: Send re-engagement if inactive
    if (!isActive) {
      await step.run('send-reengagement', async () => {
        await emailService.send({
          to: event.data.email,
          template: 're-engagement',
        });
      });
    }
  }
);

// Scheduled function
export const dailyReport = inngest.createFunction(
  { id: 'daily-report' },
  { cron: '0 9 * * *' }, // 9 AM daily
  async ({ step }) => {
    const accounts = await step.run('get-accounts', async () => {
      return db.account.findMany({ where: { isActive: true } });
    });

    // Fan out to process each account
    await Promise.all(
      accounts.map((account) =>
        step.run(`generate-report-${account.id}`, async () => {
          await reportService.generateDaily(account.id);
        })
      )
    );
  }
);
```

### API Route Handler

```typescript
// app/api/inngest/route.ts
import { serve } from 'inngest/next';
import { inngest } from '@/lib/inngest/client';
import {
  sendWelcomeEmail,
  onboardingWorkflow,
  dailyReport,
} from '@/lib/inngest/functions';

export const { GET, POST, PUT } = serve({
  client: inngest,
  functions: [sendWelcomeEmail, onboardingWorkflow, dailyReport],
});
```

### Triggering Events

```typescript
// In your application code
import { inngest } from '@/lib/inngest/client';

// After user creation
await inngest.send({
  name: 'user/created',
  data: {
    userId: user.id,
    email: user.email,
  },
});

// After order placement
await inngest.send({
  name: 'order/placed',
  data: {
    orderId: order.id,
    total: order.total,
  },
});
```

## Trigger.dev

### Setup

```typescript
// trigger.ts
import { TriggerClient } from '@trigger.dev/sdk';

export const client = new TriggerClient({
  id: 'my-app',
  apiKey: process.env.TRIGGER_API_KEY!,
});
```

### Jobs

```typescript
// jobs/process-order.ts
import { client } from '@/trigger';
import { eventTrigger } from '@trigger.dev/sdk';
import { z } from 'zod';

client.defineJob({
  id: 'process-order',
  name: 'Process Order',
  version: '1.0.0',
  trigger: eventTrigger({
    name: 'order.created',
    schema: z.object({
      orderId: z.string(),
      items: z.array(z.object({
        productId: z.string(),
        quantity: z.number(),
      })),
    }),
  }),
  run: async (payload, io) => {
    // Reserve inventory
    await io.runTask('reserve-inventory', async () => {
      for (const item of payload.items) {
        await inventoryService.reserve(item.productId, item.quantity);
      }
    });

    // Process payment
    const payment = await io.runTask('process-payment', async () => {
      return paymentService.charge(payload.orderId);
    });

    // Send confirmation
    await io.runTask('send-confirmation', async () => {
      await emailService.sendOrderConfirmation(payload.orderId);
    });

    // Schedule delivery reminder
    await io.sendEvent('schedule-reminder', {
      name: 'order.reminder',
      payload: { orderId: payload.orderId },
      deliverAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24h later
    });

    return { success: true, paymentId: payment.id };
  },
});
```

## Scheduled Tasks Patterns

### Cron Jobs with BullMQ

```typescript
// lib/queue/scheduler.ts
import { reportQueue } from './queues';

export async function setupScheduledJobs() {
  // Daily cleanup at 2 AM
  await reportQueue.add(
    'cleanup',
    { type: 'cleanup' },
    {
      repeat: {
        pattern: '0 2 * * *',
        tz: 'America/New_York',
      },
      jobId: 'daily-cleanup', // Prevent duplicates
    }
  );

  // Weekly digest every Monday at 9 AM
  await reportQueue.add(
    'weekly-digest',
    { type: 'digest' },
    {
      repeat: {
        pattern: '0 9 * * 1',
        tz: 'America/New_York',
      },
      jobId: 'weekly-digest',
    }
  );

  // Every 5 minutes health check
  await reportQueue.add(
    'health-check',
    { type: 'health' },
    {
      repeat: {
        every: 5 * 60 * 1000,
      },
      jobId: 'health-check',
    }
  );
}
```

### Node-cron Alternative

```typescript
// lib/scheduler.ts
import cron from 'node-cron';
import { createLogger } from '@/lib/logger';

const logger = createLogger('scheduler');

export function startScheduler() {
  // Daily cleanup at 2 AM
  cron.schedule('0 2 * * *', async () => {
    logger.info('Running daily cleanup');
    try {
      await cleanupService.run();
      logger.info('Daily cleanup completed');
    } catch (error) {
      logger.error('Daily cleanup failed', { error });
    }
  });

  // Every hour - sync external data
  cron.schedule('0 * * * *', async () => {
    logger.info('Running hourly sync');
    await syncService.run();
  });

  logger.info('Scheduler started');
}
```

## Error Handling & Retries

### Custom Retry Strategy

```typescript
// lib/queue/retry-strategy.ts
import { Job } from 'bullmq';

export function getBackoffDelay(job: Job): number {
  const attempt = job.attemptsMade;

  // Exponential backoff with jitter
  const baseDelay = 1000;
  const maxDelay = 30 * 60 * 1000; // 30 minutes
  const exponentialDelay = Math.min(baseDelay * Math.pow(2, attempt), maxDelay);
  const jitter = Math.random() * 1000;

  return exponentialDelay + jitter;
}

// In worker
const worker = new Worker('my-queue', processor, {
  connection,
  settings: {
    backoffStrategy: (attemptsMade) => {
      return Math.min(1000 * Math.pow(2, attemptsMade), 30 * 60 * 1000);
    },
  },
});
```

### Dead Letter Queue

```typescript
// lib/queue/dlq.ts
import { Queue, Worker } from 'bullmq';
import { connection } from './connection';

export const deadLetterQueue = new Queue('dead-letter', { connection });

// Move failed jobs to DLQ after max attempts
export async function handleFailedJob(job: Job, error: Error) {
  if (job.attemptsMade >= (job.opts.attempts || 3)) {
    await deadLetterQueue.add('failed', {
      originalQueue: job.queueName,
      originalJobId: job.id,
      data: job.data,
      error: {
        message: error.message,
        stack: error.stack,
      },
      failedAt: new Date().toISOString(),
      attempts: job.attemptsMade,
    });
  }
}

// DLQ processor - for manual review/retry
export const dlqWorker = new Worker(
  'dead-letter',
  async (job) => {
    // Log for alerting
    logger.error('Job in dead letter queue', {
      originalQueue: job.data.originalQueue,
      originalJobId: job.data.originalJobId,
      error: job.data.error,
    });

    // Could send to Sentry, Slack, etc.
    await alertService.sendAlert({
      type: 'dlq',
      job: job.data,
    });
  },
  { connection }
);
```

## Monitoring

### Queue Dashboard (Bull Board)

```typescript
// app/api/admin/queues/route.ts
import { createBullBoard } from '@bull-board/api';
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter';
import { ExpressAdapter } from '@bull-board/express';
import { emailQueue, imageQueue, reportQueue } from '@/lib/queue/queues';

const serverAdapter = new ExpressAdapter();
serverAdapter.setBasePath('/api/admin/queues');

createBullBoard({
  queues: [
    new BullMQAdapter(emailQueue),
    new BullMQAdapter(imageQueue),
    new BullMQAdapter(reportQueue),
  ],
  serverAdapter,
});

export const GET = serverAdapter.getRouter();
export const POST = serverAdapter.getRouter();
```

### Metrics

```typescript
// lib/queue/metrics.ts
import { Queue } from 'bullmq';

export async function getQueueMetrics(queue: Queue) {
  const [waiting, active, completed, failed, delayed] = await Promise.all([
    queue.getWaitingCount(),
    queue.getActiveCount(),
    queue.getCompletedCount(),
    queue.getFailedCount(),
    queue.getDelayedCount(),
  ]);

  return {
    name: queue.name,
    waiting,
    active,
    completed,
    failed,
    delayed,
    total: waiting + active + completed + failed + delayed,
  };
}

// Expose via API
export async function GET() {
  const metrics = await Promise.all([
    getQueueMetrics(emailQueue),
    getQueueMetrics(imageQueue),
    getQueueMetrics(reportQueue),
  ]);

  return Response.json(metrics);
}
```

## Best Practices

### Idempotency

```typescript
// Ensure jobs can be safely retried
async function processPayment(job: Job<PaymentJob>) {
  const { orderId, amount } = job.data;

  // Check if already processed
  const existingPayment = await db.payment.findFirst({
    where: {
      orderId,
      idempotencyKey: job.id, // Use job ID as idempotency key
    },
  });

  if (existingPayment) {
    return { alreadyProcessed: true, paymentId: existingPayment.id };
  }

  // Process payment
  const payment = await paymentService.charge({
    orderId,
    amount,
    idempotencyKey: job.id,
  });

  return { paymentId: payment.id };
}
```

### Job Timeouts

```typescript
// Set appropriate timeouts
const job = await queue.add('process', data, {
  timeout: 30000, // 30 seconds

  // Or use worker-level timeout
});

// In worker
const worker = new Worker(
  'my-queue',
  async (job) => {
    // Use AbortController for cleanup
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 25000);

    try {
      await longRunningTask({ signal: controller.signal });
    } finally {
      clearTimeout(timeout);
    }
  },
  { connection }
);
```

## Checklist

### Setup
- [ ] Queue provider configured (Redis/serverless)
- [ ] Workers deployed and running
- [ ] Dashboard accessible for monitoring
- [ ] Alerts configured for failures

### Job Design
- [ ] Jobs are idempotent
- [ ] Appropriate retry strategy
- [ ] Timeouts configured
- [ ] Dead letter queue for failed jobs

### Reliability
- [ ] Graceful shutdown handling
- [ ] Progress tracking for long jobs
- [ ] Error logging with context
- [ ] Rate limiting where needed

### Operations
- [ ] Metrics exposed
- [ ] Scheduled jobs documented
- [ ] Cleanup of old jobs
- [ ] Scaling strategy defined

# Testing Guide

Comprehensive guide for testing standards across web (Vitest, Playwright) and mobile (Flutter) applications, ensuring production-ready code with 80%+ coverage.

## Table of Contents

- [Overview](#overview)
- [Vitest Configuration](#vitest-configuration)
- [Playwright E2E Testing](#playwright-e2e-testing)
- [Flutter Testing](#flutter-testing)
- [Test Organization](#test-organization)
- [Coverage Requirements](#coverage-requirements)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

### Testing Philosophy

**Test Pyramid**:
```
     /\
    /E2\    E2E Tests (10%)
   /----\   - Critical user journeys
  /Integ\  Integration Tests (30%)
 /------\  - API + Database interactions
/__Unit__\ Unit Tests (60%)
           - Business logic, utilities
```

**Key Principles**:
1. **80% Coverage Threshold** - Branches, functions, lines, statements
2. **Separate TEST Instance** - Never corrupt dev data
3. **Fast Feedback** - Unit tests run in <5s, integration in <30s
4. **Deterministic** - No flaky tests (retry only for true network issues)
5. **RLS Validation** - Test security policies with dual-client architecture

### Performance Targets

| Test Type | Target | Actual (Ballee) |
|-----------|--------|-----------------|
| Unit Tests | <5s | ~3s |
| Integration Tests | <30s | ~15s |
| E2E Tests | <2min | ~45s |
| Full Suite | <5min | ~3min |

## Vitest Configuration

### Basic Setup

**`vitest.config.ts`**:
```typescript
import path from 'path';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react()],
  esbuild: {
    jsx: 'automatic',
    jsxImportSource: 'react',
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'],
    globalSetup: ['./app/__tests__/setup/global-setup.ts'],
    testTimeout: 60000,  // 60s for E2E tests with DB operations
    hookTimeout: 120000, // 120s for beforeEach/afterEach (E2E setup)
    include: ['**/*.{test,spec}.{ts,tsx}'],
    exclude: [
      'node_modules',
      '.next',
      'coverage',
      './e2e/**', // Legacy Playwright e2e directory
    ],
    pool: 'forks', // Isolate tests
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        '.next/',
        'coverage/',
        '**/*.d.ts',
        '**/*.config.{ts,js}',
        '**/middleware.ts',
        'supabase/',
        '__tests__/',
        '**/*.test.{ts,tsx}',
        '**/*.spec.{ts,tsx}',
      ],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80,
        },
      },
    },
    env: {
      // Supabase TEST instance (port 54421, separate from dev on 54321)
      NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54421',
      NEXT_PUBLIC_SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
      SUPABASE_SERVICE_ROLE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    },
  },
  resolve: {
    alias: {
      '~': path.resolve(__dirname, './'),
      '@': path.resolve(__dirname, './'),
      'server-only': path.resolve(__dirname, './vitest-mocks/server-only.ts'),
      '@sentry/nextjs': path.resolve(__dirname, './vitest-mocks/sentry-nextjs.ts'),
    },
  },
});
```

### Separate TEST Instance Pattern

**Why Separate Instance?**
- Prevents test data from corrupting dev database
- Allows parallel test execution without conflicts
- Enables clean slate for each test run
- Safe to reset/truncate tables

**Setup**:
```bash
# Start TEST instance on port 54421 (dev uses 54321)
supabase start --port 54421

# Or use Docker Compose
docker-compose -f docker-compose.test.yml up -d
```

**Environment Variables**:
```typescript
// vitest.config.ts
env: {
  NEXT_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54421', // Note: 54421, not 54321
  NEXT_PUBLIC_SUPABASE_ANON_KEY: '...',
  SUPABASE_SERVICE_ROLE_KEY: '...',
}
```

### Setup Files

**`vitest.setup.ts`** (runs before each test file):
```typescript
import '@testing-library/jest-dom';
import { cleanup } from '@testing-library/react';
import { afterEach, vi } from 'vitest';

// Cleanup after each test
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});

// Mock next/navigation
vi.mock('next/navigation', () => ({
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
    prefetch: vi.fn(),
  }),
  usePathname: () => '/test',
  useSearchParams: () => new URLSearchParams(),
}));

// Mock server-only
vi.mock('server-only', () => ({}));
```

**`global-setup.ts`** (runs once before all tests):
```typescript
import { createClient } from '@supabase/supabase-js';

export async function setup() {
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );

  // Reset test database
  await supabase.rpc('reset_test_data');

  // Seed with base data
  await supabase.from('accounts').insert([
    { id: 'test-account-1', name: 'Test Account' },
  ]);

  console.log('✅ Test database ready');
}

export async function teardown() {
  console.log('✅ Tests complete');
}
```

### Timeouts

**Adjust based on test type**:

```typescript
test: {
  testTimeout: 60000,  // 60s for E2E tests involving DB
  hookTimeout: 120000, // 120s for beforeEach/afterEach (E2E setup)
}
```

**Per-test overrides**:
```typescript
it('slow operation', async () => {
  // This test gets 5 minutes
}, 300000);
```

### Coverage Thresholds

**Global Requirements** (80% minimum):
```typescript
coverage: {
  thresholds: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
}
```

**Per-file Requirements** (optional):
```typescript
coverage: {
  thresholds: {
    'src/lib/critical-module.ts': {
      branches: 95,
      functions: 95,
      lines: 95,
      statements: 95,
    },
  },
}
```

### Module Aliasing

**Monorepo Package Resolution**:
```typescript
resolve: {
  alias: {
    '@kit/ui/button': path.resolve(__dirname, '../../packages/ui/src/shadcn/button.tsx'),
    '@kit/ui/dialog': path.resolve(__dirname, '../../packages/ui/src/shadcn/dialog.tsx'),
    '@kit/supabase': path.resolve(__dirname, '../../packages/supabase/src'),
  },
}
```

**Why Explicit Aliases?**
- Vite doesn't resolve package.json exports in tests
- Explicit paths ensure correct module loading
- Prevents "Cannot find module" errors

## Playwright E2E Testing

### Dual-Client Architecture for RLS Testing

**Purpose**: Validate Row Level Security policies with different user contexts.

**Pattern**:
```typescript
import { test as base } from '@playwright/test';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

// Extend base test with dual clients
const test = base.extend<{
  userClient: SupabaseClient;
  adminClient: SupabaseClient;
}>({
  userClient: async ({}, use) => {
    const client = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );

    await client.auth.signInWithPassword({
      email: 'user@test.com',
      password: 'test-password',
    });

    await use(client);
    await client.auth.signOut();
  },

  adminClient: async ({}, use) => {
    const client = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY! // Admin client bypasses RLS
    );

    await use(client);
  },
});

export { test };
```

### RLS Validation Tests

**Test Pattern**:
```typescript
import { test } from './fixtures/dual-client';
import { expect } from '@playwright/test';

test.describe('Events RLS', () => {
  test('users can only read events for their account', async ({ userClient, adminClient }) => {
    // Setup: Admin creates events for different accounts
    const { data: event1 } = await adminClient
      .from('events')
      .insert({ name: 'User Account Event', account_id: 'user-account' })
      .select()
      .single();

    const { data: event2 } = await adminClient
      .from('events')
      .insert({ name: 'Other Account Event', account_id: 'other-account' })
      .select()
      .single();

    // Test: User can only see their account's events
    const { data: userEvents } = await userClient
      .from('events')
      .select('*');

    expect(userEvents).toHaveLength(1);
    expect(userEvents[0].id).toBe(event1.id);

    // Test: User cannot see other account's events
    const { data: otherEvent } = await userClient
      .from('events')
      .select('*')
      .eq('id', event2.id)
      .single();

    expect(otherEvent).toBeNull();
  });

  test('super admin can see all events', async ({ adminClient }) => {
    // Setup: Create events for multiple accounts
    await adminClient.from('events').insert([
      { name: 'Event 1', account_id: 'account-1' },
      { name: 'Event 2', account_id: 'account-2' },
      { name: 'Event 3', account_id: 'account-3' },
    ]);

    // Test: Admin sees all events
    const { data: allEvents } = await adminClient
      .from('events')
      .select('*');

    expect(allEvents).toHaveLength(3);
  });
});
```

### Auth-Based Project Configuration

**`playwright.config.ts`**:
```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
  },

  // Auth-based projects for different user roles
  projects: [
    {
      name: 'setup',
      testMatch: /.*\.setup\.ts/,
    },
    {
      name: 'logged-out',
      use: { ...devices['Desktop Chrome'] },
      dependencies: ['setup'],
    },
    {
      name: 'user',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'playwright/.auth/user.json',
      },
      dependencies: ['setup'],
    },
    {
      name: 'admin',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'playwright/.auth/admin.json',
      },
      dependencies: ['setup'],
    },
  ],

  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

### Auth Setup Script

**`e2e/auth.setup.ts`**:
```typescript
import { test as setup, expect } from '@playwright/test';

const userAuthFile = 'playwright/.auth/user.json';
const adminAuthFile = 'playwright/.auth/admin.json';

setup('authenticate as user', async ({ page }) => {
  await page.goto('/sign-in');
  await page.fill('input[name="email"]', 'user@test.com');
  await page.fill('input[name="password"]', 'test-password');
  await page.click('button[type="submit"]');
  await page.waitForURL('/home/**');

  await page.context().storageState({ path: userAuthFile });
});

setup('authenticate as admin', async ({ page }) => {
  await page.goto('/sign-in');
  await page.fill('input[name="email"]', 'admin@test.com');
  await page.fill('input[name="password"]', 'admin-password');
  await page.click('button[type="submit"]');
  await page.waitForURL('/admin/**');

  await page.context().storageState({ path: adminAuthFile });
});
```

### Sequential vs Parallel Execution

**Sequential** (when tests modify shared state):
```typescript
test.describe.serial('User onboarding flow', () => {
  test('step 1: create account', async ({ page }) => {
    // ...
  });

  test('step 2: complete profile', async ({ page }) => {
    // ...
  });

  test('step 3: verify email', async ({ page }) => {
    // ...
  });
});
```

**Parallel** (when tests are independent):
```typescript
test.describe.parallel('Event listing', () => {
  test('filter by category', async ({ page }) => {
    // ...
  });

  test('search by name', async ({ page }) => {
    // ...
  });

  test('sort by date', async ({ page }) => {
    // ...
  });
});
```

## Flutter Testing

### Test Types

#### 1. Unit Tests

**Purpose**: Test business logic, utilities, and models.

```dart
// test/core/utils/date_formatter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/utils/date_formatter.dart';

void main() {
  group('DateFormatter', () {
    test('formats date correctly', () {
      final date = DateTime(2026, 1, 13);
      final result = DateFormatter.format(date);

      expect(result, '2026-01-13');
    });

    test('handles null dates', () {
      final result = DateFormatter.format(null);

      expect(result, '');
    });
  });
}
```

#### 2. Widget Tests

**Purpose**: Test UI components in isolation.

```dart
// test/features/events/widgets/event_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/events/widgets/event_card.dart';

void main() {
  testWidgets('EventCard displays event details', (tester) async {
    final event = Event(
      id: '1',
      name: 'Test Event',
      date: DateTime(2026, 1, 13),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventCard(event: event),
        ),
      ),
    );

    expect(find.text('Test Event'), findsOneWidget);
    expect(find.text('2026-01-13'), findsOneWidget);
  });
}
```

#### 3. Golden Tests

**Purpose**: Visual regression testing.

```dart
// test/features/events/widgets/event_card_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/events/widgets/event_card.dart';

void main() {
  testWidgets('EventCard golden test', (tester) async {
    final event = Event(
      id: '1',
      name: 'Test Event',
      date: DateTime(2026, 1, 13),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventCard(event: event),
        ),
      ),
    );

    await expectLater(
      find.byType(EventCard),
      matchesGoldenFile('event_card.png'),
    );
  });
}
```

**Update Goldens**:
```bash
flutter test --update-goldens
```

#### 4. Integration Tests

**Purpose**: Test full feature flows with real backend.

```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete event booking flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Navigate to events
    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();

    // Select event
    await tester.tap(find.text('Test Event').first);
    await tester.pumpAndSettle();

    // Book event
    await tester.tap(find.text('Book Now'));
    await tester.pumpAndSettle();

    // Verify confirmation
    expect(find.text('Booking Confirmed'), findsOneWidget);
  });
}
```

### Riverpod Mocking

**Pattern for Mocking Providers**:

```dart
// test/features/events/screens/event_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/events/providers/events_provider.dart';
import 'package:my_app/features/events/screens/event_list_screen.dart';

void main() {
  testWidgets('EventListScreen displays events', (tester) async {
    // Mock events
    final mockEvents = [
      Event(id: '1', name: 'Event 1'),
      Event(id: '2', name: 'Event 2'),
    ];

    // Create ProviderScope with overrides
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventsProvider.overrideWith((ref) => mockEvents),
        ],
        child: const MaterialApp(
          home: EventListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Event 1'), findsOneWidget);
    expect(find.text('Event 2'), findsOneWidget);
  });
}
```

### Query Validation Against Schema

**Static Validation** (`scripts/validate_queries.dart`):
```dart
import 'dart:io';
import 'package:path/path.dart' as path;

void main() async {
  final projectRoot = Directory.current.path;
  final apiDir = Directory(path.join(projectRoot, 'lib', 'core', 'api'));

  final files = apiDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final content = await file.readAsString();

    // Check for common query issues
    if (content.contains('.select()') && !content.contains('.select(')) {
      print('❌ Missing select columns in ${file.path}');
      exit(1);
    }

    // Add more validation rules
  }

  print('✅ Query validation passed');
}
```

### Test Configuration

**`test/flutter_test_config.dart`**:
```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() async {
    // Global setup
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  await testMain();
}
```

## Test Organization

### Directory Structure

```
project/
├── __tests__/              # Web integration tests
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   ├── security/           # RLS and security tests
│   └── setup/              # Global setup/teardown
├── e2e/                    # Playwright E2E tests
│   ├── auth.setup.ts       # Auth setup
│   ├── fixtures/           # Custom fixtures
│   └── tests/              # E2E test files
└── apps/mobile/
    ├── test/               # Flutter unit/widget tests
    │   ├── core/           # Core logic tests
    │   ├── features/       # Feature tests
    │   └── widgets/        # Widget tests
    └── integration_test/   # Flutter integration tests
```

### Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Unit test | `*.test.ts` | `user-service.test.ts` |
| Integration test | `*.integration.test.ts` | `events-api.integration.test.ts` |
| E2E test | `*.spec.ts` | `booking-flow.spec.ts` |
| Flutter unit | `*_test.dart` | `date_formatter_test.dart` |
| Flutter widget | `*_widget_test.dart` | `event_card_widget_test.dart` |
| Flutter golden | `*_golden_test.dart` | `event_card_golden_test.dart` |

### Test File Location

**Co-located with source** (Next.js):
```
src/
├── lib/
│   ├── services/
│   │   ├── user-service.ts
│   │   └── user-service.test.ts
│   └── utils/
│       ├── date-formatter.ts
│       └── date-formatter.test.ts
```

**Separate test directory** (Flutter):
```
lib/
├── core/
│   └── utils/
│       └── date_formatter.dart
test/
└── core/
    └── utils/
        └── date_formatter_test.dart
```

## Coverage Requirements

### Global Thresholds (80% Minimum)

```typescript
coverage: {
  thresholds: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
}
```

### Exemptions

**Acceptable Coverage Gaps**:
- Auto-generated code (Freezed, Riverpod generators)
- Third-party integrations (mock in tests)
- UI-only components (golden tests instead)
- Configuration files

**Enforce Exemptions**:
```typescript
coverage: {
  exclude: [
    '**/*.g.dart',           // Generated files
    '**/*.freezed.dart',     // Freezed generated
    '**/main.dart',          // App entry point
    '**/*.config.ts',        // Config files
  ],
}
```

### Per-File Requirements

**Critical Modules** (95% coverage):
- Authentication logic
- Payment processing
- Data validation
- Security middleware

```typescript
coverage: {
  thresholds: {
    'src/lib/auth/*': { branches: 95, functions: 95, lines: 95, statements: 95 },
    'src/lib/payments/*': { branches: 95, functions: 95, lines: 95, statements: 95 },
  },
}
```

## Best Practices

### 1. Test Naming

✅ **Good**:
```typescript
describe('UserService', () => {
  describe('createUser', () => {
    it('creates user with valid data', async () => {});
    it('throws error when email already exists', async () => {});
    it('sends welcome email after creation', async () => {});
  });
});
```

❌ **Bad**:
```typescript
describe('UserService', () => {
  it('test1', async () => {});
  it('works', async () => {});
  it('error handling', async () => {});
});
```

### 2. AAA Pattern (Arrange, Act, Assert)

```typescript
it('creates user with valid data', async () => {
  // Arrange
  const userData = {
    email: 'test@example.com',
    name: 'Test User',
  };

  // Act
  const result = await userService.create(userData);

  // Assert
  expect(result.success).toBe(true);
  expect(result.data.email).toBe(userData.email);
});
```

### 3. Test Isolation

**Reset State Between Tests**:
```typescript
beforeEach(async () => {
  await resetDatabase();
  vi.clearAllMocks();
});
```

**Avoid Shared State**:
```typescript
// ❌ Bad: Shared state
let user: User;

beforeAll(async () => {
  user = await createUser();
});

it('test 1', () => {
  user.name = 'Modified'; // Affects other tests!
});

// ✅ Good: Fresh state per test
it('test 1', async () => {
  const user = await createUser();
  user.name = 'Modified'; // Only affects this test
});
```

### 4. Deterministic Tests

**Avoid Time-Based Tests**:
```typescript
// ❌ Bad
it('expires after 1 hour', async () => {
  const token = generateToken();
  await sleep(3600000); // Wait 1 hour!
  expect(isExpired(token)).toBe(true);
});

// ✅ Good
it('expires after 1 hour', () => {
  vi.setSystemTime(new Date('2026-01-13T10:00:00'));
  const token = generateToken();

  vi.setSystemTime(new Date('2026-01-13T11:00:01'));
  expect(isExpired(token)).toBe(true);
});
```

### 5. Mock External Dependencies

```typescript
// Mock Supabase client
vi.mock('@supabase/supabase-js', () => ({
  createClient: vi.fn(() => ({
    from: vi.fn(() => ({
      select: vi.fn(() => ({
        data: mockData,
        error: null,
      })),
    })),
  })),
}));
```

## Troubleshooting

### Common Issues

#### 1. Tests Pass Locally, Fail in CI

**Causes**:
- Timing issues (async operations)
- Environment differences (ports, URLs)
- Database not reset between test runs

**Solutions**:
```typescript
// Increase timeouts in CI
test: {
  testTimeout: process.env.CI ? 120000 : 60000,
}

// Ensure database reset
beforeEach(async () => {
  if (process.env.CI) {
    await resetDatabase({ force: true });
  }
});
```

#### 2. Flaky Tests

**Symptom**: Test passes sometimes, fails other times.

**Common Causes**:
- Race conditions (async operations)
- Shared state between tests
- Time-based assertions

**Solutions**:
```typescript
// ❌ Bad: Race condition
it('loads data', async () => {
  loadData();
  expect(data).toBeDefined(); // Might not be loaded yet!
});

// ✅ Good: Wait for operation
it('loads data', async () => {
  await loadData();
  expect(data).toBeDefined();
});
```

#### 3. Module Resolution Errors

**Symptom**: `Cannot find module '@kit/ui/button'`

**Solution**: Add explicit aliases in vitest.config.ts:
```typescript
resolve: {
  alias: {
    '@kit/ui/button': path.resolve(__dirname, '../../packages/ui/src/shadcn/button.tsx'),
  },
}
```

#### 4. Coverage Below Threshold

**Symptom**: Coverage drops below 80% after adding new code.

**Solutions**:
```bash
# Check coverage report
pnpm coverage

# Identify untested files
open coverage/index.html

# Write tests for uncovered code
```

#### 5. Slow Tests

**Symptom**: Test suite takes >5 minutes.

**Solutions**:
```typescript
// Use test.concurrent for independent tests
test.concurrent('test 1', async () => {});
test.concurrent('test 2', async () => {});

// Mock expensive operations
vi.mock('./expensive-operation', () => ({
  expensiveOperation: vi.fn(() => 'mocked result'),
}));

// Use Turborepo caching
pnpm turbo test --cache-dir=.turbo
```

---

**Last Updated**: 2026-01-13
**Related**: [HOOKS_GUIDE.md](HOOKS_GUIDE.md), [QUALITY_GATES_GUIDE.md](QUALITY_GATES_GUIDE.md)

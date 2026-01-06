---
description: Comprehensive Flutter development patterns for Ballee mobile app. Covers architecture, Riverpod 3.x state management, Supabase integration, error handling, performance optimization, and navigation.
version: "2.0.0"
updated: "2025-12-22"
---

# Flutter Development Patterns

Comprehensive guide for building features in the Ballee mobile app.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Module Structure](#module-structure)
3. [Riverpod 3.x State Management](#riverpod-3x-state-management)
4. [Supabase Integration](#supabase-integration)
5. [Error Handling](#error-handling)
6. [Performance Optimization](#performance-optimization)
7. [Navigation with GoRouter](#navigation-with-gorouter)
8. [Code Generation](#code-generation)

---

## Architecture Overview

Ballee mobile uses a **3-layer architecture** based on ApparenceKit:

```
┌─────────────────────────────────────────────────────────┐
│                   PRESENTATION LAYER                     │
│  Pages (UI) ←→ Providers/Notifiers ←→ Page State Models │
├─────────────────────────────────────────────────────────┤
│                     DOMAIN LAYER                         │
│         Repositories ←→ Domain Models (Freezed)          │
├─────────────────────────────────────────────────────────┤
│                      DATA LAYER                          │
│              APIs ←→ Entities (JSON serialization)       │
└─────────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Purpose | Key Classes |
|-------|---------|-------------|
| **Data (API)** | Fetch data, handle serialization | `*Api`, `*Entity` |
| **Domain** | Business logic, transform entities to models | `*Repository`, domain models |
| **Presentation** | UI state, user interactions | `*Notifier`, `*PageState`, Pages |

---

## Module Structure

### Folder Layout

```
apps/mobile/lib/
├── core/                          # Shared utilities
│   ├── data/api/                  # Shared API clients, error types
│   ├── guards/                    # Route guards
│   ├── states/                    # Global state (user, auth)
│   ├── theme/                     # App theming
│   └── widgets/                   # Shared widgets
└── modules/                       # Feature modules
    └── <module_name>/
        ├── api/
        │   ├── <module>_api.dart
        │   └── entities/
        │       └── <entity>_entity.dart
        ├── domain/
        │   └── <model>.dart
        ├── repositories/
        │   └── <module>_repository.dart
        ├── providers/
        │   ├── <module>_notifier.dart
        │   └── models/
        │       └── <module>_page_state.dart
        └── ui/
            ├── <module>_page.dart
            ├── components/        # Smart widgets (use providers)
            └── widgets/           # Dumb widgets (pure Flutter)
```

### Creating a New Module

```bash
# Example: Creating a "payments" module
mkdir -p lib/modules/payments/{api/entities,domain,repositories,providers/models,ui/{components,widgets}}
```

---

## Riverpod 3.x State Management

### Key Changes from 2.x

Riverpod 3.0 introduces breaking changes. See [migration guide](https://riverpod.dev/docs/3.0_migration).

```dart
// OLD (Riverpod 2.x) - Don't use
@riverpod
EventsApi eventsApi(EventsApiRef ref) { ... }

// NEW (Riverpod 3.0) - Use this
@riverpod
EventsApi eventsApi(Ref ref) { ... }  // Unified Ref, no type parameter
```

### Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^2.6.0
  riverpod_annotation: ^2.6.0

dev_dependencies:
  riverpod_generator: ^2.6.0
  build_runner: ^2.4.0
```

### Provider Types

#### 1. Simple Provider (Dependency Injection)

```dart
// api/events_api.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_api.g.dart';

@riverpod
EventsApi eventsApi(Ref ref) {
  return EventsApi(client: Supabase.instance.client);
}
```

#### 2. AsyncNotifier (Page State)

```dart
// providers/events_list_notifier.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'events_list_notifier.g.dart';

@riverpod
class EventsListNotifier extends _$EventsListNotifier {
  @override
  Future<EventsPageState> build() async {
    final repository = ref.read(eventsRepositoryProvider);
    final events = await repository.getOpenEvents();
    return EventsPageState(events: events);
  }

  /// Sync mutation
  void setFilter(EventFilter filter) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(filter: filter));
  }

  /// Async mutation with optimistic update
  Future<void> expressInterest(String eventId, InterestLevel level) async {
    // Optimistic update
    state = state.whenData((data) => data.copyWith(
      events: data.events.map((e) =>
        e.event.id == eventId ? e.copyWith(interestLevel: level) : e
      ).toList(),
    ));

    try {
      await ref.read(eventsRepositoryProvider).updateParticipation(eventId, level);
    } catch (e) {
      ref.invalidateSelf(); // Revert on error
      rethrow;
    }
  }

  /// Pull to refresh
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
```

#### 3. Family Provider (Parameterized)

```dart
@riverpod
class EventDetailNotifier extends _$EventDetailNotifier {
  @override
  Future<EventDetail> build(String eventId) async {
    final repository = ref.read(eventsRepositoryProvider);
    final event = await repository.getById(eventId);
    if (event == null) throw NotFoundException('Event not found');
    return event;
  }
}

// Usage
ref.watch(eventDetailNotifierProvider('event-123'));
```

#### 4. KeepAlive Provider (Global State)

```dart
@Riverpod(keepAlive: true)
class UserStateNotifier extends _$UserStateNotifier {
  @override
  Future<UserState> build() async {
    // Persists across navigation
    final auth = ref.watch(authStateNotifierProvider);
    // ...
  }
}
```

### Page State Models (Freezed)

```dart
// providers/models/events_page_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'events_page_state.freezed.dart';

@freezed
class EventsPageState with _$EventsPageState {
  const factory EventsPageState({
    required List<EventWithParticipation> events,
    @Default(EventFilter.all) EventFilter filter,
    @Default('') String searchQuery,
    @Default(false) bool isRefreshing,
  }) = _EventsPageState;

  const EventsPageState._();

  /// Computed property
  List<EventWithParticipation> get filteredEvents {
    var result = events;
    if (filter == EventFilter.interested) {
      result = result.where((e) => e.isInterested).toList();
    }
    if (searchQuery.isNotEmpty) {
      result = result.where((e) =>
        e.event.title.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }
    return result;
  }
}

enum EventFilter { all, interested, notResponded }
```

### UI Consumption Patterns

```dart
class EventsListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventsListNotifierProvider);

    return Scaffold(
      body: state.when(
        data: (data) => _EventsList(events: data.filteredEvents),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorWidget(
          error: error,
          onRetry: () => ref.invalidate(eventsListNotifierProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // READ in callbacks, WATCH in build
          ref.read(eventsListNotifierProvider.notifier).refresh();
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
```

### Listen for Side Effects

```dart
ref.listen(assignmentActionProvider, (previous, next) {
  next.whenOrNull(
    data: (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Success!')),
      );
      context.pop();
    },
    error: (error, _) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    },
  );
});
```

---

## Supabase Integration

### Initialization

```dart
// main.dart
await Supabase.initialize(
  url: 'https://your-project.supabase.co',
  anonKey: 'your-anon-key',
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
  ),
);
```

### Entity Definition

```dart
// api/entities/event_entity.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_entity.freezed.dart';
part 'event_entity.g.dart';

@freezed
class EventEntity with _$EventEntity {
  const factory EventEntity({
    required String id,
    required String title,
    @JsonKey(name: 'start_date_time') required DateTime startDateTime,
    @JsonKey(name: 'end_date_time') DateTime? endDateTime,
    @JsonKey(name: 'production_id') String? productionId,
    String? status,
    // Nested relations
    ProductionEntity? productions,
    VenueEntity? venues,
  }) = _EventEntity;

  factory EventEntity.fromJson(Map<String, dynamic> json) =>
      _$EventEntityFromJson(json);
}
```

### API Class

```dart
// api/events_api.dart
class EventsApi {
  final SupabaseClient _client;

  EventsApi({required SupabaseClient client}) : _client = client;

  String get _userId => _client.auth.currentUser!.id;

  /// Fetch with joins
  Future<List<EventEntity>> getOpenEvents() async {
    final response = await _client
        .from('events')
        .select('''
          id, title, start_date_time, end_date_time, status,
          productions(id, name, choreographer),
          venues(id, name, city, country)
        ''')
        .eq('status', 'active')
        .gte('start_date_time', DateTime.now().toIso8601String())
        .order('start_date_time', ascending: true);

    return response.map((json) => EventEntity.fromJson(json)).toList();
  }

  /// Single record
  Future<EventEntity?> getById(String id) async {
    final response = await _client
        .from('events')
        .select('*, productions(*), venues(*)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return EventEntity.fromJson(response);
  }

  /// Insert/Update
  Future<void> upsertParticipation({
    required String eventId,
    required String interestLevel,
  }) async {
    await _client.from('event_participants').upsert({
      'event_id': eventId,
      'performer_id': _userId,
      'interest_level': interestLevel,
      'response_date': DateTime.now().toIso8601String(),
    }, onConflict: 'event_id,performer_id');
  }

  /// RPC function
  Future<void> acceptAssignment(String assignmentId) async {
    await _client.rpc('respond_to_casting_invitation', params: {
      'p_assignment_id': assignmentId,
      'p_response': 'accepted',
    });
  }
}
```

### Repository (Entity → Domain)

```dart
// repositories/events_repository.dart
@riverpod
EventsRepository eventsRepository(Ref ref) {
  return EventsRepository(api: ref.read(eventsApiProvider));
}

class EventsRepository {
  final EventsApi _api;

  EventsRepository({required EventsApi api}) : _api = api;

  Future<List<Event>> getOpenEvents() async {
    final entities = await _api.getOpenEvents();
    return entities.map(Event.fromEntity).toList();
  }

  Future<Event?> getById(String id) async {
    final entity = await _api.getById(id);
    if (entity == null) return null;
    return Event.fromEntity(entity);
  }
}
```

### Domain Model with Factory

```dart
// domain/event.dart
@freezed
class Event with _$Event {
  const factory Event({
    required String id,
    required String title,
    required DateTime startDateTime,
    DateTime? endDateTime,
    String? productionName,
    String? venueName,
    String? city,
    required EventStatus status,
  }) = _Event;

  const Event._();

  bool get isUpcoming => startDateTime.isAfter(DateTime.now());

  factory Event.fromEntity(EventEntity entity) {
    return Event(
      id: entity.id,
      title: entity.title,
      startDateTime: entity.startDateTime,
      endDateTime: entity.endDateTime,
      productionName: entity.productions?.name,
      venueName: entity.venues?.name,
      city: entity.venues?.city,
      status: EventStatus.fromString(entity.status),
    );
  }
}
```

### Authentication

```dart
@Riverpod(keepAlive: true)
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  Stream<AuthState> build() {
    return Supabase.instance.client.auth.onAuthStateChange;
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signInWithApple() async {
    return await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'com.ballee.app://login-callback',
    );
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}
```

### Storage Uploads

```dart
Future<String> uploadProfilePhoto(File file) async {
  final userId = _client.auth.currentUser!.id;
  final extension = file.path.split('.').last;
  final path = '$userId/profile.$extension';

  await _client.storage.from('profile-photos').upload(
    path,
    file,
    fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
  );

  return _client.storage.from('profile-photos').getPublicUrl(path);
}
```

### Realtime Subscriptions

```dart
@riverpod
class AssignmentsRealtimeNotifier extends _$AssignmentsRealtimeNotifier {
  RealtimeChannel? _channel;

  @override
  Future<List<Assignment>> build() async {
    final assignments = await ref.read(assignmentsRepositoryProvider).getAll();
    _setupSubscription();
    ref.onDispose(() => _channel?.unsubscribe());
    return assignments;
  }

  void _setupSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _channel = Supabase.instance.client.channel('assignments:$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'cast_assignments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'performer_id',
          value: userId,
        ),
        callback: (_) => ref.invalidateSelf(),
      )
      .subscribe();
  }
}
```

---

## Error Handling

### Result Pattern

Use the Result pattern to force explicit error handling. No exceptions escape to the UI.

```dart
// core/data/result.dart
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Ok<T>;
  bool get isError => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Ok(value: final v) => v,
    Err() => null,
  };

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppException error) err,
  }) {
    return switch (this) {
      Ok(value: final v) => ok(v),
      Err(error: final e) => err(e),
    };
  }
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final AppException error;
  const Err(this.error);
}
```

### Exception Types

```dart
// core/data/exceptions.dart
sealed class AppException implements Exception {
  String get message;
}

class NetworkException extends AppException {
  @override
  final String message;
  NetworkException([this.message = 'Network error']);
}

class DatabaseException extends AppException {
  @override
  final String message;
  final String? code;
  DatabaseException(this.message, [this.code]);
}

class AuthException extends AppException {
  @override
  final String message;
  AuthException(this.message);
}

class NotFoundException extends AppException {
  @override
  final String message;
  NotFoundException([this.message = 'Not found']);
}
```

### Repository with Result

```dart
class EventsRepository {
  final EventsApi _api;

  Future<Result<List<Event>>> getOpenEvents() async {
    try {
      final entities = await _api.getOpenEvents();
      return Ok(entities.map(Event.fromEntity).toList());
    } on PostgrestException catch (e) {
      return Err(DatabaseException(e.message, e.code));
    } on SocketException {
      return Err(NetworkException());
    } catch (e) {
      return Err(DatabaseException(e.toString()));
    }
  }

  Future<Result<Event>> getById(String id) async {
    try {
      final entity = await _api.getById(id);
      if (entity == null) return Err(NotFoundException('Event not found'));
      return Ok(Event.fromEntity(entity));
    } on PostgrestException catch (e) {
      return Err(DatabaseException(e.message));
    }
  }
}
```

### Notifier with Result

```dart
@riverpod
class EventsListNotifier extends _$EventsListNotifier {
  @override
  Future<EventsPageState> build() async {
    final result = await ref.read(eventsRepositoryProvider).getOpenEvents();

    return result.when(
      ok: (events) => EventsPageState(events: events),
      err: (error) => throw error, // Let Riverpod handle as AsyncError
    );
  }
}
```

---

## Performance Optimization

### Build Method Best Practices

```dart
// BAD: Heavy work in build()
Widget build(BuildContext context) {
  final data = expensiveComputation(); // Called on every rebuild!
  return Text(data);
}

// GOOD: Pre-compute in provider
Widget build(BuildContext context) {
  final data = ref.watch(precomputedDataProvider);
  return Text(data);
}
```

### Use const Constructors

```dart
// BAD: Creates new instance every rebuild
return SizedBox(height: 16);

// GOOD: Reuses cached instance
return const SizedBox(height: 16);

// Enable lint rule in analysis_options.yaml:
// prefer_const_constructors: true
```

### Split Widgets to Minimize Rebuilds

```dart
// BAD: Entire widget rebuilds when counter changes
class BadExample extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterProvider);
    return Column(
      children: [
        const ExpensiveHeader(), // Rebuilds unnecessarily!
        Text('Count: $counter'),
        const ExpensiveFooter(), // Rebuilds unnecessarily!
      ],
    );
  }
}

// GOOD: Only CounterDisplay rebuilds
class GoodExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ExpensiveHeader(), // Never rebuilds
        const CounterDisplay(),  // Only this rebuilds
        const ExpensiveFooter(), // Never rebuilds
      ],
    );
  }
}

class CounterDisplay extends ConsumerWidget {
  const CounterDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterProvider);
    return Text('Count: $counter');
  }
}
```

### Avoid Widget Helper Methods

```dart
// BAD: No widget reuse, rebuilds every time
Widget _buildCard(Event event) {
  return Card(child: Text(event.title));
}

// GOOD: Extract to const widget class
class EventCard extends StatelessWidget {
  final Event event;
  const EventCard({required this.event, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(child: Text(event.title));
  }
}
```

### ListView Optimization

```dart
// BAD: Builds all items upfront
ListView(
  children: events.map((e) => EventCard(event: e)).toList(),
)

// GOOD: Lazy builds only visible items
ListView.builder(
  itemCount: events.length,
  itemBuilder: (context, index) => EventCard(event: events[index]),
)

// BEST: With keys for efficient updates
ListView.builder(
  itemCount: events.length,
  itemBuilder: (context, index) => EventCard(
    key: ValueKey(events[index].id),
    event: events[index],
  ),
)
```

### RepaintBoundary for Complex Widgets

```dart
// Isolate expensive repaints
RepaintBoundary(
  child: ComplexAnimatedWidget(),
)
```

---

## Navigation with GoRouter

### Basic Setup

```dart
// router.dart
final goRouterProvider = Provider<GoRouter>((ref) => generateRouter());

GoRouter generateRouter() {
  return GoRouter(
    initialLocation: '/',
    navigatorKey: navigatorKey,
    errorBuilder: (context, state) => const PageNotFound(),
    routes: [
      GoRoute(
        name: 'home',
        path: '/',
        builder: (context, state) => const UserInfosGuard(
          fallbackRoute: '/onboarding',
          child: BottomMenu(),
        ),
      ),
      GoRoute(
        name: 'event_detail',
        path: '/events/:eventId',
        builder: (context, state) => EventDetailPage(
          eventId: state.pathParameters['eventId']!,
        ),
      ),
      GoRoute(
        name: 'assignment_detail',
        path: '/assignments/:assignmentId',
        builder: (context, state) => AssignmentDetailPage(
          assignmentId: state.pathParameters['assignmentId']!,
        ),
      ),
    ],
  );
}
```

### Navigation Methods

```dart
// Navigate to route
context.go('/events/123');

// Push onto stack (can go back)
context.push('/events/123');

// Go back
context.pop();

// Replace current route
context.replace('/home');

// With named route
context.goNamed('event_detail', pathParameters: {'eventId': '123'});
```

### Type-Safe Routes (Optional)

For compile-time safety, use `go_router_builder`:

```yaml
# pubspec.yaml
dev_dependencies:
  go_router_builder: ^2.4.0
```

```dart
// routes.dart
part 'routes.g.dart';

@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData {
  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

@TypedGoRoute<EventDetailRoute>(path: '/events/:eventId')
class EventDetailRoute extends GoRouteData {
  final String eventId;
  const EventDetailRoute({required this.eventId});

  @override
  Widget build(BuildContext context, GoRouterState state) =>
    EventDetailPage(eventId: eventId);
}

// Usage - compile-time safe!
EventDetailRoute(eventId: '123').go(context);
```

### Deep Link Configuration

**iOS (Info.plist):**
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.ballee.app</string>
    </array>
  </dict>
</array>
```

**Android (AndroidManifest.xml):**
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="com.ballee.app" android:host="login-callback" />
</intent-filter>
```

---

## Code Generation

### Run Build Runner

```bash
cd apps/mobile

# One-time build
dart run build_runner build --delete-conflicting-outputs

# Watch mode (development)
dart run build_runner watch --delete-conflicting-outputs
```

### Generated Files

| Annotation | Generated |
|------------|-----------|
| `@freezed` | `*.freezed.dart` |
| `@JsonSerializable` / `@freezed` with JSON | `*.g.dart` |
| `@riverpod` | `*.g.dart` |

### Import Conventions

Always use package imports:

```dart
// CORRECT
import 'package:apparence_kit/modules/events/domain/event.dart';

// INCORRECT
import '../domain/event.dart';
```

---

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `events_list_page.dart` |
| Classes | PascalCase | `EventsListPage` |
| Variables | camelCase | `eventsList` |
| Constants | SCREAMING_SNAKE | `MAX_EVENTS` |
| Entities | `*Entity` | `EventEntity` |
| APIs | `*Api` | `EventsApi` |
| Repositories | `*Repository` | `EventsRepository` |
| Notifiers | `*Notifier` | `EventsListNotifier` |
| Page States | `*PageState` | `EventsPageState` |

---

## Quick Reference

### Creating a New Feature

1. Create entity in `api/entities/`
2. Create API methods in `api/<module>_api.dart`
3. Create domain model in `domain/`
4. Create repository in `repositories/`
5. Create page state in `providers/models/`
6. Create notifier in `providers/`
7. Create page in `ui/`
8. Add route to `router.dart`
9. Run `dart run build_runner build --delete-conflicting-outputs`

### Checklist

- [ ] Entities use `@freezed` and `@JsonKey` for snake_case
- [ ] Domain models have `fromEntity` factory
- [ ] Repositories return `Result<T>` or handle errors
- [ ] Notifiers use `@riverpod` with unified `Ref`
- [ ] Page states have computed properties
- [ ] UI uses `state.when()` for loading/error/data
- [ ] `const` constructors used everywhere possible
- [ ] Widgets split to minimize rebuilds

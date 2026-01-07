# Flutter Development Patterns

Architecture and state management patterns for Flutter applications.

> **Template Usage:** Customize for your state management (Riverpod, Bloc, Provider) and backend (Supabase, Firebase, REST API).

## Architecture

### 3-Layer Architecture

```
lib/
├── core/                    # Shared utilities
│   ├── config/              # App configuration
│   ├── constants/           # App constants
│   ├── extensions/          # Dart extensions
│   ├── guards/              # Route guards
│   ├── theme/               # App theme
│   └── utils/               # Utility functions
├── modules/                 # Feature modules
│   ├── auth/
│   │   ├── data/            # Data layer (API, repositories)
│   │   ├── domain/          # Domain layer (models, interfaces)
│   │   └── presentation/    # UI layer (screens, widgets, providers)
│   ├── home/
│   └── profile/
├── shared/                  # Shared widgets and services
│   ├── widgets/
│   └── services/
└── main.dart
```

### Layer Responsibilities

| Layer | Contents | Dependencies |
|-------|----------|--------------|
| **Data** | API clients, repositories, DTOs | External packages, core |
| **Domain** | Models, interfaces, business logic | None (pure Dart) |
| **Presentation** | Screens, widgets, state | Domain, core |

## State Management (Riverpod)

### Provider Types

```dart
// Simple value provider
final appNameProvider = Provider<String>((ref) => 'My App');

// State provider (mutable)
final counterProvider = StateProvider<int>((ref) => 0);

// Future provider (async data)
final userProvider = FutureProvider<User>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getCurrentUser();
});

// Stream provider (real-time)
final messagesProvider = StreamProvider<List<Message>>((ref) {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.watchMessages();
});

// Notifier provider (complex state)
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() => const AuthState.initial();

  Future<void> signIn(String email, String password) async {
    state = const AuthState.loading();
    try {
      final user = await ref.read(authRepositoryProvider).signIn(email, password);
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState.initial();
  }
}
```

### Provider Organization

```dart
// lib/modules/auth/presentation/providers/auth_providers.dart

// Repository provider
@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
}

// State notifier
@riverpod
class Auth extends _$Auth {
  @override
  FutureOr<User?> build() async {
    return ref.watch(authRepositoryProvider).getCurrentUser();
  }

  // Methods...
}

// Derived providers
@riverpod
bool isAuthenticated(IsAuthenticatedRef ref) {
  return ref.watch(authProvider).valueOrNull != null;
}
```

## Models with Freezed

```dart
// lib/modules/user/domain/models/user.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    String? name,
    String? avatarUrl,
    @Default(false) bool isVerified,
    DateTime? createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

// Sealed class for states
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(User user) = _Authenticated;
  const factory AuthState.error(String message) = _Error;
}
```

## Repository Pattern

```dart
// lib/modules/user/data/repositories/user_repository.dart

abstract class UserRepository {
  Future<User?> getUser(String id);
  Future<List<User>> getUsers({int limit = 20, int offset = 0});
  Future<User> createUser(CreateUserInput input);
  Future<User> updateUser(String id, UpdateUserInput input);
  Future<void> deleteUser(String id);
  Stream<User> watchUser(String id);
}

class SupabaseUserRepository implements UserRepository {
  final SupabaseClient _client;

  SupabaseUserRepository(this._client);

  @override
  Future<User?> getUser(String id) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', id)
        .maybeSingle();

    return response != null ? User.fromJson(response) : null;
  }

  @override
  Future<List<User>> getUsers({int limit = 20, int offset = 0}) async {
    final response = await _client
        .from('users')
        .select()
        .range(offset, offset + limit - 1)
        .order('created_at', ascending: false);

    return response.map((json) => User.fromJson(json)).toList();
  }

  @override
  Stream<User> watchUser(String id) {
    return _client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((data) => User.fromJson(data.first));
  }
}
```

## Navigation (go_router)

```dart
// lib/core/router/app_router.dart

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authState),
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isAuthenticated && !isAuthRoute) {
        return '/auth/login';
      }
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'users/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return UserDetailScreen(userId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
        routes: [
          GoRoute(
            path: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: 'register',
            builder: (context, state) => const RegisterScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
});

// Navigation helper
extension GoRouterX on BuildContext {
  void goToUser(String id) => GoRouter.of(this).go('/users/$id');
  void goToProfile() => GoRouter.of(this).go('/profile');
}
```

## Error Handling

```dart
// lib/core/errors/app_exception.dart

sealed class AppException implements Exception {
  String get message;
}

class NetworkException extends AppException {
  @override
  final String message;
  final int? statusCode;

  NetworkException(this.message, {this.statusCode});
}

class AuthException extends AppException {
  @override
  final String message;

  AuthException(this.message);
}

class ValidationException extends AppException {
  @override
  final String message;
  final Map<String, String>? fieldErrors;

  ValidationException(this.message, {this.fieldErrors});
}

// Result type
@freezed
sealed class Result<T> with _$Result<T> {
  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(AppException error) = Failure<T>;
}

// Usage in repository
Future<Result<User>> getUser(String id) async {
  try {
    final response = await _client.from('users').select().eq('id', id).single();
    return Result.success(User.fromJson(response));
  } on PostgrestException catch (e) {
    return Result.failure(NetworkException(e.message, statusCode: e.code));
  } catch (e) {
    return Result.failure(NetworkException(e.toString()));
  }
}
```

## Form Handling

```dart
// Using flutter_form_builder + form_builder_validators

class LoginForm extends ConsumerWidget {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return FormBuilder(
      key: _formKey,
      child: Column(
        children: [
          FormBuilderTextField(
            name: 'email',
            decoration: const InputDecoration(labelText: 'Email'),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.email(),
            ]),
          ),
          FormBuilderTextField(
            name: 'password',
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.minLength(8),
            ]),
          ),
          ElevatedButton(
            onPressed: authState.isLoading ? null : _submit,
            child: authState.isLoading
                ? const CircularProgressIndicator()
                : const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      final values = _formKey.currentState!.value;
      ref.read(authProvider.notifier).signIn(
        values['email'] as String,
        values['password'] as String,
      );
    }
  }
}
```

## Performance Patterns

### Image Optimization

```dart
// Use cached_network_image
CachedNetworkImage(
  imageUrl: user.avatarUrl,
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  memCacheWidth: 200, // Resize in memory
)

// Preload images
precacheImage(CachedNetworkImageProvider(imageUrl), context);
```

### List Optimization

```dart
// Use ListView.builder for large lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemTile(item: items[index]),
)

// Use const constructors
class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.name),
    );
  }
}

// Avoid rebuilds with select
final userName = ref.watch(userProvider.select((u) => u.name));
```

### Async Initialization

```dart
// Preload data during splash
class SplashScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(initializationProvider).when(
      data: (_) {
        // Navigate to home
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/');
        });
        return const SizedBox.shrink();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorScreen(error: e.toString()),
    );
  }
}

@riverpod
Future<void> initialization(InitializationRef ref) async {
  // Preload essential data
  await Future.wait([
    ref.read(userProvider.future),
    ref.read(settingsProvider.future),
  ]);
}
```

## Code Generation

```bash
# Run build_runner for Freezed, Riverpod, JSON serialization
dart run build_runner build --delete-conflicting-outputs

# Watch mode during development
dart run build_runner watch --delete-conflicting-outputs
```

## Checklist

### Architecture
- [ ] 3-layer architecture (data, domain, presentation)
- [ ] Feature modules organized consistently
- [ ] Clear dependency direction (presentation -> domain <- data)
- [ ] Shared code in core/ or shared/

### State Management
- [ ] Appropriate provider type for each use case
- [ ] Providers disposed properly (autoDispose)
- [ ] No business logic in widgets
- [ ] Error states handled

### Models
- [ ] Freezed for immutable models
- [ ] JSON serialization configured
- [ ] Sealed classes for state variants
- [ ] Null safety enforced

### Navigation
- [ ] Route guards for protected screens
- [ ] Deep linking configured
- [ ] Error routes defined
- [ ] Type-safe route parameters

### Performance
- [ ] ListView.builder for lists
- [ ] const constructors used
- [ ] Images cached and sized
- [ ] Selective rebuilds with select()

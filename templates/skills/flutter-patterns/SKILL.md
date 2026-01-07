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

## Offline-First with Hive

### Setup

```dart
// lib/core/storage/hive_storage.dart
import 'package:hive_flutter/hive_flutter.dart';

class HiveStorage {
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters for custom types
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(SettingsAdapter());

    // Open boxes
    await Future.wait([
      Hive.openBox<User>('users'),
      Hive.openBox<Settings>('settings'),
      Hive.openBox('cache'),
    ]);
  }

  static Box<User> get usersBox => Hive.box<User>('users');
  static Box<Settings> get settingsBox => Hive.box<Settings>('settings');
  static Box get cacheBox => Hive.box('cache');

  static Future<void> clearAll() async {
    await Future.wait([
      usersBox.clear(),
      settingsBox.clear(),
      cacheBox.clear(),
    ]);
  }
}
```

### Cache-First Repository

```dart
// lib/modules/user/data/repositories/cached_user_repository.dart

class CachedUserRepository implements UserRepository {
  final SupabaseClient _client;
  final Box<User> _cache;
  final Duration _cacheValidity;

  CachedUserRepository(
    this._client,
    this._cache, {
    this._cacheValidity = const Duration(minutes: 5),
  });

  @override
  Future<User?> getUser(String id) async {
    // 1. Check cache first
    final cached = _cache.get(id);
    final cacheTime = _cache.get('${id}_timestamp') as DateTime?;

    final isCacheValid = cached != null &&
        cacheTime != null &&
        DateTime.now().difference(cacheTime) < _cacheValidity;

    if (isCacheValid) {
      return cached;
    }

    // 2. Fetch from network
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response != null) {
        final user = User.fromJson(response);
        // 3. Update cache
        await _cache.put(id, user);
        await _cache.put('${id}_timestamp', DateTime.now());
        return user;
      }
      return null;
    } catch (e) {
      // 4. Return stale cache on network error
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<void> invalidateCache(String id) async {
    await _cache.delete(id);
    await _cache.delete('${id}_timestamp');
  }
}
```

### Offline Queue for Mutations

```dart
// lib/core/sync/offline_queue.dart

@freezed
class QueuedOperation with _$QueuedOperation {
  const factory QueuedOperation({
    required String id,
    required String type,  // 'create', 'update', 'delete'
    required String table,
    required Map<String, dynamic> data,
    required DateTime createdAt,
    @Default(0) int retryCount,
  }) = _QueuedOperation;

  factory QueuedOperation.fromJson(Map<String, dynamic> json) =>
      _$QueuedOperationFromJson(json);
}

class OfflineQueue {
  final Box _queueBox;
  final SupabaseClient _client;

  OfflineQueue(this._queueBox, this._client);

  Future<void> enqueue(QueuedOperation operation) async {
    await _queueBox.put(operation.id, operation.toJson());
  }

  Future<void> processQueue() async {
    final operations = _queueBox.values
        .map((json) => QueuedOperation.fromJson(Map<String, dynamic>.from(json)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final op in operations) {
      try {
        await _processOperation(op);
        await _queueBox.delete(op.id);
      } catch (e) {
        // Increment retry count
        if (op.retryCount < 3) {
          await _queueBox.put(
            op.id,
            op.copyWith(retryCount: op.retryCount + 1).toJson(),
          );
        }
      }
    }
  }

  Future<void> _processOperation(QueuedOperation op) async {
    switch (op.type) {
      case 'create':
        await _client.from(op.table).insert(op.data);
      case 'update':
        await _client.from(op.table).update(op.data).eq('id', op.data['id']);
      case 'delete':
        await _client.from(op.table).delete().eq('id', op.data['id']);
    }
  }

  int get pendingCount => _queueBox.length;
}
```

## Push Notifications (FCM)

### Setup

```dart
// lib/core/notifications/push_notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return;
    }

    // Get FCM token
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToBackend(token);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_saveTokenToBackend);

    // Initialize local notifications
    await _initLocalNotifications();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check for initial message (app opened from terminated state)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        // Handle local notification tap
        _handleLocalNotificationTap(response.payload);
      },
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show local notification when app is in foreground
    _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'default_channel',
          'Default',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['route'],
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null) {
      // Navigate to the route
      // navigatorKey.currentState?.pushNamed(route);
    }
  }

  void _handleLocalNotificationTap(String? payload) {
    if (payload != null) {
      // Navigate to the route
    }
  }

  Future<void> _saveTokenToBackend(String token) async {
    // Save token to your backend
  }
}

// Must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
}
```

### Provider

```dart
@riverpod
PushNotificationService pushNotificationService(PushNotificationServiceRef ref) {
  return PushNotificationService();
}

@riverpod
Future<void> initNotifications(InitNotificationsRef ref) async {
  final service = ref.read(pushNotificationServiceProvider);
  await service.init();
}
```

## Biometric Authentication

```dart
// lib/core/auth/biometric_service.dart
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    return canCheck && isDeviceSupported;
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    return _auth.getAvailableBiometrics();
  }

  Future<bool> authenticate({
    String reason = 'Please authenticate to continue',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/password fallback
        ),
      );
    } catch (e) {
      return false;
    }
  }
}

// Usage with secure storage
class SecureAuthService {
  final BiometricService _biometric;
  final FlutterSecureStorage _secureStorage;

  SecureAuthService(this._biometric, this._secureStorage);

  Future<bool> enableBiometric(String userId, String refreshToken) async {
    if (!await _biometric.isAvailable()) {
      return false;
    }

    // Authenticate first
    final authenticated = await _biometric.authenticate(
      reason: 'Authenticate to enable biometric login',
    );

    if (!authenticated) {
      return false;
    }

    // Store refresh token securely
    await _secureStorage.write(
      key: 'biometric_refresh_token',
      value: refreshToken,
    );
    await _secureStorage.write(
      key: 'biometric_user_id',
      value: userId,
    );
    await _secureStorage.write(
      key: 'biometric_enabled',
      value: 'true',
    );

    return true;
  }

  Future<String?> authenticateWithBiometric() async {
    final enabled = await _secureStorage.read(key: 'biometric_enabled');
    if (enabled != 'true') {
      return null;
    }

    final authenticated = await _biometric.authenticate(
      reason: 'Authenticate to sign in',
    );

    if (!authenticated) {
      return null;
    }

    return _secureStorage.read(key: 'biometric_refresh_token');
  }

  Future<void> disableBiometric() async {
    await _secureStorage.delete(key: 'biometric_refresh_token');
    await _secureStorage.delete(key: 'biometric_user_id');
    await _secureStorage.delete(key: 'biometric_enabled');
  }
}
```

## Platform Channels

### Native Code Integration

```dart
// lib/core/platform/platform_channel.dart

class NativePlatform {
  static const MethodChannel _channel = MethodChannel('com.example.app/native');
  static const EventChannel _eventChannel = EventChannel('com.example.app/events');

  // Method call (one-time)
  static Future<String> getBatteryLevel() async {
    try {
      final int result = await _channel.invokeMethod('getBatteryLevel');
      return '$result%';
    } on PlatformException catch (e) {
      return 'Failed: ${e.message}';
    }
  }

  // Method call with arguments
  static Future<bool> shareText(String text) async {
    try {
      await _channel.invokeMethod('shareText', {'text': text});
      return true;
    } on PlatformException {
      return false;
    }
  }

  // Event stream (continuous)
  static Stream<int> get locationUpdates {
    return _eventChannel
        .receiveBroadcastStream()
        .map((event) => event as int);
  }
}
```

### iOS Implementation (Swift)

```swift
// ios/Runner/AppDelegate.swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.example.app/native",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getBatteryLevel":
        result(self.getBatteryLevel())
      case "shareText":
        if let args = call.arguments as? [String: Any],
           let text = args["text"] as? String {
          self.shareText(text)
          result(nil)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getBatteryLevel() -> Int {
    UIDevice.current.isBatteryMonitoringEnabled = true
    return Int(UIDevice.current.batteryLevel * 100)
  }

  private func shareText(_ text: String) {
    let activityVC = UIActivityViewController(
      activityItems: [text],
      applicationActivities: nil
    )
    window?.rootViewController?.present(activityVC, animated: true)
  }
}
```

### Android Implementation (Kotlin)

```kotlin
// android/app/src/main/kotlin/.../MainActivity.kt
package com.example.app

import android.content.Intent
import android.os.BatteryManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.app/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBatteryLevel" -> {
                        val batteryLevel = getBatteryLevel()
                        if (batteryLevel != -1) {
                            result.success(batteryLevel)
                        } else {
                            result.error("UNAVAILABLE", "Battery level not available", null)
                        }
                    }
                    "shareText" -> {
                        val text = call.argument<String>("text")
                        if (text != null) {
                            shareText(text)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGS", "Text required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getBatteryLevel(): Int {
        val batteryManager = getSystemService(BATTERY_SERVICE) as BatteryManager
        return batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    private fun shareText(text: String) {
        val intent = Intent().apply {
            action = Intent.ACTION_SEND
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        startActivity(Intent.createChooser(intent, "Share via"))
    }
}
```

## App Flavors (Multiple Environments)

### Configuration

```dart
// lib/core/config/environment.dart

enum Environment { dev, staging, prod }

class AppConfig {
  final Environment environment;
  final String apiBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool enableAnalytics;
  final bool enableCrashlytics;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.enableAnalytics = true,
    this.enableCrashlytics = true,
  });

  static late AppConfig current;

  static const dev = AppConfig(
    environment: Environment.dev,
    apiBaseUrl: 'https://api-dev.example.com',
    supabaseUrl: 'https://xxx.supabase.co',
    supabaseAnonKey: 'dev-anon-key',
    enableAnalytics: false,
    enableCrashlytics: false,
  );

  static const staging = AppConfig(
    environment: Environment.staging,
    apiBaseUrl: 'https://api-staging.example.com',
    supabaseUrl: 'https://yyy.supabase.co',
    supabaseAnonKey: 'staging-anon-key',
    enableAnalytics: true,
    enableCrashlytics: true,
  );

  static const prod = AppConfig(
    environment: Environment.prod,
    apiBaseUrl: 'https://api.example.com',
    supabaseUrl: 'https://zzz.supabase.co',
    supabaseAnonKey: 'prod-anon-key',
    enableAnalytics: true,
    enableCrashlytics: true,
  );

  bool get isDev => environment == Environment.dev;
  bool get isStaging => environment == Environment.staging;
  bool get isProd => environment == Environment.prod;
}
```

### Entry Points

```dart
// lib/main_dev.dart
import 'package:my_app/core/config/environment.dart';
import 'package:my_app/main_common.dart';

void main() {
  AppConfig.current = AppConfig.dev;
  mainCommon();
}

// lib/main_staging.dart
import 'package:my_app/core/config/environment.dart';
import 'package:my_app/main_common.dart';

void main() {
  AppConfig.current = AppConfig.staging;
  mainCommon();
}

// lib/main_prod.dart (or just lib/main.dart)
import 'package:my_app/core/config/environment.dart';
import 'package:my_app/main_common.dart';

void main() {
  AppConfig.current = AppConfig.prod;
  mainCommon();
}

// lib/main_common.dart
void mainCommon() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services based on config
  if (AppConfig.current.enableCrashlytics) {
    await initCrashlytics();
  }

  runApp(const MyApp());
}
```

### Run Commands

```bash
# Development
flutter run --flavor dev -t lib/main_dev.dart

# Staging
flutter run --flavor staging -t lib/main_staging.dart

# Production
flutter run --flavor prod -t lib/main_prod.dart

# Build
flutter build apk --flavor prod -t lib/main_prod.dart
flutter build ios --flavor prod -t lib/main_prod.dart
```

### Android Flavor Config

```groovy
// android/app/build.gradle
android {
    flavorDimensions "environment"
    productFlavors {
        dev {
            dimension "environment"
            applicationIdSuffix ".dev"
            versionNameSuffix "-dev"
        }
        staging {
            dimension "environment"
            applicationIdSuffix ".staging"
            versionNameSuffix "-staging"
        }
        prod {
            dimension "environment"
        }
    }
}
```

### iOS Flavor Config

```ruby
# ios/Podfile
project 'Runner', {
  'Debug-dev' => :debug,
  'Debug-staging' => :debug,
  'Debug-prod' => :debug,
  'Release-dev' => :release,
  'Release-staging' => :release,
  'Release-prod' => :release,
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

// Result type
@freezed
sealed class Result<T> with _$Result<T> {
  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(AppException error) = Failure<T>;
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
  // ...
}

// Avoid rebuilds with select
final userName = ref.watch(userProvider.select((u) => u.name));
```

## Code Generation

```bash
# Run build_runner for Freezed, Riverpod, JSON serialization
dart run build_runner build --delete-conflicting-outputs

# Watch mode during development
dart run build_runner watch --delete-conflicting-outputs
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Provider not found | Missing ProviderScope | Wrap app with `ProviderScope` |
| State not updating | Provider not watched | Use `ref.watch()` not `ref.read()` |
| Infinite rebuild loop | Provider watching itself | Check provider dependencies |
| Freezed not generating | Missing part directives | Add `part 'file.freezed.dart'` |
| Push notification not received | Missing background handler | Add top-level `@pragma` function |
| Biometric fails silently | Permission not requested | Check `AndroidManifest.xml` and `Info.plist` |
| Flavor build fails | Missing configuration | Check `build.gradle` and Xcode schemes |
| Platform channel error | Method not implemented | Check native code implementation |

## Checklist

### Architecture
- [ ] 3-layer architecture (data, domain, presentation)
- [ ] Feature modules organized consistently
- [ ] Clear dependency direction
- [ ] Shared code in core/ or shared/

### State Management
- [ ] Appropriate provider type for each use case
- [ ] Providers disposed properly (autoDispose)
- [ ] No business logic in widgets
- [ ] Error states handled

### Offline Support
- [ ] Hive initialized before runApp
- [ ] Cache-first strategy for reads
- [ ] Offline queue for mutations
- [ ] Sync on connectivity restore

### Push Notifications
- [ ] Permission requested appropriately
- [ ] Token saved to backend
- [ ] Foreground/background handlers
- [ ] Deep linking from notifications

### Security
- [ ] Biometric available check
- [ ] Secure storage for tokens
- [ ] Fallback to PIN/password

### Environments
- [ ] Separate configs per environment
- [ ] Different app IDs for dev/staging
- [ ] Feature flags per environment

## Related Templates

- See `flutter-testing` for testing patterns
- See `mobile-cicd` for CI/CD configuration
- See `auth-patterns` for authentication
- See `error-handling` for error boundaries

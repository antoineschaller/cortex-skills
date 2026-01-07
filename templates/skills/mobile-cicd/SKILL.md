# Mobile CI/CD Patterns

CI/CD patterns for Flutter/mobile applications with Xcode Cloud, Fastlane, and GitHub Actions.

> **Template Usage:** Customize for your platform (iOS, Android, both) and CI provider (Xcode Cloud, GitHub Actions, Codemagic, Bitrise).

## Xcode Cloud Setup

### ci_post_clone.sh Script

```bash
#!/bin/bash
# ci_scripts/ci_post_clone.sh
# Runs after Xcode Cloud clones the repository

set -e

echo "=== CI Post Clone Script ==="

# Navigate to Flutter project
cd $CI_PRIMARY_REPOSITORY_PATH/apps/mobile

# Install Flutter
echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Verify Flutter installation
flutter doctor -v

# Install dependencies
echo "Installing dependencies..."
flutter pub get

# Generate code (Freezed, Riverpod, etc.)
echo "Generating code..."
dart run build_runner build --delete-conflicting-outputs

# Build iOS
echo "Building iOS..."
flutter build ios --release --no-codesign

# Install CocoaPods
echo "Installing CocoaPods..."
cd ios
pod install

echo "=== CI Post Clone Complete ==="
```

### Xcode Cloud Workflow Configuration

```yaml
# Workflow: Production Release
name: Production Release
start_condition:
  source_branch: main
  action: push

environment:
  xcode: latest_release
  platform: iOS

actions:
  - action: build
    scheme: Runner
    configuration: Release

  - action: test
    scheme: Runner
    destination: platform=iOS Simulator,name=iPhone 15

  - action: archive
    scheme: Runner
    configuration: Release

  - action: distribute
    distribution: App Store Connect
    group: Production
```

### Environment Variables (Xcode Cloud)

```bash
# In Xcode Cloud settings, add these secrets:
SUPABASE_URL=your-project-url
SUPABASE_ANON_KEY=your-anon-key
SENTRY_DSN=your-sentry-dsn

# Access in ci_post_clone.sh:
echo "SUPABASE_URL=$SUPABASE_URL" >> .env
echo "SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" >> .env
```

## GitHub Actions for Flutter

### Complete CI/CD Workflow

```yaml
# .github/workflows/flutter-ci.yml
name: Flutter CI/CD

on:
  push:
    branches: [main, develop]
    paths:
      - 'apps/mobile/**'
  pull_request:
    branches: [main, develop]
    paths:
      - 'apps/mobile/**'

env:
  FLUTTER_VERSION: '3.24.0'
  JAVA_VERSION: '17'

jobs:
  analyze:
    name: Analyze & Test
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: apps/mobile

    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Analyze
        run: flutter analyze --fatal-infos

      - name: Format check
        run: dart format --output=none --set-exit-if-changed .

      - name: Run tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: apps/mobile/coverage/lcov.info
          flags: flutter

  build-android:
    name: Build Android
    runs-on: ubuntu-latest
    needs: analyze
    if: github.ref == 'refs/heads/main'
    defaults:
      run:
        working-directory: apps/mobile

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: ${{ env.JAVA_VERSION }}

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Setup environment
        run: |
          echo "SUPABASE_URL=${{ secrets.SUPABASE_URL }}" >> .env
          echo "SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}" >> .env

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Decode keystore
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE }}" | base64 --decode > android/app/upload-keystore.jks

      - name: Build APK
        run: flutter build apk --release
        env:
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}

      - name: Build App Bundle
        run: flutter build appbundle --release
        env:
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: apps/mobile/build/app/outputs/flutter-apk/app-release.apk

      - name: Upload AAB
        uses: actions/upload-artifact@v4
        with:
          name: android-aab
          path: apps/mobile/build/app/outputs/bundle/release/app-release.aab

  build-ios:
    name: Build iOS
    runs-on: macos-latest
    needs: analyze
    if: github.ref == 'refs/heads/main'
    defaults:
      run:
        working-directory: apps/mobile

    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          cache: true

      - name: Setup environment
        run: |
          echo "SUPABASE_URL=${{ secrets.SUPABASE_URL }}" >> .env
          echo "SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}" >> .env

      - name: Install dependencies
        run: flutter pub get

      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - name: Install CocoaPods
        run: |
          cd ios
          pod install

      - name: Build iOS (no codesign)
        run: flutter build ios --release --no-codesign

      # For signed builds, use Fastlane or Xcode Cloud

  deploy-android:
    name: Deploy to Play Store
    runs-on: ubuntu-latest
    needs: build-android
    if: github.ref == 'refs/heads/main'
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Download AAB
        uses: actions/download-artifact@v4
        with:
          name: android-aab

      - name: Deploy to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.yourcompany.yourapp
          releaseFiles: app-release.aab
          track: internal
          status: completed
```

## Fastlane Configuration

### iOS Fastfile

```ruby
# ios/fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Build and upload to TestFlight"
  lane :beta do
    setup_ci if ENV['CI']

    # Match for code signing
    match(
      type: "appstore",
      readonly: true,
      app_identifier: "com.yourcompany.yourapp"
    )

    # Build
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      configuration: "Release",
      export_options: {
        method: "app-store",
        provisioningProfiles: {
          "com.yourcompany.yourapp" => "match AppStore com.yourcompany.yourapp"
        }
      }
    )

    # Upload to TestFlight
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      apple_id: "YOUR_APPLE_ID"
    )
  end

  desc "Deploy to App Store"
  lane :release do
    setup_ci if ENV['CI']

    match(type: "appstore", readonly: true)

    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      configuration: "Release"
    )

    upload_to_app_store(
      skip_metadata: false,
      skip_screenshots: true,
      submit_for_review: false,
      automatic_release: false,
      precheck_include_in_app_purchases: false
    )
  end

  desc "Increment version"
  lane :bump_version do |options|
    increment_version_number(
      version_number: options[:version]
    )
    increment_build_number(
      build_number: latest_testflight_build_number + 1
    )
  end
end
```

### Android Fastfile

```ruby
# android/fastlane/Fastfile
default_platform(:android)

platform :android do
  desc "Deploy to Play Store Internal Track"
  lane :internal do
    gradle(
      task: "bundle",
      build_type: "Release",
      project_dir: ".."
    )

    upload_to_play_store(
      track: "internal",
      aab: "../build/app/outputs/bundle/release/app-release.aab",
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end

  desc "Promote Internal to Beta"
  lane :promote_to_beta do
    upload_to_play_store(
      track: "internal",
      track_promote_to: "beta",
      skip_upload_aab: true,
      skip_upload_metadata: true
    )
  end

  desc "Deploy to Production"
  lane :release do
    upload_to_play_store(
      track: "beta",
      track_promote_to: "production",
      skip_upload_aab: true,
      rollout: "0.1" # 10% rollout
    )
  end
end
```

## Version Management

### pubspec.yaml Version

```yaml
# pubspec.yaml
name: my_app
version: 1.2.3+45  # version+buildNumber
```

### Auto-increment Build Number

```bash
#!/bin/bash
# scripts/bump-version.sh

CURRENT_VERSION=$(grep "version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
CURRENT_BUILD=$(grep "version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)

NEW_BUILD=$((CURRENT_BUILD + 1))

sed -i '' "s/version: .*/version: $CURRENT_VERSION+$NEW_BUILD/" pubspec.yaml

echo "Updated to version $CURRENT_VERSION+$NEW_BUILD"
```

### Semantic Versioning Script

```bash
#!/bin/bash
# scripts/release.sh

BUMP_TYPE=$1  # major, minor, patch

CURRENT=$(grep "version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
BUILD=$(grep "version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case $BUMP_TYPE in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
NEW_BUILD=$((BUILD + 1))

sed -i '' "s/version: .*/version: $NEW_VERSION+$NEW_BUILD/" pubspec.yaml

echo "Released $NEW_VERSION+$NEW_BUILD"
```

## Code Signing

### iOS (Match)

```ruby
# Matchfile
git_url("git@github.com:yourcompany/certificates.git")
storage_mode("git")
type("appstore")
app_identifier(["com.yourcompany.yourapp"])
team_id("YOUR_TEAM_ID")
```

### Android (Keystore)

```properties
# android/key.properties (DO NOT COMMIT)
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=upload
storeFile=../upload-keystore.jks
```

```groovy
// android/app/build.gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## Environment Configuration

### Flavor-based Configuration

```dart
// lib/core/config/environment.dart
enum Environment { development, staging, production }

class AppConfig {
  final Environment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String sentryDsn;

  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.sentryDsn,
  });

  static AppConfig get current => _instance;
  static late AppConfig _instance;

  static void initialize(Environment env) {
    _instance = switch (env) {
      Environment.development => const AppConfig(
        environment: Environment.development,
        supabaseUrl: 'https://xxx.supabase.co',
        supabaseAnonKey: 'dev-key',
        sentryDsn: '',
      ),
      Environment.staging => const AppConfig(
        environment: Environment.staging,
        supabaseUrl: 'https://xxx.supabase.co',
        supabaseAnonKey: 'staging-key',
        sentryDsn: 'https://xxx@sentry.io/xxx',
      ),
      Environment.production => const AppConfig(
        environment: Environment.production,
        supabaseUrl: 'https://xxx.supabase.co',
        supabaseAnonKey: 'prod-key',
        sentryDsn: 'https://xxx@sentry.io/xxx',
      ),
    };
  }
}
```

### Build Flavors

```bash
# Run with flavor
flutter run --flavor development
flutter run --flavor staging
flutter run --flavor production

# Build with flavor
flutter build apk --flavor production
flutter build ios --flavor production
```

## Notifications (Slack/Discord)

```yaml
# Add to workflow
- name: Notify Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    fields: repo,message,commit,author,action,eventName,ref,workflow
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

- name: Notify Discord
  if: failure()
  uses: sarisia/actions-status-discord@v1
  with:
    webhook: ${{ secrets.DISCORD_WEBHOOK }}
    title: "Build Failed"
    description: "Flutter build failed on ${{ github.ref }}"
```

## Checklist

### CI/CD Setup
- [ ] Xcode Cloud or GitHub Actions configured
- [ ] Environment variables set as secrets
- [ ] Code signing configured (Match or manual)
- [ ] Build triggers on correct branches

### iOS
- [ ] ci_post_clone.sh working
- [ ] Certificates and profiles in place
- [ ] TestFlight distribution configured
- [ ] App Store Connect API key set

### Android
- [ ] Keystore created and secured
- [ ] Google Play service account configured
- [ ] Release tracks set up (internal, beta, production)
- [ ] App signing by Google Play enabled

### Quality Gates
- [ ] Tests run before build
- [ ] Code analysis passes
- [ ] Coverage thresholds met
- [ ] Build artifacts archived

### Deployment
- [ ] Version auto-incrementing
- [ ] Release notes generated
- [ ] Rollout strategy defined
- [ ] Rollback plan documented

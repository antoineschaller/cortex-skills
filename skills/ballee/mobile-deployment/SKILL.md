# Mobile Deployment Skill

Comprehensive guide for deploying the Ballee mobile app to iOS (TestFlight/App Store) and Android (Play Store).

## Overview

| Platform | CI/CD | Local Deploy | Distribution |
|----------|-------|--------------|--------------|
| **iOS** | Xcode Cloud | Fastlane / xcodebuild | TestFlight, App Store |
| **Android** | GitLab CI | Fastlane / Gradle | Firebase App Distribution, Play Store |

## Prerequisites

### iOS Prerequisites

1. **Apple Developer Account** with distribution certificate
2. **App Store Connect API Key** at `~/.appstoreconnect/private_keys/AuthKey_LGU934Y2XR.p8`
3. **Xcode** installed with command line tools
4. **Ruby & Bundler** for Fastlane
5. **CocoaPods** for iOS dependencies

**Key Identifiers:**
| Item | Value |
|------|-------|
| Bundle ID | `co.ballee` |
| Team ID | `A86CXY8H75` |
| API Key ID | `LGU934Y2XR` |
| API Issuer ID | `69a6de96-5d75-47e3-e053-5b8c7c11a4d1` |
| Apple ID | `antoine@ballee.co` |

### Android Prerequisites

1. **Release Keystore** configured in `apps/mobile/android/key.properties`
2. **Google Play Console** access with service account
3. **Java 11+** and Android SDK
4. **Flutter SDK** installed

**Key Identifiers:**
| Item | Value |
|------|-------|
| Package Name | `co.ballee` |
| Min SDK | 24 |

## iOS Deployment

### Option 1: Xcode Cloud (Automated - Recommended)

Xcode Cloud automatically builds and deploys to TestFlight on push to `main`.

**Trigger a build manually:**
```bash
cd apps/mobile/ios/scripts
python3 xcode_cloud_cli.py trigger
```

**Check build status:**
```bash
python3 xcode_cloud_cli.py list
```

**Environment variables (set in Xcode Cloud):**
| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Production Supabase URL |
| `SUPABASE_ANON_KEY` | Production anon key |
| `SENTRY_DSN` | Sentry DSN for crash reporting |
| `MIXPANEL_TOKEN` | Analytics token |
| `APP_STORE_CONNECT_API_KEY_ID` | API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | Base64-encoded .p8 key |

**CI Scripts:**
- `ci_post_clone.sh` - Installs Flutter, builds iOS app, runs code generation
- `ci_post_xcodebuild.sh` - Uploads to TestFlight, uploads dSYMs to Sentry

### Option 2: Fastlane (Local)

**Setup (first time):**
```bash
cd apps/mobile/ios
bundle install
```

**Deploy to TestFlight:**
```bash
cd apps/mobile/ios

# Option A: Manual signing (uses match provisioning profiles)
bundle exec fastlane beta

# Option B: Automatic signing (uses Xcode managed signing)
bundle exec fastlane beta_auto

# Option C: Build only (no upload)
bundle exec fastlane build_only
```

**Available Lanes:**
| Lane | Description |
|------|-------------|
| `beta` | Build with manual signing + upload to TestFlight |
| `beta_auto` | Build with automatic signing + upload to TestFlight |
| `build_only` | Build IPA without uploading |

**Increment build number:**
```bash
bundle exec fastlane beta increment_build:true
```

### Option 3: Manual xcodebuild

**Step 1: Build Flutter app**
```bash
cd apps/mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build ios --release --no-codesign \
    --dart-define=ENV=prod \
    --dart-define=BACKEND_URL="https://csjruhqyqzzqxnfeyiaf.supabase.co" \
    --dart-define=SUPABASE_TOKEN="$SUPABASE_ANON_KEY"
```

**Step 2: Install pods**
```bash
cd ios
pod install --repo-update
```

**Step 3: Archive**
```bash
xcodebuild -workspace Ballee.xcworkspace \
    -scheme Ballee \
    -sdk iphoneos \
    -configuration Release \
    -archivePath build/Ballee.xcarchive \
    archive
```

**Step 4: Export and upload**
```bash
xcodebuild -exportArchive \
    -archivePath build/Ballee.xcarchive \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath build/export \
    -allowProvisioningUpdates \
    -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_LGU934Y2XR.p8 \
    -authenticationKeyID LGU934Y2XR \
    -authenticationKeyIssuerID 69a6de96-5d75-47e3-e053-5b8c7c11a4d1
```

### iOS Quick Deploy Script

Use the provided script for one-command deployment:
```bash
./.claude/skills/mobile-deployment/scripts/deploy-ios.sh
```

Options:
- `--increment` - Increment build number
- `--skip-upload` - Build only, don't upload

## Android Deployment

### Setting Up Release Signing

**Step 1: Create keystore (if needed)**
```bash
./.claude/skills/mobile-deployment/scripts/setup-android-signing.sh
```

Or manually:
```bash
keytool -genkey -v \
    -keystore ~/ballee-release-key.jks \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias ballee
```

**Step 2: Create key.properties**
Create `apps/mobile/android/key.properties`:
```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=ballee
storeFile=/path/to/ballee-release-key.jks
```

**Step 3: Enable release signing**
Uncomment the signing config in `apps/mobile/android/app/build.gradle.kts`:
```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

### Building Release APK/AAB

**Build AAB (for Play Store):**
```bash
cd apps/mobile
flutter build appbundle --release \
    --dart-define=ENV=prod \
    --dart-define=BACKEND_URL="https://csjruhqyqzzqxnfeyiaf.supabase.co" \
    --dart-define=SUPABASE_TOKEN="$SUPABASE_ANON_KEY"
```
Output: `build/app/outputs/bundle/release/app-release.aab`

**Build APK (for direct install/testing):**
```bash
flutter build apk --release \
    --dart-define=ENV=prod \
    --dart-define=BACKEND_URL="https://csjruhqyqzzqxnfeyiaf.supabase.co" \
    --dart-define=SUPABASE_TOKEN="$SUPABASE_ANON_KEY"
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Fastlane for Android

**Setup (first time):**
```bash
cd apps/mobile/android
bundle install
```

**Available Lanes:**
| Lane | Description |
|------|-------------|
| `build_apk` | Build release APK |
| `build_aab` | Build release AAB |
| `firebase` | Build and deploy to Firebase App Distribution |
| `playstore` | Build and upload to Play Store (internal track) |

**Deploy to Firebase App Distribution:**
```bash
bundle exec fastlane firebase
```

**Deploy to Play Store:**
```bash
bundle exec fastlane playstore
```

### Manual Play Store Upload

1. Go to [Google Play Console](https://play.google.com/console)
2. Select "Ballee" app
3. Go to Release > Production (or Testing tracks)
4. Create new release
5. Upload the AAB file from `build/app/outputs/bundle/release/app-release.aab`
6. Add release notes
7. Review and roll out

### Android Quick Deploy Script

Use the provided script for one-command deployment:
```bash
./.claude/skills/mobile-deployment/scripts/deploy-android.sh
```

Options:
- `--apk` - Build APK instead of AAB
- `--firebase` - Deploy to Firebase App Distribution
- `--playstore` - Deploy to Play Store

## Environment Variables

### Production Environment

All environment variables are passed via `--dart-define` at build time:

| Variable | Description | iOS | Android |
|----------|-------------|-----|---------|
| `ENV` | Environment (`prod`, `staging`, `dev`) | Yes | Yes |
| `BACKEND_URL` | Supabase URL | Yes | Yes |
| `SUPABASE_TOKEN` | Supabase anon key | Yes | Yes |
| `SENTRY_DSN` | Sentry DSN | Yes | Yes |
| `MIXPANEL_TOKEN` | Mixpanel token | Yes | Yes |
| `APP_STORE_ID` | App Store ID (iOS only) | Yes | No |

### Production Values

```bash
SUPABASE_URL="https://csjruhqyqzzqxnfeyiaf.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNzanJ1aHF5cXp6cXhuZmV5aWFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTgzNDkxOTQsImV4cCI6MjA3MzkyNTE5NH0.wyDYf6UpJr2trbGOzWx-Sf0p5pSbnTWcQOCFnvtN5lI"
```

## File Reference

### iOS Files

| File | Purpose |
|------|---------|
| `apps/mobile/ios/fastlane/Fastfile` | Fastlane lane definitions |
| `apps/mobile/ios/fastlane/Appfile` | App Store Connect config |
| `apps/mobile/ios/Gemfile` | Ruby dependencies |
| `apps/mobile/ios/ci_scripts/ci_post_clone.sh` | Xcode Cloud setup script |
| `apps/mobile/ios/ci_scripts/ci_post_xcodebuild.sh` | Post-build upload script |
| `apps/mobile/ios/scripts/xcode_cloud_cli.py` | CLI for Xcode Cloud API |
| `apps/mobile/ios/ExportOptions.plist` | Export configuration |
| `apps/mobile/ios/Ballee/Info.plist` | App configuration |

### Android Files

| File | Purpose |
|------|---------|
| `apps/mobile/android/app/build.gradle.kts` | Gradle build config |
| `apps/mobile/android/key.properties` | Signing credentials (not in git) |
| `apps/mobile/android/fastlane/Fastfile` | Fastlane lane definitions |
| `apps/mobile/android/fastlane/Appfile` | Play Store config |

## Troubleshooting

### iOS Issues

**"Preparing build for App Store Connect failed" (Xcode Cloud)**
- This is often an Apple infrastructure issue
- Try changing Xcode version in workflow settings
- Fallback: Use local Fastlane deployment

**"No signing certificate found" / "Revoked certificate"**
- Check Xcode > Settings > Accounts for valid certificates
- Create new distribution certificate in Apple Developer Portal
- For Xcode Cloud: Certificates are managed automatically

**"Missing purpose string in Info.plist"**
- Add required `NS*UsageDescription` keys to `Info.plist`
- Common ones: `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`

**Podfile.lock out of sync**
```bash
cd apps/mobile/ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

**Build number already exists**
```bash
# Increment via Fastlane
bundle exec fastlane beta increment_build:true

# Or manually in Xcode
# Ballee.xcodeproj > Build Settings > Current Project Version
```

### Android Issues

**"Keystore was tampered with, or password was incorrect"**
- Verify passwords in `key.properties` match keystore
- Regenerate keystore if lost

**"No key with alias 'ballee' found in keystore"**
- Check `keyAlias` in `key.properties` matches alias used during keystore creation

**Release build not signed**
- Ensure `key.properties` exists and paths are correct
- Uncomment signing config in `build.gradle.kts`

**App crashes on release but not debug**
- Check ProGuard/R8 rules
- Verify environment variables are passed correctly

### General Flutter Issues

**"pub get failed"**
```bash
flutter clean
flutter pub get
```

**"build_runner failed"**
```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

## Related Skills

- `xcode-cloud-cicd` - Detailed Xcode Cloud CI/CD documentation
- `flutter-development` - Flutter development patterns
- `flutter-testing` - Testing patterns for mobile

## Quick Reference

### Deploy iOS to TestFlight
```bash
cd apps/mobile/ios && bundle exec fastlane beta_auto
```

### Deploy Android to Play Store
```bash
cd apps/mobile/android && bundle exec fastlane playstore
```

### Trigger Xcode Cloud Build
```bash
cd apps/mobile/ios/scripts && python3 xcode_cloud_cli.py trigger
```

# Codemagic Flutter CI/CD

Complete guide for setting up and managing Codemagic CI/CD for Flutter iOS applications, including code signing, TestFlight deployment, and troubleshooting.

## Overview

Codemagic is a cloud-based CI/CD platform specialized for mobile app development. It provides:

- **Automatic code signing** for iOS without requiring a Mac
- **App Store Connect integration** for TestFlight and App Store publishing
- **Flutter-specific build tools** and environments
- **Build caching** and optimization for faster builds

## Quick Links

- [Workflows Configuration](./workflows.md) - Complete codemagic.yaml setup
- [Code Signing Setup](./code-signing.md) - iOS code signing with App Store Connect API
- [TestFlight Deployment](./testflight.md) - Publishing to TestFlight
- [Troubleshooting](./troubleshooting.md) - Common issues and solutions

## Prerequisites

### 1. Apple Developer Account

- Active Apple Developer Program membership ($99/year)
- Access to Apple Developer Portal
- Access to App Store Connect

### 2. App Store Connect API Key

Required for automatic code signing and publishing:

1. **Generate API Key**:
   - Go to: https://appstoreconnect.apple.com/access/api
   - Click "+" to create new key
   - Name: `Codemagic - <Your App Name>`
   - Access: **Admin** (recommended for full functionality)

2. **Download and Save**:
   - Download the `.p8` private key file (only available once!)
   - Record the **Issuer ID** (shown at top of page)
   - Record the **Key ID** (shown in table)

3. **Store Securely**:
   - Save `.p8` file to 1Password or secure vault
   - Never commit private key to git

### 3. Apple Developer Portal Setup

Create these resources in Apple Developer Portal:

1. **App ID**:
   - Go to: https://developer.apple.com/account/resources/identifiers/list
   - Create App ID with your bundle identifier (e.g., `co.ballee`)
   - Enable required capabilities (Push Notifications, Sign in with Apple, etc.)

2. **App Store Provisioning Profile**:
   - Go to: https://developer.apple.com/account/resources/profiles/list
   - Create "App Store" type profile for your bundle ID
   - Codemagic can also create this automatically via API

3. **Distribution Certificate** (optional):
   - Codemagic can create this automatically if none exists
   - Maximum 3 distribution certificates per team

### 4. App Store Connect App Record

Create your app in App Store Connect before automating deployment:

1. **Create App Record**:
   - Go to: https://appstoreconnect.apple.com
   - My Apps → "+" → New App
   - Fill in app information
   - Set bundle ID to match your App ID

2. **Initial Manual Upload** (recommended):
   - Upload first build manually via Xcode or Transporter
   - This creates the initial app structure in TestFlight
   - Subsequent builds can be automated

## Project Structure

```
your-project/
├── codemagic.yaml              # CI/CD configuration (must be at repository root)
├── apps/mobile/                # Flutter app (if monorepo)
│   ├── ios/
│   │   ├── Runner.xcodeproj
│   │   └── Runner.xcworkspace
│   ├── pubspec.yaml
│   └── lib/
└── .gitignore                  # Ensure sensitive files are ignored
```

## Environment Variables

Configure these in Codemagic UI (App Settings → Environment variables):

### Required for Code Signing (Critical!)

**IMPORTANT**: When using automatic code signing with `--create` flag, you MUST configure these in the `app_store_credentials` group:

| Variable | Description | How to Generate |
|----------|-------------|-----------------|
| `APP_STORE_CONNECT_ISSUER_ID` | From App Store Connect API page | Copy from https://appstoreconnect.apple.com/access/api |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Key ID | Copy from API key table |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contents of .p8 file | Download .p8 file, copy contents |
| `CERTIFICATE_PRIVATE_KEY` | RSA private key | `openssl genrsa -out cert_key.pem 2048` |

Without `CERTIFICATE_PRIVATE_KEY`, builds will fail with:
```
ERROR > Cannot save Signing Certificates without certificate private key
```

### Required for Build

| Variable | Description | Secure? |
|----------|-------------|---------|
| `APP_STORE_ID` | App Store ID (visible in App Store Connect URL) | No |
| `SUPABASE_TOKEN` | Supabase anon key | Yes |
| `BACKEND_URL` | Backend API URL | No |

### Optional for Analytics/Features

| Variable | Description | Secure? |
|----------|-------------|---------|
| `RC_IOS_API_KEY` | RevenueCat iOS API key | Yes |
| `RC_ANDROID_API_KEY` | RevenueCat Android API key | Yes |
| `SENTRY_DSN` | Sentry error tracking DSN | Yes |
| `MIXPANEL_TOKEN` | Mixpanel analytics token | Yes |

## Basic Workflow

```yaml
workflows:
  ios-testflight:
    name: iOS TestFlight
    max_build_duration: 120
    instance_type: mac_mini_m2
    working_directory: apps/mobile  # If monorepo
    integrations:
      app_store_connect: <Integration Name>
    environment:
      vars:
        APP_STORE_APPLE_ID: '1234567890'
        XCODE_WORKSPACE: 'ios/Runner.xcworkspace'
        XCODE_SCHEME: 'Runner'
      flutter: stable
      xcode: latest
      cocoapods: default
    scripts:
      - name: Set up code signing
        script: |
          app-store-connect fetch-signing-files $BUNDLE_ID \\
            --type IOS_APP_STORE \\
            --create
      - name: Apply profiles to Xcode
        script: |
          xcode-project use-profiles
      - name: Get Flutter packages
        script: |
          flutter pub get
      - name: Build IPA
        script: |
          flutter build ipa --release
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
        beta_groups:
          - Internal Testers
```

## Codemagic API

Use the Codemagic API to trigger builds programmatically:

```bash
curl -X POST \\
  -H "x-auth-token: $CODEMAGIC_API_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{
    "appId": "<app_id>",
    "workflowId": "ios-testflight",
    "branch": "main"
  }' \\
  https://api.codemagic.io/builds
```

Get API token from: https://codemagic.io/app/profile

## Key Concepts

### Instance Types

- **mac_mini_m1**: Standard builds, ~15-20 min for Flutter iOS
- **mac_mini_m2**: Faster builds (recommended)
- **mac_pro**: Premium, fastest builds

### Build Duration

- Average iOS build: 15-20 minutes
- TestFlight upload: 5-10 minutes
- Total: ~25-35 minutes from commit to TestFlight

### Caching

Codemagic automatically caches:
- Flutter SDK
- CocoaPods dependencies
- Build artifacts

## Next Steps

1. [Set up your workflow](./workflows.md) - Complete codemagic.yaml configuration
2. [Configure code signing](./code-signing.md) - iOS code signing setup
3. [Deploy to TestFlight](./testflight.md) - Publishing configuration
4. [Troubleshoot issues](./troubleshooting.md) - Common problems and solutions

## Resources

- **Codemagic Docs**: https://docs.codemagic.io
- **Flutter Workflow Guide**: https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/
- **iOS Code Signing**: https://docs.codemagic.io/yaml-code-signing/signing-ios/
- **App Store Connect Publishing**: https://docs.codemagic.io/yaml-publishing/app-store-connect/
- **CLI Tools Reference**: https://github.com/codemagic-ci-cd/cli-tools

## Support

- **Codemagic Support**: support@codemagic.io
- **Documentation**: https://docs.codemagic.io
- **Community**: https://github.com/codemagic-ci-cd/codemagic-sample-projects

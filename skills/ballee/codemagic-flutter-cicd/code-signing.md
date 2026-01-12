# iOS Code Signing with Codemagic

Complete guide to iOS code signing for Flutter apps using App Store Connect API integration.

## Overview

iOS apps require:
1. **Distribution Certificate** - Proves your identity as a developer
2. **Provisioning Profile** - Links your app to your certificate and App ID

Codemagic can automatically fetch or create these using the App Store Connect API.

## Two Approaches

### Approach 1: Automatic Signing (Recommended)

Codemagic fetches/creates certificates and profiles automatically during the build.

**Pros**:
- Fully automated
- No manual certificate/profile management
- Profiles auto-update when they expire
- Works without a Mac

**Cons**:
- Requires App Store Connect API integration
- Less control over certificate/profile creation

### Approach 2: Manual Signing

Upload certificates and profiles to Codemagic manually.

**Pros**:
- Full control over certificates/profiles
- Can use existing certificates
- Works with enterprise certificates

**Cons**:
- Manual profile updates when they expire
- Requires exporting certificates from Mac
- More maintenance overhead

## Setup: App Store Connect Integration

### Step 1: Create API Key in App Store Connect

1. Go to: https://appstoreconnect.apple.com/access/api
2. Click "+" to generate new key
3. **Name**: `Codemagic - <Your App Name>`
4. **Access**: Select **Admin** (required for code signing)
5. Click "Generate"
6. **Download** the `.p8` private key file (only shown once!)
7. **Record**:
   - **Issuer ID**: Shown at top of page (e.g., `69a6de96-5d75-47e3-e053-5b8c7c11a4d1`)
   - **Key ID**: Shown in table (e.g., `LGU934Y2XR`)

### Step 2: Add Integration to Codemagic

**Method A: Via Codemagic UI** (Recommended)

1. Go to Codemagic Team settings: https://codemagic.io/teams
2. Select your team → **Integrations**
3. Find "App Store Connect" section
4. Click **"Add integration"**
5. Fill in:
   - **Integration name**: `Ballee App Store Connect` (use in codemagic.yaml)
   - **Issuer ID**: Paste from App Store Connect
   - **Key ID**: Paste from App Store Connect
   - **Private key**: Upload the `.p8` file
6. Click **Save**

**Method B: Via Environment Variables** (Required when using `--create` flag)

Add these to Codemagic app environment variables:

```yaml
environment:
  groups:
    - app_store_credentials  # Group containing:
                             # - APP_STORE_CONNECT_ISSUER_ID
                             # - APP_STORE_CONNECT_KEY_IDENTIFIER
                             # - APP_STORE_CONNECT_PRIVATE_KEY
                             # - CERTIFICATE_PRIVATE_KEY (REQUIRED!)
```

**CRITICAL**: When using `app-store-connect fetch-signing-files --create`, you MUST also provide `CERTIFICATE_PRIVATE_KEY`. Without it, you'll get:

```
ERROR > Cannot save Signing Certificates without certificate private key
```

**Generate certificate private key**:

```bash
# Generate a 2048-bit RSA private key
openssl genrsa -out cert_key.pem 2048

# Add to Codemagic via API
curl -X POST \
  -H "x-auth-token: $CODEMAGIC_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"key\": \"CERTIFICATE_PRIVATE_KEY\",
    \"value\": \"$(cat cert_key.pem)\",
    \"secure\": true,
    \"group\": \"app_store_credentials\"
  }" \
  "https://api.codemagic.io/apps/$APP_ID/variables"
```

**Complete Environment Variables Required**:

| Variable | Required | Description |
|----------|----------|-------------|
| `APP_STORE_CONNECT_ISSUER_ID` | ✅ Yes | From App Store Connect API page |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | ✅ Yes | Key ID from App Store Connect |
| `APP_STORE_CONNECT_PRIVATE_KEY` | ✅ Yes | Contents of .p8 file |
| `CERTIFICATE_PRIVATE_KEY` | ✅ Yes (with `--create`) | RSA private key for certificate creation |

### Step 3: Configure Apple Developer Portal

#### Create App ID

1. Go to: https://developer.apple.com/account/resources/identifiers/list
2. Click "+" button
3. Select "App IDs" → Continue
4. Select "App" → Continue
5. Fill in:
   - **Description**: Your app name (e.g., `Ballee`)
   - **Bundle ID**: Select "Explicit" → Enter bundle ID (e.g., `co.ballee`)
   - **Capabilities**: Enable required capabilities:
     - Push Notifications
     - Sign in with Apple
     - Associated Domains
     - etc.
6. Continue → Register

#### Create Provisioning Profile (Optional)

Codemagic can create this automatically with `--create` flag, but you can create it manually:

1. Go to: https://developer.apple.com/account/resources/profiles/list
2. Click "+" button
3. Select "App Store" (under Distribution) → Continue
4. Select your App ID → Continue
5. Select Distribution Certificate → Continue
   - If none exists, Codemagic will create one automatically
6. **Profile Name**: `<App Name> App Store` (e.g., `Ballee App Store`)
7. Generate → Download (optional, Codemagic fetches via API)

## Workflow Configuration

### Option 1: Manual Fetch (Recommended for Flexibility)

Use this when you need explicit control over code signing:

```yaml
workflows:
  ios-testflight:
    name: iOS TestFlight
    integrations:
      app_store_connect: Ballee App Store Connect  # Must match integration name
    environment:
      vars:
        BUNDLE_ID: co.ballee
      flutter: stable
      xcode: latest
    scripts:
      - name: Set up code signing
        script: |
          app-store-connect fetch-signing-files "$BUNDLE_ID" \\
            --type IOS_APP_STORE \\
            --create
      - name: Apply profiles to Xcode
        script: |
          xcode-project use-profiles
      - name: Build IPA
        script: |
          flutter build ipa --release
```

### Option 2: Automatic Signing (Simpler but Less Flexible)

Use this for simple apps with standard signing requirements:

```yaml
workflows:
  ios-testflight:
    name: iOS TestFlight
    integrations:
      app_store_connect: Ballee App Store Connect
    environment:
      ios_signing:
        distribution_type: app_store      # or: development, ad_hoc, enterprise
        bundle_identifier: co.ballee
      flutter: stable
    scripts:
      - name: Set up code signing
        script: |
          xcode-project use-profiles
      - name: Build IPA
        script: |
          flutter build ipa --release
```

**Note**: With `ios_signing` configured, Codemagic automatically fetches certificates and profiles **before** scripts run.

## fetch-signing-files Command Reference

Full command syntax:

```bash
app-store-connect fetch-signing-files <BUNDLE_ID> \\
  --type <PROFILE_TYPE> \\
  --platform <PLATFORM> \\
  --create \\
  --strict-match-identifier \\
  --certificate-key <KEY> \\
  --certificate-key-password <PASSWORD> \\
  --p12-password <PASSWORD> \\
  --profiles-dir <DIR> \\
  --certificates-dir <DIR>
```

### Required Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `BUNDLE_ID` | App bundle identifier | `co.ballee` |

### Key Options

| Option | Description | Values |
|--------|-------------|--------|
| `--type` | Provisioning profile type | `IOS_APP_STORE` (default: `IOS_APP_DEVELOPMENT`) |
| `--platform` | Bundle ID platform | `IOS` (default), `MAC_OS`, `UNIVERSAL`, `SERVICES` |
| `--create` | Create resources if missing | (flag, no value) |
| `--strict-match-identifier` | Only exact Bundle ID matches | (flag, no value) |

### Profile Types

| Type | Description | Use Case |
|------|-------------|----------|
| `IOS_APP_DEVELOPMENT` | Development builds | Local testing on devices |
| `IOS_APP_STORE` | App Store distribution | TestFlight, App Store |
| `IOS_APP_ADHOC` | Ad Hoc distribution | Beta testing outside TestFlight |
| `IOS_APP_INHOUSE` | Enterprise distribution | Internal enterprise apps |
| `MAC_APP_DEVELOPMENT` | macOS development | Mac development builds |
| `MAC_APP_STORE` | Mac App Store | macOS App Store distribution |

### Advanced Options

```bash
# Use custom certificate private key
app-store-connect fetch-signing-files co.ballee \\
  --type IOS_APP_STORE \\
  --certificate-key @env:CERT_PRIVATE_KEY \\
  --certificate-key-password @env:CERT_PASSWORD

# Save to custom directory
app-store-connect fetch-signing-files co.ballee \\
  --type IOS_APP_STORE \\
  --profiles-dir /tmp/profiles \\
  --certificates-dir /tmp/certs

# Set password for exported .p12 file
app-store-connect fetch-signing-files co.ballee \\
  --type IOS_APP_STORE \\
  --p12-password "my-secure-password"
```

### Environment Variables

The command uses these environment variables automatically when using integrations:

```bash
APP_STORE_CONNECT_ISSUER_ID=69a6de96-5d75-47e3-e053-5b8c7c11a4d1
APP_STORE_CONNECT_KEY_IDENTIFIER=LGU934Y2XR
APP_STORE_CONNECT_PRIVATE_KEY=<contents of .p8 file>
```

## Applying Profiles to Xcode

After fetching signing files, apply them to your Xcode project:

```bash
xcode-project use-profiles
```

This command:
1. Finds all provisioning profiles in `~/Library/MobileDevice/Provisioning Profiles`
2. Matches profiles to targets based on bundle identifiers
3. Updates Xcode project build settings
4. Configures automatic signing or manual signing as appropriate

### Custom Workspace/Project

```bash
xcode-project use-profiles \\
  --project ios/Runner.xcodeproj

xcode-project use-profiles \\
  --workspace ios/Runner.xcworkspace
```

## Troubleshooting Code Signing

### "No matching profiles found"

**Symptoms**: Build fails immediately with "No matching profiles found for bundle identifier 'X'"

**Causes**:
1. App ID doesn't exist in Apple Developer Portal
2. Provisioning profile doesn't exist
3. Bundle ID mismatch between app and portal

**Solutions**:

```bash
# 1. Verify App ID exists
open https://developer.apple.com/account/resources/identifiers/list

# 2. Create profile automatically with --create flag
app-store-connect fetch-signing-files co.ballee \\
  --type IOS_APP_STORE \\
  --create

# 3. Check bundle ID in Xcode project
grep -r "PRODUCT_BUNDLE_IDENTIFIER" ios/*.pbxproj
```

### "Certificate limit exceeded"

**Symptoms**: Error creating new certificate - "Maximum number of certificates generated"

**Cause**: Apple limits distribution certificates to 3 per team

**Solutions**:

```bash
# 1. Check existing certificates
open https://developer.apple.com/account/resources/certificates/list

# 2. Revoke old/unused certificates

# 3. Use existing certificate by providing private key
app-store-connect fetch-signing-files co.ballee \\
  --type IOS_APP_STORE \\
  --certificate-key @file:~/certs/distribution.p12 \\
  --certificate-key-password "password"
```

### "Invalid provisioning profile"

**Symptoms**: Build succeeds but archive fails with "Invalid provisioning profile"

**Solutions**:

```bash
# Delete stale profiles
app-store-connect fetch-signing-files co.ballee \\
  --type IOS_APP_STORE \\
  --delete-stale-profiles

# Regenerate profile
# 1. Delete profile from Apple Developer Portal
# 2. Rerun fetch with --create
```

### Integration not found

**Symptoms**: "Integration 'X' not found"

**Cause**: Integration name in codemagic.yaml doesn't match Codemagic settings

**Solution**:

```yaml
# Integration name must match EXACTLY (case-sensitive)
integrations:
  app_store_connect: Ballee App Store Connect  # ← Must match UI exactly
```

Verify integration name:
1. Go to: https://codemagic.io/teams
2. Select team → Integrations → App Store Connect
3. Copy exact integration name

## Best Practices

### 1. Use Automatic Profile Creation

Always use `--create` flag to let Codemagic create missing resources:

```bash
app-store-connect fetch-signing-files co.ballee \\
  --type IOS_APP_STORE \\
  --create
```

### 2. Store API Keys Securely

- Use Codemagic integrations (recommended)
- Never commit `.p8` files to git
- Store in 1Password or secure vault
- Use environment variable groups in Codemagic

### 3. Use Team-Level Integrations

Configure integrations at **team level**, not app level:
- Easier to share across multiple apps
- Centralized credential management
- Better security controls

### 4. Monitor Certificate Expiration

- Distribution certificates expire after 1 year
- Provisioning profiles expire after 1 year
- Codemagic can auto-regenerate profiles
- Certificates require manual renewal

### 5. Test Locally First

Before automating, test code signing locally:

```bash
# Install Codemagic CLI tools
pip3 install codemagic-cli-tools

# Fetch signing files locally
app-store-connect fetch-signing-files co.ballee \\
  --type IOS_APP_STORE \\
  --issuer-id <issuer_id> \\
  --key-id <key_id> \\
  --private-key @file:AuthKey_XXX.p8

# Build locally
flutter build ipa --release
```

## Resources

- **Codemagic iOS Signing Docs**: https://docs.codemagic.io/yaml-code-signing/signing-ios/
- **CLI Tools Reference**: https://github.com/codemagic-ci-cd/cli-tools/blob/master/docs/app-store-connect/fetch-signing-files.md
- **Apple Code Signing Guide**: https://developer.apple.com/support/code-signing/
- **Troubleshooting Guide**: https://docs.codemagic.io/troubleshooting/common-issues/

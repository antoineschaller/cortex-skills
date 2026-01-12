# Codemagic Troubleshooting Guide

Common issues and solutions when using Codemagic for Flutter iOS builds.

## Code Signing Issues

### "No matching profiles found for bundle identifier 'X'"

**Symptoms**:
- Build fails immediately or during code signing step
- Error message: `No matching profiles found for bundle identifier "com.example.app" and distribution type "app_store"`

**Causes**:
1. App ID doesn't exist in Apple Developer Portal
2. Provisioning profile doesn't exist
3. Bundle ID mismatch between app and Apple Developer Portal
4. Integration credentials not configured properly

**Solutions**:

#### 1. Verify App ID Exists

```bash
# Open Apple Developer Portal
open https://developer.apple.com/account/resources/identifiers/list

# Search for your bundle ID (e.g., co.ballee)
# If not found, create it
```

#### 2. Create/Verify Provisioning Profile

```bash
# Open Profiles page
open https://developer.apple.com/account/resources/profiles/list

# Create App Store profile if missing:
# - Click "+"
# - Select "App Store"
# - Choose your App ID
# - Select Distribution Certificate
# - Generate
```

#### 3. Use --create Flag

Add `--create` flag to automatically create missing resources:

```yaml
scripts:
  - name: Set up code signing
    script: |
      app-store-connect fetch-signing-files "$BUNDLE_ID" \\
        --type IOS_APP_STORE \\
        --create
```

#### 4. Check Bundle ID Match

```bash
# Verify bundle ID in Xcode project matches Apple Developer Portal
grep -r "PRODUCT_BUNDLE_IDENTIFIER" ios/*.pbxproj

# Should output: PRODUCT_BUNDLE_IDENTIFIER = co.ballee;
```

#### 5. Verify Integration Configuration

- Go to: https://codemagic.io/teams
- Select team → Integrations
- Verify App Store Connect integration exists
- Integration name must match exactly in codemagic.yaml:

```yaml
integrations:
  app_store_connect: Ballee App Store Connect  # Must match UI exactly
```

### "Cannot save Signing Certificates without certificate private key"

**Symptoms**:
- Build fails during `fetch-signing-files` command
- Error: `ERROR > Cannot save Signing Certificates without certificate private key`

**Cause**:
The `CERTIFICATE_PRIVATE_KEY` environment variable is missing. This is **REQUIRED** when using `--create` flag to automatically create distribution certificates.

**Solution**:

Generate and add certificate private key to Codemagic:

```bash
# 1. Generate private key
openssl genrsa -out cert_key.pem 2048

# 2. Add to Codemagic via API
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

# 3. Trigger new build
```

Or add via Codemagic UI:
1. Go to: https://codemagic.io/app/YOUR_APP_ID/settings
2. Environment variables → Add variable
3. Key: `CERTIFICATE_PRIVATE_KEY`
4. Value: Paste contents of `cert_key.pem`
5. Secure: ✅ Yes
6. Group: `app_store_credentials`

### "Step X script `Set up code signing` exited with status code 1"

**Symptoms**:
- Build starts but fails during code signing script
- No detailed error message

**Causes**:
1. API credentials not accessible
2. Invalid App Store Connect API key
3. Insufficient permissions on API key
4. Missing CERTIFICATE_PRIVATE_KEY (see above)
5. Network issues connecting to Apple servers

**Solutions**:

#### 1. Verify Environment Variables Are Loaded

Add debug script before code signing:

```yaml
scripts:
  - name: Debug environment
    script: |
      echo "Checking API credentials..."
      if [ -z "$APP_STORE_CONNECT_ISSUER_ID" ]; then
        echo "❌ ISSUER_ID not set"
      else
        echo "✅ ISSUER_ID set"
      fi

      if [ -z "$APP_STORE_CONNECT_KEY_IDENTIFIER" ]; then
        echo "❌ KEY_IDENTIFIER not set"
      else
        echo "✅ KEY_IDENTIFIER set"
      fi

      if [ -z "$APP_STORE_CONNECT_PRIVATE_KEY" ]; then
        echo "❌ PRIVATE_KEY not set"
      else
        echo "✅ PRIVATE_KEY set (length: ${#APP_STORE_CONNECT_PRIVATE_KEY})"
      fi

  - name: Set up code signing
    script: |
      app-store-connect fetch-signing-files "$BUNDLE_ID" \\
        --type IOS_APP_STORE \\
        --create
```

#### 2. Verify API Key Has Admin Access

```bash
# Open App Store Connect
open https://appstoreconnect.apple.com/access/api

# Find your API key
# Verify Access = "Admin" (not "App Manager")
```

#### 3. Test Locally with CLI Tools

```bash
# Install Codemagic CLI tools
pip3 install codemagic-cli-tools

# Test fetch command locally
export APP_STORE_CONNECT_ISSUER_ID="your-issuer-id"
export APP_STORE_CONNECT_KEY_IDENTIFIER="your-key-id"
export APP_STORE_CONNECT_PRIVATE_KEY="$(cat AuthKey_XXX.p8)"

app-store-connect fetch-signing-files co.ballee \\
  --type IOS_APP_STORE \\
  --create \\
  --verbose
```

#### 4. Check Private Key Format

Private key must be complete with headers:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
... (multiple lines) ...
-----END PRIVATE KEY-----
```

### "Certificate limit exceeded"

**Symptoms**:
- Error: "Maximum number of certificates generated"
- Cannot create new distribution certificate

**Cause**:
Apple limits distribution certificates to 3 per team.

**Solutions**:

#### 1. Check Existing Certificates

```bash
open https://developer.apple.com/account/resources/certificates/list

# Look for "Apple Distribution" certificates
# Check expiration dates
```

#### 2. Revoke Unused Certificates

- Select unused/expired certificates
- Click "Revoke"
- Codemagic will create new certificate automatically

#### 3. Use Existing Certificate

If you want to keep existing certificates, export one and use it:

```bash
# Export from Keychain (on Mac)
# File → Export → Choose .p12 format
# Set password

# Add to Codemagic via environment variable
# or upload in Team settings > Code signing identities
```

## Build Issues

### "Workflow 'X' does not exist"

**Symptoms**:
- Build fails immediately
- Error: `Workflow "ios-testflight" does not exist`

**Cause**:
`codemagic.yaml` not found or not at repository root.

**Solutions**:

#### 1. Move codemagic.yaml to Repository Root

```bash
# For monorepos
mv apps/mobile/codemagic.yaml ./codemagic.yaml

# Update workflow with working_directory
working_directory: apps/mobile
```

#### 2. Verify File is Committed

```bash
git add codemagic.yaml
git commit -m "Add codemagic.yaml"
git push
```

### "Flutter command not found"

**Symptoms**:
- Build fails during Flutter commands
- Error: `flutter: command not found`

**Cause**:
Flutter environment not specified or PATH issues.

**Solution**:

```yaml
environment:
  flutter: stable  # or specific version: 3.19.0
  xcode: latest
```

### "No Podfile found"

**Symptoms**:
- CocoaPods installation fails
- Error: `No Podfile found in the project directory`

**Cause**:
Working directory not set correctly.

**Solution**:

```yaml
scripts:
  - name: Install pods
    script: |
      cd ios && pod install
    # or
    script: |
      find . -name "Podfile" -execdir pod install \\;
```

### Build Timeout

**Symptoms**:
- Build exceeds maximum duration
- Build cancelled automatically

**Causes**:
1. Build taking too long (network issues, large dependencies)
2. `max_build_duration` set too low

**Solutions**:

```yaml
workflows:
  ios-testflight:
    max_build_duration: 120  # Increase to 120 minutes
    instance_type: mac_mini_m2  # Use faster instance
```

Optimize build:

```yaml
cache:
  cache_paths:
    - ~/.pub-cache
    - $CM_BUILD_DIR/ios/Pods
```

## Publishing Issues

### "App record must be created before you can upload builds"

**Symptoms**:
- TestFlight upload fails
- Error message about app record not existing

**Cause**:
App not created in App Store Connect.

**Solution**:

```bash
# 1. Create app in App Store Connect
open https://appstoreconnect.apple.com

# My Apps → "+" → New App
# - Platform: iOS
# - Name: Your App Name
# - Bundle ID: co.ballee (must match exactly)
# - SKU: Unique identifier
# - User Access: Full Access

# 2. Optional: Upload first build manually via Transporter
# This creates initial app structure in TestFlight
```

### "Build Processing Timeout"

**Symptoms**:
- Build succeeds but TestFlight processing times out
- Warning: "Build processing exceeded 120 minutes"

**Cause**:
Apple's processing takes longer than expected.

**Solution**:

This is normal for first builds. Subsequent builds process faster.

- Check TestFlight in App Store Connect after 30-60 minutes
- Build will appear even if Codemagic shows timeout

### "Invalid Archive"

**Symptoms**:
- Archive created but upload fails
- Error about invalid IPA or archive

**Causes**:
1. Code signing configuration incorrect
2. Entitlements mismatch
3. Missing required Info.plist keys

**Solutions**:

#### 1. Verify Code Signing

```bash
# Check which profiles were used
xcodebuild -showBuildSettings -workspace ios/Runner.xcworkspace \\
  -scheme Runner \\
  -configuration Release | grep CODE_SIGN
```

#### 2. Check Entitlements

```bash
# View entitlements
codesign -d --entitlements - build/ios/ipa/*.ipa
```

#### 3. Validate Archive Locally

```bash
# Build locally first
flutter build ipa --release

# Validate
xcrun altool --validate-app -f build/ios/ipa/*.ipa \\
  -t ios \\
  -u your-apple-id@example.com \\
  --password your-app-specific-password
```

## Environment Variable Issues

### Variables Not Available in Scripts

**Symptoms**:
- Environment variables undefined
- Scripts fail with "variable not set" errors

**Causes**:
1. Variables not added to Codemagic
2. Variable group not referenced in workflow
3. Typo in variable name

**Solutions**:

#### 1. Add Variables via API

```bash
curl -X POST \\
  -H "x-auth-token: $CODEMAGIC_API_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{
    "key": "MY_VARIABLE",
    "value": "my-value",
    "secure": false,
    "group": "my-group"
  }' \\
  "https://api.codemagic.io/apps/$APP_ID/variables"
```

#### 2. Reference Groups in Workflow

```yaml
environment:
  groups:
    - app_store_credentials
    - mobile
```

#### 3. Debug Variables

```yaml
scripts:
  - name: Debug environment
    script: |
      echo "All environment variables:"
      env | sort

      echo "Checking specific variables:"
      echo "APP_STORE_ID: ${APP_STORE_ID:-NOT SET}"
      echo "BACKEND_URL: ${BACKEND_URL:-NOT SET}"
```

### Secure Variables Show as Asterisks

**Symptom**:
Secure variables show as `********` in logs.

**This is expected behavior**. Codemagic masks secure variables for security.

To debug, temporarily mark variable as non-secure, test, then mark as secure again.

## Integration Issues

### "Integration 'X' not found"

**Symptoms**:
- Build fails with integration not found error

**Causes**:
1. Integration name mismatch
2. Integration configured at wrong level (app vs team)
3. Integration deleted or renamed

**Solutions**:

#### 1. Verify Integration Name Matches Exactly

```yaml
# Integration names are case-sensitive
integrations:
  app_store_connect: Ballee App Store Connect  # Must match UI exactly
```

#### 2. Check Integration Exists

```bash
# Go to team settings
open https://codemagic.io/teams

# Select team → Integrations → App Store Connect
# Copy exact integration name
```

#### 3. Use Team-Level Integrations

Configure integrations at team level (not app level) for better sharing and management.

## Network and Connection Issues

### "Connection to Apple servers failed"

**Symptoms**:
- Timeout errors
- Connection refused errors

**Causes**:
1. Temporary Apple server outage
2. Network connectivity issues
3. Rate limiting

**Solutions**:

#### 1. Retry Build

Apple servers occasionally have temporary issues. Wait 10-15 minutes and retry.

#### 2. Check Apple System Status

```bash
open https://developer.apple.com/system-status/
```

#### 3. Add Retry Logic

```yaml
scripts:
  - name: Fetch signing files with retry
    script: |
      for i in {1..3}; do
        if app-store-connect fetch-signing-files "$BUNDLE_ID" \\
          --type IOS_APP_STORE \\
          --create; then
          break
        fi
        echo "Retry $i/3 failed, waiting 30s..."
        sleep 30
      done
```

## Debugging Techniques

### Enable Verbose Logging

```yaml
scripts:
  - name: Verbose code signing
    script: |
      set -x  # Print all commands
      app-store-connect fetch-signing-files "$BUNDLE_ID" \\
        --type IOS_APP_STORE \\
        --create \\
        --verbose  # Verbose output
```

### Save Logs as Artifacts

```yaml
artifacts:
  - /tmp/xcodebuild_logs/*.log
  - flutter_drive.log
  - build/**/*.log
```

### Test Components Individually

Break complex scripts into smaller steps:

```yaml
scripts:
  - name: Test 1 - Environment
    script: env | sort

  - name: Test 2 - Fetch signing files
    script: |
      app-store-connect fetch-signing-files "$BUNDLE_ID" \\
        --type IOS_APP_STORE \\
        --create

  - name: Test 3 - Apply profiles
    script: xcode-project use-profiles

  - name: Test 4 - Build
    script: flutter build ipa --release
```

### Use SSH Access

Enable SSH access to debug builds interactively:

1. Trigger build via UI
2. Click "Enable SSH access" during build
3. SSH into build machine
4. Run commands manually

## Getting Help

### Codemagic Support

- Email: support@codemagic.io
- Include: Build ID, App ID, error messages, codemagic.yaml

### Community Resources

- **Documentation**: https://docs.codemagic.io
- **GitHub Discussions**: https://github.com/codemagic-ci-cd/cli-tools/discussions
- **Sample Projects**: https://github.com/codemagic-ci-cd/codemagic-sample-projects
- **Blog**: https://blog.codemagic.io

### Apple Developer Support

For Apple-specific issues:
- **Developer Forums**: https://developer.apple.com/forums/
- **System Status**: https://developer.apple.com/system-status/
- **Support**: https://developer.apple.com/support/

## Quick Reference: Common Error Messages

| Error | Common Cause | Quick Fix |
|-------|-------------|-----------|
| "Cannot save Signing Certificates without certificate private key" | Missing CERTIFICATE_PRIVATE_KEY | Generate with `openssl genrsa`, add to Codemagic |
| "No matching profiles found" | App ID or profile doesn't exist | Create in Apple Developer Portal + use `--create` |
| "Workflow does not exist" | codemagic.yaml not at repo root | Move file to root, add `working_directory` |
| "Certificate limit exceeded" | Too many certificates | Revoke old certificates |
| "Integration not found" | Name mismatch | Match integration name exactly |
| "Step X exited with status code 1" | Script failure | Add verbose logging, check environment variables |
| "Build processing timeout" | Apple processing slow | Wait 30-60 min, check TestFlight manually |
| "Invalid archive" | Code signing issue | Validate archive locally first |
| "App record must be created" | App not in App Store Connect | Create app record first |

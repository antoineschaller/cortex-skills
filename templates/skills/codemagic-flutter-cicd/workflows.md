# Codemagic Workflows Configuration

Complete guide to creating production-ready codemagic.yaml workflows for Flutter iOS apps.

## File Location

**CRITICAL**: `codemagic.yaml` MUST be at the repository root, even for monorepos.

```
✅ CORRECT:
/your-repo/codemagic.yaml
/your-repo/apps/mobile/    # Flutter app location

❌ WRONG:
/your-repo/apps/mobile/codemagic.yaml
```

For monorepos, use `working_directory` to specify the Flutter app location.

## Basic Workflow Structure

```yaml
workflows:
  <workflow-id>:
    name: <Workflow Display Name>
    max_build_duration: <minutes>
    instance_type: <mac_mini_m1|mac_mini_m2|mac_pro>
    working_directory: <path>  # Optional, for monorepos
    integrations:
      app_store_connect: <integration-name>
    environment:
      groups:
        - <env-group-name>
      vars:
        KEY: value
      flutter: <version>
      xcode: <version>
      cocoapods: <version>
    triggering:
      events:
        - push
        - pull_request
        - tag
      branch_patterns:
        - pattern: main
          include: true
    scripts:
      - name: <Step Name>
        script: |
          # Commands here
    artifacts:
      - build/**/*.ipa
    publishing:
      app_store_connect:
        auth: integration
        submit_to_testflight: true
```

## Complete Production Workflow

```yaml
workflows:
  ios-testflight:
    name: iOS TestFlight
    max_build_duration: 120
    instance_type: mac_mini_m2
    working_directory: apps/mobile  # For monorepos only

    integrations:
      app_store_connect: Ballee App Store Connect

    environment:
      groups:
        - app_store_credentials  # APP_STORE_CONNECT_* variables
        - mobile  # App-specific env vars

      vars:
        # App Store Connect
        APP_STORE_APPLE_ID: '1234567890'  # From App Store Connect URL

        # Xcode configuration
        XCODE_WORKSPACE: 'ios/Runner.xcworkspace'
        XCODE_SCHEME: 'Runner'
        BUNDLE_ID: 'co.ballee'

        # Build configuration
        BUILD_NAME: '1.0.0'

      # SDK versions
      flutter: stable  # or: 3.19.0, beta, dev
      xcode: latest    # or: 15.0, 14.3, etc.
      cocoapods: default

    triggering:
      events:
        - push
      branch_patterns:
        - pattern: main
          include: true
          source: true
      cancel_previous_builds: true

    scripts:
      # 1. Set up code signing
      - name: Set up code signing
        script: |
          app-store-connect fetch-signing-files "$BUNDLE_ID" \\
            --type IOS_APP_STORE \\
            --create

      # 2. Apply profiles to Xcode
      - name: Set up code signing settings on Xcode project
        script: |
          xcode-project use-profiles

      # 3. Get Flutter dependencies
      - name: Get Flutter packages
        script: |
          flutter pub get

      # 4. Generate code (if using build_runner)
      - name: Generate code (Freezed, Riverpod)
        script: |
          dart run build_runner build --delete-conflicting-outputs

      # 5. Install CocoaPods
      - name: Install pods
        script: |
          cd ios && pod install --repo-update

      # 6. Build IPA with auto-incrementing build number
      - name: Flutter build ipa
        script: |
          flutter build ipa --release \\
            --build-name="$BUILD_NAME" \\
            --build-number=$(($(app-store-connect get-latest-testflight-build-number "$APP_STORE_APPLE_ID") + 1)) \\
            --dart-define=ENV=prod \\
            --dart-define=APP_STORE_ID="$APP_STORE_ID" \\
            --dart-define=BACKEND_URL="$BACKEND_URL"

    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log

    publishing:
      email:
        recipients:
          - team@example.com
        notify:
          success: true
          failure: true

      slack:
        channel: '#deployments'
        notify_on_build_start: false
        notify:
          success: true
          failure: true

      app_store_connect:
        auth: integration

        # TestFlight settings
        submit_to_testflight: true
        beta_groups:
          - Internal Testers
          - External Testers

        # App Store submission (optional)
        submit_to_app_store: false
        release_type: MANUAL

        # Options
        cancel_previous_submissions: true
```

## Environment Configuration

### SDK Versions

```yaml
environment:
  flutter: stable       # Latest stable release
  flutter: 3.19.0       # Specific version
  flutter: beta         # Latest beta
  flutter: dev          # Latest dev

  xcode: latest         # Latest Xcode
  xcode: 15.0           # Specific Xcode version
  xcode: edge           # Beta Xcode

  cocoapods: default    # Latest stable CocoaPods
  cocoapods: 1.12.0     # Specific version
```

### Environment Variables

**Organize into groups**:

```yaml
environment:
  groups:
    - app_store_credentials  # Shared across apps
    - production_secrets     # Production-only secrets
    - mobile                 # App-specific variables
```

**Variable types**:

```yaml
vars:
  # Plain text (visible in logs)
  APP_NAME: 'Ballee'
  BACKEND_URL: 'https://api.example.com'

  # Secure variables (set in UI, marked as secure)
  # - SUPABASE_TOKEN
  # - SENTRY_DSN
  # - API_KEYS
```

### Working Directory (Monorepos)

```yaml
working_directory: apps/mobile  # Relative to repository root
```

All scripts run from this directory.

## Triggering

### Push Triggers

```yaml
triggering:
  events:
    - push
  branch_patterns:
    - pattern: main
      include: true
      source: true  # Trigger from source branch
    - pattern: develop
      include: true
    - pattern: 'release/*'
      include: true
    - pattern: 'feature/*'
      include: false  # Exclude feature branches
  cancel_previous_builds: true  # Cancel older builds on new push
```

### Pull Request Triggers

```yaml
triggering:
  events:
    - pull_request
  branch_patterns:
    - pattern: '*'  # All PRs
      include: true
```

### Tag Triggers

```yaml
triggering:
  events:
    - tag
  tag_patterns:
    - pattern: 'v*'  # Trigger on version tags (v1.0.0, v2.1.3, etc.)
      include: true
```

### Manual Triggers Only

```yaml
triggering:
  events: []  # No automatic triggers
```

Trigger manually via UI or API.

### Scheduled Builds

```yaml
triggering:
  events:
    - push
  branch_patterns:
    - pattern: main
      include: true
  schedule:
    - cron: "0 0 * * *"  # Daily at midnight UTC
      branch: main
```

## Scripts

### Script Options

```yaml
scripts:
  - name: Build step
    script: |
      echo "Building..."
      flutter build ipa

    # Optional settings
    ignore_failure: false  # Fail build if script fails (default: false)
    working_directory: ios  # Override workflow working_directory
```

### Common Script Patterns

#### Initialize Keychain

```bash
- name: Initialize keychain
  script: |
    keychain initialize
```

Codemagic helper command to set up code signing keychain.

#### Flutter Build with Dart Defines

```bash
- name: Build IPA with environment variables
  script: |
    flutter build ipa --release \\
      --dart-define=ENV=production \\
      --dart-define=API_URL="$BACKEND_URL" \\
      --dart-define=API_KEY="$API_KEY"
```

#### Auto-Incrementing Build Numbers

```bash
- name: Build with auto-increment
  script: |
    BUILD_NUMBER=$(($(app-store-connect get-latest-testflight-build-number "$APP_STORE_APPLE_ID") + 1))
    flutter build ipa --release \\
      --build-name=1.0.0 \\
      --build-number=$BUILD_NUMBER
```

#### Conditional Steps

```bash
- name: Run only on main branch
  script: |
    if [ "$CM_BRANCH" = "main" ]; then
      echo "Running on main"
      flutter test
    fi
```

#### Multi-line Scripts with Error Handling

```bash
- name: Complex build step
  script: |
    set -e  # Exit on error
    set -x  # Print commands (debugging)

    echo "Step 1"
    flutter pub get

    echo "Step 2"
    flutter test

    echo "Step 3"
    flutter build ipa
```

## Artifacts

Specify build outputs to preserve:

```yaml
artifacts:
  # iOS builds
  - build/ios/ipa/*.ipa
  - build/ios/archive/*.xcarchive

  # Logs
  - /tmp/xcodebuild_logs/*.log
  - flutter_drive.log

  # Test results
  - test-results/**/*.xml

  # Screenshots
  - screenshots/**/*.png
```

**Artifact retention**: 30 days by default

## Publishing

### TestFlight

```yaml
publishing:
  app_store_connect:
    auth: integration  # Use integration from integrations section

    # TestFlight
    submit_to_testflight: true
    beta_groups:
      - Internal Testers    # Exact group names from App Store Connect
      - External Testers

    # Auto-submit for beta review
    submit_to_beta_review: true

    # Cancel previous submissions
    cancel_previous_submissions: true
```

### App Store

```yaml
publishing:
  app_store_connect:
    auth: integration

    # App Store submission
    submit_to_app_store: true
    release_type: MANUAL  # MANUAL, AFTER_APPROVAL, SCHEDULED
    earliest_release_date: 2024-01-15T00:00:00+00:00  # ISO 8601 format

    # Metadata
    copyright: "2024 Your Company"

    # Phased release
    phased_release: true

    # Version localization
    whats_new: |
      Bug fixes and performance improvements
```

### Email Notifications

```yaml
publishing:
  email:
    recipients:
      - dev@example.com
      - qa@example.com
    notify:
      success: true
      failure: true
```

### Slack Notifications

```yaml
publishing:
  slack:
    channel: '#mobile-builds'
    notify_on_build_start: true
    notify:
      success: true
      failure: true
      cancelled: false
```

## Multiple Workflows

Define multiple workflows for different purposes:

```yaml
workflows:
  # Development builds
  ios-dev:
    name: iOS Development
    instance_type: mac_mini_m1
    environment:
      ios_signing:
        distribution_type: development
        bundle_identifier: co.ballee.dev
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: develop
          include: true

  # Production builds
  ios-production:
    name: iOS Production
    instance_type: mac_mini_m2
    environment:
      ios_signing:
        distribution_type: app_store
        bundle_identifier: co.ballee
    triggering:
      events:
        - push
      branch_patterns:
        - pattern: main
          include: true
    publishing:
      app_store_connect:
        submit_to_testflight: true

  # Pull request validation
  ios-pr:
    name: iOS PR Validation
    instance_type: mac_mini_m1
    triggering:
      events:
        - pull_request
    scripts:
      - name: Analyze
        script: flutter analyze
      - name: Test
        script: flutter test
```

## Codemagic Built-in Environment Variables

Available in all scripts:

| Variable | Description |
|----------|-------------|
| `CM_BUILD_ID` | Unique build identifier |
| `CM_BUILD_NUMBER` | Incremental build number |
| `CM_BUILD_DIR` | Build directory path |
| `CM_BRANCH` | Git branch name |
| `CM_TAG` | Git tag (if triggered by tag) |
| `CM_COMMIT` | Git commit SHA |
| `CM_REPO_SLUG` | Repository slug (owner/repo) |
| `CM_PULL_REQUEST` | Pull request number (if PR build) |
| `CM_PULL_REQUEST_DEST` | PR destination branch |
| `FCI_BUILD_STEP_STATUS` | Current step status |
| `FCI_BUILD_STEP_NAME` | Current step name |

## Advanced Patterns

### Conditional Workflows

```yaml
workflows:
  ios-testflight:
    when:
      changeset:
        includes:
          - 'apps/mobile/'
        excludes:
          - '**/*.md'
```

### Dependency Caching

```yaml
workflows:
  ios-testflight:
    cache:
      cache_paths:
        - ~/.pub-cache
        - ~/Library/Caches/CocoaPods
```

### Post-Build Scripts

```yaml
scripts:
  - name: Build IPA
    script: flutter build ipa

  - name: Upload to Custom Server
    script: |
      if [ "$CM_BRANCH" = "main" ]; then
        curl -F "file=@build/ios/ipa/*.ipa" https://deploy.example.com/upload
      fi
```

## Best Practices

1. **Use Environment Groups**: Organize variables into logical groups
2. **Secure Sensitive Data**: Mark API keys and tokens as secure
3. **Auto-Increment Build Numbers**: Use `app-store-connect get-latest-testflight-build-number`
4. **Cancel Previous Builds**: Set `cancel_previous_builds: true` to save resources
5. **Separate Workflows**: Use different workflows for dev/staging/production
6. **Version SDK**: Pin Flutter/Xcode versions for reproducible builds
7. **Add Logging**: Use `set -x` in scripts for debugging
8. **Fail Fast**: Use `set -e` to exit on first error
9. **Save Artifacts**: Capture logs and build outputs for debugging
10. **Notify Teams**: Configure email/Slack for build status updates

## Resources

- **Workflow Docs**: https://docs.codemagic.io/yaml/yaml-getting-started/
- **Environment Variables**: https://docs.codemagic.io/yaml-basic-configuration/configuring-environment-variables/
- **Sample Workflows**: https://github.com/codemagic-ci-cd/codemagic-sample-projects

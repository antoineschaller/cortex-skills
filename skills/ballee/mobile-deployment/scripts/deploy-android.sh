#!/bin/bash
#
# deploy-android.sh - Deploy Ballee Android app
#
# Usage:
#   ./deploy-android.sh              # Build AAB for Play Store
#   ./deploy-android.sh --apk        # Build APK instead
#   ./deploy-android.sh --firebase   # Deploy to Firebase App Distribution
#   ./deploy-android.sh --playstore  # Deploy to Play Store
#
# Prerequisites:
#   - key.properties configured in apps/mobile/android/
#   - Flutter SDK installed
#   - For Firebase: Firebase CLI and service account
#   - For Play Store: Play Store service account JSON

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
MOBILE_DIR="$REPO_ROOT/apps/mobile"
ANDROID_DIR="$MOBILE_DIR/android"

# Load environment variables from .env.local
ENV_FILE="$REPO_ROOT/.env.local"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# Production Supabase credentials (from .env.local)
SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${NEXT_PUBLIC_SUPABASE_ANON_KEY:-}"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
    echo "❌ Error: NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY must be set in .env.local"
    exit 1
fi

# Parse arguments
BUILD_TYPE="aab"
DEPLOY_TARGET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --apk)
            BUILD_TYPE="apk"
            shift
            ;;
        --firebase)
            DEPLOY_TARGET="firebase"
            shift
            ;;
        --playstore)
            DEPLOY_TARGET="playstore"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --apk        Build APK instead of AAB"
            echo "  --firebase   Deploy to Firebase App Distribution"
            echo "  --playstore  Deploy to Play Store (internal track)"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "==========================================="
echo "Ballee Android Deployment"
echo "==========================================="
echo "Started: $(date)"
echo "Build type: $BUILD_TYPE"
echo "Deploy target: ${DEPLOY_TARGET:-none (build only)}"
echo "==========================================="

# Check prerequisites
echo ""
echo "[1/5] Checking prerequisites..."

if ! command -v flutter &> /dev/null; then
    echo "ERROR: Flutter not found. Please install Flutter."
    exit 1
fi

# Check for signing configuration
KEY_PROPS="$ANDROID_DIR/key.properties"
if [ ! -f "$KEY_PROPS" ]; then
    echo "WARNING: key.properties not found at $KEY_PROPS"
    echo "Release builds will use debug signing."
    echo ""
    echo "To set up release signing, run:"
    echo "  ./.claude/skills/mobile-deployment/scripts/setup-android-signing.sh"
    echo ""
fi

echo "  Flutter: $(flutter --version | head -1)"
echo "  Signing: $([ -f "$KEY_PROPS" ] && echo "Configured" || echo "Not configured")"

# Install dependencies and run code generation
echo ""
echo "[2/5] Installing dependencies..."
cd "$MOBILE_DIR"

flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Build the app
echo ""
echo "[3/5] Building release $BUILD_TYPE..."
cd "$MOBILE_DIR"

DART_DEFINES=(
    "--dart-define=ENV=prod"
    "--dart-define=BACKEND_URL=$SUPABASE_URL"
    "--dart-define=SUPABASE_TOKEN=$SUPABASE_ANON_KEY"
)

if [ "$BUILD_TYPE" = "apk" ]; then
    flutter build apk --release "${DART_DEFINES[@]}"
    OUTPUT_FILE="$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk"
else
    flutter build appbundle --release "${DART_DEFINES[@]}"
    OUTPUT_FILE="$MOBILE_DIR/build/app/outputs/bundle/release/app-release.aab"
fi

echo "Build output: $OUTPUT_FILE"

# Deploy if requested
if [ -n "$DEPLOY_TARGET" ]; then
    echo ""
    echo "[4/5] Deploying to $DEPLOY_TARGET..."
    cd "$ANDROID_DIR"

    # Check for Fastlane
    if [ -f "Gemfile" ]; then
        bundle install --quiet

        case $DEPLOY_TARGET in
            firebase)
                bundle exec fastlane firebase
                ;;
            playstore)
                bundle exec fastlane playstore
                ;;
        esac
    else
        echo "ERROR: Fastlane not configured for Android."
        echo "Please set up Fastlane in $ANDROID_DIR first."
        echo ""
        echo "For manual upload:"
        if [ "$DEPLOY_TARGET" = "firebase" ]; then
            echo "  firebase appdistribution:distribute $OUTPUT_FILE --app YOUR_APP_ID"
        else
            echo "  Upload $OUTPUT_FILE to Google Play Console"
        fi
        exit 1
    fi
else
    echo ""
    echo "[4/5] Skipping deployment (no target specified)"
fi

# Done
echo ""
echo "==========================================="
echo "Android Deployment Complete"
echo "==========================================="
echo "Finished: $(date)"
echo "Output: $OUTPUT_FILE"

if [ -z "$DEPLOY_TARGET" ]; then
    echo ""
    echo "To deploy, run with:"
    echo "  --firebase   Deploy to Firebase App Distribution"
    echo "  --playstore  Deploy to Play Store"
fi
echo "==========================================="

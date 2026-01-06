#!/bin/bash
#
# deploy-ios.sh - Deploy Ballee iOS app to TestFlight
#
# Usage:
#   ./deploy-ios.sh              # Build and upload to TestFlight
#   ./deploy-ios.sh --increment  # Increment build number first
#   ./deploy-ios.sh --skip-upload # Build only, don't upload
#
# Prerequisites:
#   - App Store Connect API key at ~/.appstoreconnect/private_keys/AuthKey_LGU934Y2XR.p8
#   - Valid Apple Developer distribution certificate
#   - Ruby and Bundler installed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
MOBILE_DIR="$REPO_ROOT/apps/mobile"
IOS_DIR="$MOBILE_DIR/ios"

# Load environment variables from .env.local
ENV_FILE="$REPO_ROOT/.env.local"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# App Store Connect Configuration (from .env.local or defaults)
API_KEY_ID="${APPSTORE_API_KEY_ID:-LGU934Y2XR}"
API_ISSUER_ID="${APPSTORE_API_ISSUER_ID:-69a6de96-5d75-47e3-e053-5b8c7c11a4d1}"
API_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"
TEAM_ID="${APPLE_TEAM_ID:-A86CXY8H75}"

# Production Supabase credentials (from .env.local)
SUPABASE_URL="${NEXT_PUBLIC_SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${NEXT_PUBLIC_SUPABASE_ANON_KEY:-}"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
    echo "❌ Error: NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY must be set in .env.local"
    exit 1
fi

# Parse arguments
INCREMENT_BUILD=false
SKIP_UPLOAD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --increment)
            INCREMENT_BUILD=true
            shift
            ;;
        --skip-upload)
            SKIP_UPLOAD=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --increment    Increment build number before building"
            echo "  --skip-upload  Build only, don't upload to TestFlight"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "==========================================="
echo "Ballee iOS Deployment"
echo "==========================================="
echo "Started: $(date)"
echo "==========================================="

# Check prerequisites
echo ""
echo "[1/6] Checking prerequisites..."

if [ ! -f "$API_KEY_PATH" ]; then
    echo "ERROR: App Store Connect API key not found at $API_KEY_PATH"
    echo "Please place your API key there."
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    echo "ERROR: Flutter not found. Please install Flutter."
    exit 1
fi

if ! command -v bundle &> /dev/null; then
    echo "ERROR: Bundler not found. Please run: gem install bundler"
    exit 1
fi

echo "  API Key: Found"
echo "  Flutter: $(flutter --version | head -1)"
echo "  Bundler: Found"

# Install Ruby dependencies
echo ""
echo "[2/6] Installing Ruby dependencies..."
cd "$IOS_DIR"
bundle install --quiet

# Build Flutter app
echo ""
echo "[3/6] Building Flutter app..."
cd "$MOBILE_DIR"

flutter pub get
dart run build_runner build --delete-conflicting-outputs

flutter build ios --release --no-codesign \
    --dart-define=ENV=prod \
    --dart-define=BACKEND_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_TOKEN="$SUPABASE_ANON_KEY"

# Install CocoaPods
echo ""
echo "[4/6] Installing CocoaPods..."
cd "$IOS_DIR"
pod install --repo-update

# Run Fastlane
echo ""
echo "[5/6] Building and signing with Fastlane..."
cd "$IOS_DIR"

if [ "$SKIP_UPLOAD" = true ]; then
    echo "Building IPA only (skipping upload)..."
    bundle exec fastlane build_only
else
    if [ "$INCREMENT_BUILD" = true ]; then
        echo "Incrementing build number and uploading to TestFlight..."
        bundle exec fastlane beta_auto increment_build:true
    else
        echo "Uploading to TestFlight..."
        bundle exec fastlane beta_auto
    fi
fi

# Done
echo ""
echo "==========================================="
echo "iOS Deployment Complete"
echo "==========================================="
echo "Finished: $(date)"

if [ "$SKIP_UPLOAD" = true ]; then
    echo "IPA location: $IOS_DIR/build/Ballee.ipa"
else
    echo "Check TestFlight for the new build!"
fi
echo "==========================================="

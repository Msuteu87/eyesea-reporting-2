#!/bin/bash

# iOS Release Build Script for TestFlight
# This script builds the iOS app with proper environment variables for production

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🚀 Building iOS Release for TestFlight"
echo "========================================"
echo ""

# Check if .env file exists (for reading values)
if [ ! -f ".env" ]; then
    echo "⚠️  Warning: .env file not found"
    echo "   Make sure to set environment variables manually or use --dart-define flags"
    echo ""
fi

# Load .env file if it exists
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Verify required environment variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ] || [ -z "$MAPBOX_ACCESS_TOKEN" ]; then
    echo "❌ Error: Missing required environment variables"
    echo ""
    echo "Required variables:"
    echo "  - SUPABASE_URL"
    echo "  - SUPABASE_ANON_KEY"
    echo "  - MAPBOX_ACCESS_TOKEN"
    echo ""
    echo "Set them in:"
    echo "  1. .env file (for local builds)"
    echo "  2. Environment variables"
    echo "  3. Or pass via --dart-define flags"
    echo ""
    exit 1
fi

echo "✅ Environment variables loaded"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
cd ios && pod install && cd ..
echo ""

# Build iOS release with environment variables
echo "📦 Building iOS release..."
echo ""

flutter build ios --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN" \
    --no-codesign

echo ""
echo "✅ iOS release build complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Open ios/Runner.xcworkspace in Xcode"
echo "  2. Select 'Any iOS Device' or your device"
echo "  3. Product → Archive"
echo "  4. Distribute App → App Store Connect → Upload"
echo ""
echo "⚠️  Important:"
echo "  - Make sure code signing is configured in Xcode"
echo "  - Verify bundle ID matches: com.mariussuteu.eyesea.eyeseareporting"
echo "  - Check that all secrets are properly set"
echo ""

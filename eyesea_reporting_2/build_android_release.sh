#!/bin/bash

# Android Release Build Script for Google Play
# This script builds the Android app with proper environment variables for production

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🚀 Building Android Release for Google Play"
echo "============================================="
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

# Check if keystore exists
if [ ! -f "android/app/eyesea-release-key.jks" ]; then
    echo "⚠️  Warning: Release keystore not found"
    echo "   Run: ./setup_android_signing.sh (or see CODE_SIGNING_SETUP.md)"
    echo ""
fi

echo "✅ Environment variables loaded"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
echo ""

# Build Android release with environment variables
echo "📦 Building Android release APK..."
echo ""

flutter build apk --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"

echo ""
echo "✅ Android release APK build complete!"
echo ""

# Also build App Bundle for Play Store
echo "📦 Building Android App Bundle (AAB) for Google Play..."
echo ""

flutter build appbundle --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"

echo ""
echo "✅ Android App Bundle build complete!"
echo ""
echo "📝 Build outputs:"
echo "  - APK: build/app/outputs/flutter-apk/app-release.apk"
echo "  - AAB: build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "📝 Next steps for Google Play:"
echo "  1. Go to Google Play Console"
echo "  2. Create new release (or update existing)"
echo "  3. Upload app-release.aab"
echo "  4. Fill in release notes"
echo "  5. Review and publish"
echo ""
echo "⚠️  Important:"
echo "  - Verify keystore is properly configured"
echo "  - Check that all secrets are properly set"
echo "  - Test the APK before uploading AAB"
echo ""

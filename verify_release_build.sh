#!/bin/bash

# Verify Release Build Configuration
# Checks if all required secrets and configurations are in place

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🔍 Verifying Release Build Configuration"
echo "========================================"
echo ""

ERRORS=0
WARNINGS=0

# Check .env file
echo "📋 Environment Variables:"
if [ -f ".env" ]; then
    echo "  ✅ .env file exists"
    
    # Check required variables
    source .env 2>/dev/null || true
    
    if [ -z "$SUPABASE_URL" ]; then
        echo "  ❌ SUPABASE_URL not set"
        ERRORS=$((ERRORS + 1))
    else
        echo "  ✅ SUPABASE_URL is set"
    fi
    
    if [ -z "$SUPABASE_ANON_KEY" ]; then
        echo "  ❌ SUPABASE_ANON_KEY not set"
        ERRORS=$((ERRORS + 1))
    else
        echo "  ✅ SUPABASE_ANON_KEY is set"
    fi
    
    if [ -z "$MAPBOX_ACCESS_TOKEN" ]; then
        echo "  ❌ MAPBOX_ACCESS_TOKEN not set"
        ERRORS=$((ERRORS + 1))
    else
        echo "  ✅ MAPBOX_ACCESS_TOKEN is set"
    fi
else
    echo "  ⚠️  .env file not found (will use --dart-define flags)"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# Check iOS configuration
echo "🍎 iOS Configuration:"
if [ -f "ios/Flutter/Secrets.xcconfig" ]; then
    echo "  ✅ Secrets.xcconfig exists"
else
    echo "  ⚠️  Secrets.xcconfig not found (will use --dart-define flags)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check bundle ID
BUNDLE_ID=$(grep -o "PRODUCT_BUNDLE_IDENTIFIER = [^;]*" ios/Runner.xcodeproj/project.pbxproj 2>/dev/null | head -1 | sed 's/PRODUCT_BUNDLE_IDENTIFIER = //' || echo "")
if [ ! -z "$BUNDLE_ID" ]; then
    echo "  ✅ Bundle ID: $BUNDLE_ID"
else
    echo "  ⚠️  Bundle ID not found"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# Check Android configuration
echo "🤖 Android Configuration:"
if [ -f "android/app/eyesea-release-key.jks" ]; then
    echo "  ✅ Release keystore exists"
else
    echo "  ⚠️  Release keystore not found"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -f "android/key.properties" ]; then
    echo "  ✅ key.properties exists"
else
    echo "  ⚠️  key.properties not found"
    WARNINGS=$((WARNINGS + 1))
fi

# Check gradle.properties
if [ -f "android/gradle.properties" ]; then
    if grep -q "MAPBOX_ACCESS_TOKEN" android/gradle.properties; then
        echo "  ✅ MAPBOX_ACCESS_TOKEN in gradle.properties"
    else
        echo "  ⚠️  MAPBOX_ACCESS_TOKEN not in gradle.properties"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

echo ""

# Check version
echo "📦 Version Information:"
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
BUILD=$(grep "^version:" pubspec.yaml | sed 's/.*+//')
echo "  Version: $VERSION"
echo "  Build: $BUILD"

echo ""
echo "=========================="
echo "📊 Summary"
echo "=========================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ Everything is configured correctly!"
    echo ""
    echo "Ready to build:"
    echo "  iOS: ./build_ios_release.sh"
    echo "  Android: ./build_android_release.sh"
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  $WARNINGS warning(s) found"
    echo ""
    echo "You can still build, but review warnings above."
    echo "For production, ensure all secrets are set via --dart-define flags."
else
    echo "❌ $ERRORS error(s) and $WARNINGS warning(s) found"
    echo ""
    echo "Fix errors before building for release."
fi

echo ""
echo "📝 Important:"
echo "  - Use build scripts (build_ios_release.sh / build_android_release.sh)"
echo "  - They automatically include --dart-define flags"
echo "  - This ensures secrets are included in production builds"
echo ""

exit $ERRORS

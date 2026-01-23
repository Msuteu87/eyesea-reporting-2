#!/bin/bash

# Verification script for new laptop setup
# Checks if everything is configured correctly

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "🔍 Verifying Project Setup"
echo "=========================="
echo ""

ERRORS=0
WARNINGS=0

# Check Flutter
echo "📱 Flutter:"
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -1)
    echo "  ✅ Flutter installed: $FLUTTER_VERSION"
else
    echo "  ❌ Flutter not found in PATH"
    ERRORS=$((ERRORS + 1))
fi

# Check Xcode
echo ""
echo "🍎 Xcode:"
if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -1)
    echo "  ✅ Xcode installed: $XCODE_VERSION"
    
    # Check if signed in
    if xcodebuild -checkFirstLaunchStatus 2>&1 | grep -q "first launch"; then
        echo "  ⚠️  Xcode first launch - you may need to accept license"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "  ❌ Xcode not found"
    ERRORS=$((ERRORS + 1))
fi

# Check CocoaPods
echo ""
echo "📦 CocoaPods:"
if command -v pod &> /dev/null; then
    POD_VERSION=$(pod --version)
    echo "  ✅ CocoaPods installed: $POD_VERSION"
else
    echo "  ❌ CocoaPods not found"
    ERRORS=$((ERRORS + 1))
fi

# Check .env file
echo ""
echo "🔐 Environment Variables:"
if [ -f ".env" ]; then
    echo "  ✅ .env file exists"
    if grep -q "SUPABASE_URL" .env && grep -q "SUPABASE_ANON_KEY" .env && grep -q "MAPBOX_ACCESS_TOKEN" .env; then
        echo "  ✅ Required variables present"
    else
        echo "  ⚠️  Some required variables missing"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "  ⚠️  .env file not found"
    WARNINGS=$((WARNINGS + 1))
fi

# Check iOS secrets
echo ""
echo "🍎 iOS Secrets:"
if [ -f "ios/Flutter/Secrets.xcconfig" ]; then
    echo "  ✅ Secrets.xcconfig exists"
else
    echo "  ⚠️  Secrets.xcconfig not found (copy from .example)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check development team
echo ""
echo "👥 Development Team:"
TEAM_IDS=$(grep -o "DEVELOPMENT_TEAM = [^;]*" ios/Runner.xcodeproj/project.pbxproj 2>/dev/null | sort -u || echo "")
if [ ! -z "$TEAM_IDS" ]; then
    echo "  ✅ Team ID(s) found:"
    echo "$TEAM_IDS" | sed 's/^/    /'
else
    echo "  ⚠️  No development team configured"
    WARNINGS=$((WARNINGS + 1))
fi

# Check bundle ID
echo ""
echo "📦 Bundle ID:"
BUNDLE_ID=$(grep -o "PRODUCT_BUNDLE_IDENTIFIER = [^;]*" ios/Runner.xcodeproj/project.pbxproj 2>/dev/null | head -1 | sed 's/PRODUCT_BUNDLE_IDENTIFIER = //' || echo "")
if [ ! -z "$BUNDLE_ID" ]; then
    echo "  ✅ Bundle ID: $BUNDLE_ID"
else
    echo "  ⚠️  Bundle ID not found"
    WARNINGS=$((WARNINGS + 1))
fi

# Check Flutter dependencies
echo ""
echo "📚 Flutter Dependencies:"
if [ -f "pubspec.lock" ]; then
    echo "  ✅ Dependencies installed (pubspec.lock exists)"
else
    echo "  ⚠️  Run 'flutter pub get' to install dependencies"
    WARNINGS=$((WARNINGS + 1))
fi

# Check iOS Pods
echo ""
echo "📦 iOS Pods:"
if [ -d "ios/Pods" ]; then
    echo "  ✅ Pods installed"
else
    echo "  ⚠️  Run 'cd ios && pod install && cd ..' to install pods"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "=========================="
echo "📊 Summary"
echo "=========================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ Everything looks good!"
    echo ""
    echo "Next steps:"
    echo "  1. Open project in Xcode: open ios/Runner.xcworkspace"
    echo "  2. Verify signing: Runner target → Signing & Capabilities"
    echo "  3. Test build: flutter run"
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  $WARNINGS warning(s) found - review above"
    echo ""
    echo "Most issues can be fixed by:"
    echo "  - Creating .env file from .env.example"
    echo "  - Running: flutter pub get"
    echo "  - Running: cd ios && pod install && cd .."
else
    echo "❌ $ERRORS error(s) and $WARNINGS warning(s) found"
    echo ""
    echo "Fix errors first, then review warnings"
fi

exit $ERRORS

#!/bin/bash

# Helper script to configure Android SDK after installation

set -e

echo "🔧 Android SDK Configuration Helper"
echo "===================================="
echo ""

# Check if Android Studio is installed
if [ ! -d "/Applications/Android Studio.app" ]; then
    echo "❌ Android Studio not found"
    echo ""
    echo "Please install Android Studio first:"
    echo "  https://developer.android.com/studio"
    exit 1
fi

echo "✅ Android Studio is installed"
echo ""

# Common SDK locations
SDK_LOCATIONS=(
    "$HOME/Library/Android/sdk"
    "$HOME/Android/Sdk"
    "/usr/local/android-sdk"
)

SDK_FOUND=""

for location in "${SDK_LOCATIONS[@]}"; do
    if [ -d "$location" ] && [ -d "$location/platform-tools" ]; then
        SDK_FOUND="$location"
        echo "✅ Found Android SDK at: $location"
        break
    fi
done

if [ -z "$SDK_FOUND" ]; then
    echo "⚠️  Android SDK not found in common locations"
    echo ""
    echo "Please do one of the following:"
    echo ""
    echo "Option 1: Let Android Studio set it up (Recommended)"
    echo "  1. Open Android Studio"
    echo "  2. On first launch, it will guide you through SDK installation"
    echo "  3. Accept licenses and install components"
    echo "  4. Note the SDK location (usually ~/Library/Android/sdk)"
    echo "  5. Run this script again, or manually:"
    echo "     flutter config --android-sdk ~/Library/Android/sdk"
    echo ""
    echo "Option 2: Manual SDK setup"
    echo "  1. Open Android Studio"
    echo "  2. Go to: Preferences → Appearance & Behavior → System Settings → Android SDK"
    echo "  3. Check 'Android SDK Location' path"
    echo "  4. Install SDK Platform-Tools and Build-Tools if not installed"
    echo "  5. Run: flutter config --android-sdk <sdk-location>"
    echo ""
    exit 1
fi

# Configure Flutter
echo ""
echo "🔧 Configuring Flutter to use Android SDK..."
flutter config --android-sdk "$SDK_FOUND"

echo ""
echo "✅ Flutter configured!"
echo ""

# Verify
echo "🔍 Verifying setup..."
flutter doctor 2>&1 | grep -A 5 "Android toolchain" || true

echo ""
echo "📝 Next steps:"
echo "  1. If Android toolchain shows [✓], you're ready!"
echo "  2. Run: ./build_android_release.sh"
echo "  3. If it still shows [✗], you may need to:"
echo "     - Accept Android licenses: flutter doctor --android-licenses"
echo "     - Install additional SDK components in Android Studio"
echo ""

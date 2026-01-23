#!/bin/bash

# iOS Build Cleanup Script
# Fixes code signing errors and stale build artifacts

set -e

echo "🧹 iOS Build Cleanup Script"
echo "=========================="
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "📍 Working directory: $(pwd)"
echo ""

# Step 1: Clean Flutter build
echo "Step 1/5: Cleaning Flutter build..."
flutter clean
echo "✅ Flutter build cleaned"
echo ""

# Step 2: Remove extended attributes
echo "Step 2/5: Removing extended attributes..."
xattr -rc . 2>/dev/null || true
echo "✅ Extended attributes removed"
echo ""

# Step 3: Clean Xcode derived data
echo "Step 3/5: Cleaning Xcode derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-* 2>/dev/null || true
echo "✅ Xcode derived data cleaned"
echo ""

# Step 4: Regenerate Flutter configuration
echo "Step 4/5: Regenerating Flutter configuration..."
flutter pub get
echo "✅ Flutter configuration regenerated"
echo ""

# Step 5: Reinstall CocoaPods
echo "Step 5/5: Reinstalling CocoaPods..."
cd ios
pod install
cd ..
echo "✅ CocoaPods reinstalled"
echo ""

echo "=========================="
echo "✅ Cleanup complete!"
echo ""
echo "You can now run:"
echo "  flutter run"
echo "  flutter build ios --debug"
echo "  flutter build ios --release"
echo ""

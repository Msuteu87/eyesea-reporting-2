#!/bin/bash

# Disk Space Cleanup Script for Flutter/iOS Development
# This script safely cleans up caches and build artifacts

echo "🧹 Starting disk space cleanup..."
echo ""

# Check current disk usage
echo "📊 Current disk usage:"
df -h / | tail -1
echo ""

# Clean Flutter project build artifacts
echo "🗑️  Cleaning Flutter build artifacts..."
flutter clean
echo ""

# Clean Android build artifacts
echo "🗑️  Cleaning Android build artifacts..."
rm -rf android/.gradle
rm -rf android/app/build
rm -rf android/build
echo "✅ Android artifacts cleaned"
echo ""

# Clean iOS build artifacts
echo "🗑️  Cleaning iOS build artifacts..."
rm -rf ios/build
rm -rf ios/Pods
rm -rf ios/.symlinks
echo "✅ iOS artifacts cleaned"
echo ""

# Clean Gradle caches (optional, will be redownloaded)
echo "⚠️  Gradle cache is using:"
du -sh ~/.gradle 2>/dev/null || echo "No Gradle cache"
read -p "Do you want to clean Gradle cache? This will redownload dependencies. (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Cleaning Gradle cache..."
    rm -rf ~/.gradle/caches
    rm -rf ~/.gradle/daemon
    echo "✅ Gradle cache cleaned"
fi
echo ""

# Clean pub cache (optional, will be redownloaded)
echo "⚠️  Pub cache is using:"
du -sh ~/.pub-cache 2>/dev/null || echo "No pub cache"
read -p "Do you want to clean pub cache? This will redownload dependencies. (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Cleaning pub cache..."
    flutter pub cache clean --force
    echo "✅ Pub cache cleaned"
fi
echo ""

# Clean Xcode derived data
echo "⚠️  Xcode DerivedData is using:"
du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null || echo "No DerivedData"
read -p "Do you want to clean Xcode DerivedData? This is safe and recommended. (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Cleaning Xcode DerivedData..."
    rm -rf ~/Library/Developer/Xcode/DerivedData
    echo "✅ Xcode DerivedData cleaned"
fi
echo ""

# Clean Xcode archives (old builds)
echo "⚠️  Xcode Archives is using:"
du -sh ~/Library/Developer/Xcode/Archives 2>/dev/null || echo "No Archives"
read -p "Do you want to clean old Xcode Archives? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Cleaning Xcode Archives..."
    rm -rf ~/Library/Developer/Xcode/Archives
    echo "✅ Xcode Archives cleaned"
fi
echo ""

# Final disk usage
echo "📊 Final disk usage:"
df -h / | tail -1
echo ""
echo "✨ Cleanup complete!"

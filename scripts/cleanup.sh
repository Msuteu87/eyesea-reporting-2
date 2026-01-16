#!/bin/bash
echo "🧹 Starting safe cleanup..."

# 1. Clean Flutter Project
echo "cleaning flutter..."
flutter clean

# 2. XCode Derived Data (Safe to delete, rebuilds automatically)
echo "Removing Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 3. iOS Simulators (Delete unavailable/broken ones)
echo "Pruning unavailable simulators..."
xcrun simctl delete unavailable

# 4. Gradle Cache (Can grow large, safe to clear)
echo "Clearing Gradle cache..."
rm -rf ~/.gradle/caches/

# 5. Pod Cache
echo "Cleaning Pod cache..."
pod cache clean --all

echo "✅ Cleanup complete! usage may still be high if you have many iOS Runtimes installed."
echo "To remove old iOS Runtimes, Check: /Library/Developer/CoreSimulator/Profiles/Runtimes/"

#!/bin/bash

# Script to update Development Team ID in iOS project
# Usage: ./update_team_id.sh <NEW_TEAM_ID>

set -e

if [ -z "$1" ]; then
    echo "❌ Error: Team ID required"
    echo ""
    echo "Usage: ./update_team_id.sh <NEW_TEAM_ID>"
    echo ""
    echo "Example: ./update_team_id.sh ABC123XYZ4"
    echo ""
    echo "To find your Team ID:"
    echo "  1. Xcode → Settings → Accounts → Select team"
    echo "  2. Apple Developer Portal → Top right corner"
    exit 1
fi

NEW_TEAM_ID="$1"
OLD_TEAM_ID="PD3WHVUAM3"
PROJECT_FILE="ios/Runner.xcodeproj/project.pbxproj"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: Project file not found: $PROJECT_FILE"
    exit 1
fi

echo "🔄 Updating Development Team ID"
echo "================================"
echo ""
echo "Old Team ID: $OLD_TEAM_ID"
echo "New Team ID: $NEW_TEAM_ID"
echo ""

# Backup project file
cp "$PROJECT_FILE" "${PROJECT_FILE}.backup"
echo "✅ Backup created: ${PROJECT_FILE}.backup"

# Update team ID
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/DEVELOPMENT_TEAM = $OLD_TEAM_ID;/DEVELOPMENT_TEAM = $NEW_TEAM_ID;/g" "$PROJECT_FILE"
else
    # Linux
    sed -i "s/DEVELOPMENT_TEAM = $OLD_TEAM_ID;/DEVELOPMENT_TEAM = $NEW_TEAM_ID;/g" "$PROJECT_FILE"
fi

# Verify changes
UPDATED_COUNT=$(grep -c "DEVELOPMENT_TEAM = $NEW_TEAM_ID;" "$PROJECT_FILE" || true)

if [ "$UPDATED_COUNT" -gt 0 ]; then
    echo "✅ Updated $UPDATED_COUNT occurrence(s) of DEVELOPMENT_TEAM"
    echo ""
    echo "Next steps:"
    echo "  1. Open project in Xcode:"
    echo "     open ios/Runner.xcworkspace"
    echo ""
    echo "  2. Verify signing:"
    echo "     - Select Runner target"
    echo "     - Go to Signing & Capabilities"
    echo "     - Verify team is selected"
    echo ""
    echo "  3. Clean and rebuild:"
    echo "     flutter clean"
    echo "     cd ios && pod install && cd .."
    echo "     flutter run"
    echo ""
    echo "⚠️  Note: You may need to:"
    echo "  - Sign in to Xcode with the Apple ID for the new team"
    echo "  - Register the bundle ID in the new team's Apple Developer account"
else
    echo "⚠️  Warning: No occurrences found. Team ID might already be different."
    echo "   Current team IDs in project:"
    grep "DEVELOPMENT_TEAM" "$PROJECT_FILE" | sort -u
fi

echo ""
echo "📝 To restore backup:"
echo "   cp ${PROJECT_FILE}.backup $PROJECT_FILE"

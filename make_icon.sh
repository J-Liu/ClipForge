#!/bin/bash
#
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright © 2026 Jia Liu
#
# Compile ClipForge.icon to Assets.car for macOS
# Run this locally after updating the icon, then commit the result.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Compiling icon..."

# Create output directory
mkdir -p "$SCRIPT_DIR/Resources/Compiled"

# Compile .icon to Assets.car
xcrun actool "$SCRIPT_DIR/Resources/ClipForge.icon" \
    --compile "$SCRIPT_DIR/Resources/Compiled" \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --app-icon ClipForge \
    --output-partial-info-plist /dev/null

echo "✅ Icon compiled: Resources/Compiled/Assets.car"
echo ""
echo "   Now commit and push:"
echo "     git add Resources/Compiled/Assets.car"
echo "     git commit -m 'Update compiled icon'"
echo "     git push"
#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright © 2026 Jia Liu
#
set -e

APP_NAME="ClipForge"
BUILD_DIR=".build/release"
APP_BUNDLE="build/${APP_NAME}.app"
ICNS="build/ClipForge.icns"

echo "==> Building..."
swift build -c release

# Generate icon if not exists
if [ ! -f "$ICNS" ]; then
    echo "==> Generating icon..."
    chmod +x make_icon.sh
    ./make_icon.sh
fi

echo "==> Packaging .app..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

if [ -f "$ICNS" ]; then
    cp "$ICNS" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi

echo "==> Done: ${APP_BUNDLE}"
echo "Run with: open ${APP_BUNDLE}"

#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright © 2026 Jia Liu
#
set -e

APP_NAME="ClipForge"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
ASSETS_CAR="Resources/Compiled/Assets.car"
ICNS_FILE="Resources/Compiled/ClipForge.icns"

echo "==> Building..."
swift build -c release

echo "==> Packaging .app..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

if [ -f "$ASSETS_CAR" ]; then
    cp "$ASSETS_CAR" "${APP_BUNDLE}/Contents/Resources/"
    echo "    Copied Assets.car"
else
    echo "    Warning: ${ASSETS_CAR} not found"
fi

if [ -f "$ICNS_FILE" ]; then
    cp "$ICNS_FILE" "${APP_BUNDLE}/Contents/Resources/"
    echo "    Copied ClipForge.icns"
else
    echo "    Warning: ${ICNS_FILE} not found"
fi

echo "==> Verifying bundle..."
for f in \
    "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    "${APP_BUNDLE}/Contents/Info.plist" \
    "${APP_BUNDLE}/Contents/Resources/ClipForge.icns" \
    "${APP_BUNDLE}/Contents/Resources/Assets.car"
do
    if [ -f "$f" ]; then
        echo "    ✓ $f"
    else
        echo "    ✗ MISSING: $f"
    fi
done

echo "==> Done: ${APP_BUNDLE}"
echo "Run with: open ${APP_BUNDLE}"

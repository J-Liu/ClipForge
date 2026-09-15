#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright © 2026 Jia Liu
#
set -e

APP_NAME="ClipForge"
BUILD_DIR=".build/release"
APP_BUNDLE="build/${APP_NAME}.app"
ASSETS_CAR="Resources/Compiled/Assets.car"

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
fi

echo "==> Done: ${APP_BUNDLE}"
echo "Run with: open ${APP_BUNDLE}"

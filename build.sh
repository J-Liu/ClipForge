#!/bin/bash
# build.sh
# Builds the ClipForge Swift package and packages it into a proper .app bundle.
# Usage: ./build.sh

set -euo pipefail

APP_NAME="ClipForge"
BUILD_CONFIG="release"

# Resolve project root (script is in root)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# 1. Build the binary
echo "==> Building ${APP_NAME} (${BUILD_CONFIG})..."
swift build -c "$BUILD_CONFIG"

BINARY_PATH="$(swift build -c "$BUILD_CONFIG" --show-bin-path)/${APP_NAME}"
if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: binary not found at ${BINARY_PATH}"
    exit 1
fi

# 2. Assemble .app bundle structure (in root directory)
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
echo "==> Assembling ${APP_BUNDLE}..."

rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "$BINARY_PATH" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist from Resources/
cp "${ROOT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Copy pre-compiled icon assets (committed to git)
ICON_DIR="${ROOT_DIR}/Resources/Compiled"
if [ -f "${ICON_DIR}/Assets.car" ]; then
    cp "${ICON_DIR}/Assets.car" "${APP_BUNDLE}/Contents/Resources/Assets.car"
fi
if [ -f "${ICON_DIR}/${APP_NAME}.icns" ]; then
    cp "${ICON_DIR}/${APP_NAME}.icns" "${APP_BUNDLE}/Contents/Resources/${APP_NAME}.icns"
fi

# Copy Sparkle.framework
SPARKLE_BUILD_DIR="$(swift build -c "$BUILD_CONFIG" --show-bin-path)"
SPARKLE_FRAMEWORK="${SPARKLE_BUILD_DIR}/../../release/Sparkle.framework"
if [ ! -d "$SPARKLE_FRAMEWORK" ]; then
    # Try alternate path
    SPARKLE_FRAMEWORK="${ROOT_DIR}/.build/release/Sparkle.framework"
fi
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    echo "==> Copying Sparkle.framework..."
    mkdir -p "${APP_BUNDLE}/Contents/Frameworks"
    cp -R "$SPARKLE_FRAMEWORK" "${APP_BUNDLE}/Contents/Frameworks/"
fi

# Add rpath for frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# 3. Sign with local certificate (stable identity for TCC)
echo "==> Signing..."
if security find-identity -v -p codesigning | grep -q "Local Development Signing"; then
    codesign --force --deep --sign "Local Development Signing" "$APP_BUNDLE"
    echo "==> Signed ${APP_BUNDLE} using certificate"
else
    # Fallback to ad-hoc signing
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "==> Signed ${APP_BUNDLE} by ad-hoc"
fi
echo ""
echo "==> Done: ${APP_BUNDLE}"
echo "    Run:  open \"${APP_BUNDLE}\""

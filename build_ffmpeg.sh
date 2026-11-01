#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright 2026 Jia Liu

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FFMPEG_KIT_DIR="ffmpeg-kit-next-9.0.0"
VERSION="9.0.0"
TARBALL_URL="https://github.com/arthenica/ffmpeg-kit-next/archive/refs/tags/v${VERSION}.tar.gz"
CACHE_DIR="$SCRIPT_DIR/.cache"

cd "$SCRIPT_DIR"

# Source Nix daemon profile first (may fix PATH)
if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Check Nix installation
if ! command -v nix &> /dev/null; then
    echo "ERROR: Nix not found"
    echo ""
    echo "Nix may need to be reinstalled. Run:"
    echo "  curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh"
    exit 1
fi

# Create cache directory
mkdir -p "$CACHE_DIR"

# Download and extract tarball (reuse if exists)
TARBALL_PATH="$CACHE_DIR/ffmpeg-kit-next-${VERSION}.tar.gz"

if [ ! -d "$FFMPEG_KIT_DIR" ]; then
    if [ ! -f "$TARBALL_PATH" ]; then
        echo "Downloading ffmpeg-kit-next v${VERSION} tarball..."
        curl -L -o "$TARBALL_PATH" "$TARBALL_URL"
    else
        echo "✓ Using cached tarball"
    fi

    echo "Extracting..."
    tar -xzf "$TARBALL_PATH" -C "$CACHE_DIR"
    mv "$CACHE_DIR/ffmpeg-kit-next-${VERSION}" "$FFMPEG_KIT_DIR"
else
    echo "✓ $FFMPEG_KIT_DIR directory exists, skipping download"
fi

cd "$FFMPEG_KIT_DIR"

# Build macOS xcframework
echo ""
echo "Building FFmpeg for macOS..."
echo "Version: ${VERSION}"
echo "Features: VideoToolbox, AudioToolbox, AVFoundation"
echo ""

./nix-macos.sh \
    -p xcode26 \
    -x \
    --enable-lib-macos-videotoolbox \
    --enable-lib-macos-audiotoolbox \
    --enable-lib-macos-avfoundation

# Print output location
PRODUCT_PATH="$SCRIPT_DIR/$FFMPEG_KIT_DIR/prebuilt/bundle-apple-xcframework-macos-10.15"
if [ -d "$PRODUCT_PATH" ]; then
    echo ""
    echo "✅ Build completed successfully!"
    echo "Product path: $PRODUCT_PATH"
    echo ""
    echo "Generated xcrameworks:"
    ls -1 "$PRODUCT_PATH"
    echo ""
    echo "License: LGPL 3.0"
else
    echo ""
    echo "❌ Build failed. Check build.log for details."
    echo "Log: $SCRIPT_DIR/$FFMPEG_KIT_DIR/build.log"
    exit 1
fi

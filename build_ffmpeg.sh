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

echo "=========================================="
echo "FFmpegKit Build Script"
echo "=========================================="
echo "Version: ${VERSION}"
echo "Script dir: ${SCRIPT_DIR}"
echo "Cache dir: ${CACHE_DIR}"
echo "=========================================="
echo ""

# ============================================
# Step 1: Check Nix installation
# ============================================
echo "==> [Step 1/7] Checking Nix installation..."

if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    echo "    Sourcing Nix daemon profile..."
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

if ! command -v nix &> /dev/null; then
    echo "    ❌ ERROR: Nix not found"
    echo ""
    echo "    Nix may need to be reinstalled. Run:"
    echo "      curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh"
    exit 1
fi

echo "    ✅ Nix found: $(nix --version)"
echo ""

# ============================================
# Step 2: Create cache directory
# ============================================
echo "==> [Step 2/7] Creating cache directory..."
mkdir -p "$CACHE_DIR"
echo "    ✅ Done"
echo ""

# ============================================
# Step 3: Download tarball
# ============================================
TARBALL_PATH="$CACHE_DIR/ffmpeg-kit-next-${VERSION}.tar.gz"

if [ -f "$TARBALL_PATH" ]; then
    echo "==> [Step 3/7] Using cached tarball: $TARBALL_PATH"
    echo "    Size: $(ls -lh "$TARBALL_PATH" | awk '{print $5}')"
else
    echo "==> [Step 3/7] Downloading ffmpeg-kit-next v${VERSION}..."
    echo "    URL: $TARBALL_URL"
    curl -L -o "$TARBALL_PATH" "$TARBALL_URL"
    echo "    ✅ Downloaded: $(ls -lh "$TARBALL_PATH" | awk '{print $5}')"
fi
echo ""

# ============================================
# Step 4: Extract tarball
# ============================================
if [ -d "$FFMPEG_KIT_DIR" ] && [ -f "$FFMPEG_KIT_DIR/nix-macos.sh" ]; then
    echo "==> [Step 4/7] Source directory exists and valid, skipping extraction"
else
    echo "==> [Step 4/7] Extracting tarball..."
    rm -rf "$FFMPEG_KIT_DIR"
    tar -xzf "$TARBALL_PATH" -C "$CACHE_DIR"
    mv "$CACHE_DIR/ffmpeg-kit-next-${VERSION}" "$FFMPEG_KIT_DIR"
    echo "    ✅ Extracted to: $FFMPEG_KIT_DIR"
fi
echo ""

# ============================================
# Step 5: Build FFmpegKit
# ============================================
echo "==> [Step 5/7] Building FFmpegKit for macOS..."
echo "    Features: VideoToolbox, AudioToolbox, AVFoundation"
echo "    Build type: xcframework"
echo "    Target SDK: 10.15"
echo ""

cd "$FFMPEG_KIT_DIR"

# Verify we're in the right place
if [ ! -f "nix-macos.sh" ]; then
    echo "    ❌ ERROR: nix-macos.sh not found in $(pwd)"
    echo "    Directory contents:"
    ls -la
    exit 1
fi

BUILD_LOG="$SCRIPT_DIR/$FFMPEG_KIT_DIR/build.log"
# Clear previous log
> "$BUILD_LOG"

echo "    Build log: $BUILD_LOG"
echo ""

# Function to stop background processes
stop_monitors() {
    if [ -n "$INFO_PID" ]; then
        kill $INFO_PID 2>/dev/null || true
    fi
}

# Trap to ensure cleanup on exit
trap stop_monitors EXIT

# Monitor build.log for INFO lines (key milestones)
{
    while IFS= read -r line; do
        if [[ "$line" == INFO:* ]]; then
            # Extract the key info
            info="${line#INFO: }"
            echo "    ▶ $info"
        fi
    done < <(tail -f "$BUILD_LOG" 2>/dev/null)
} &
INFO_PID=$!

# Run the build
echo "    Starting Nix build..."
echo ""

./nix-macos.sh \
    -p xcode26 \
    -x \
    --enable-lib-macos-videotoolbox \
    --enable-lib-macos-audiotoolbox \
    --enable-lib-macos-avfoundation

BUILD_EXIT=$?

# Stop monitors
stop_monitors
trap - EXIT

# ============================================
# Step 6: Verify output
# ============================================
echo ""
echo "==> [Step 6/7] Verifying build output..."

PRODUCT_PATH="$SCRIPT_DIR/$FFMPEG_KIT_DIR/prebuilt/bundle-apple-xcframework-macos-10.15"
if [ -d "$PRODUCT_PATH" ]; then
    echo "    ✅ Product path: $PRODUCT_PATH"
    echo ""
    echo "    Generated xcrameworks:"
    ls -1 "$PRODUCT_PATH"
else
    echo "    ❌ Build output not found at: $PRODUCT_PATH"
    echo "    Check build.log: $BUILD_LOG"
    exit 1
fi
echo ""

# ============================================
# Step 7: Copy to Packages
# ============================================
echo "==> [Step 7/7] Copying xcframeworks to Packages/FFmpegKit/..."
cp -a "$PRODUCT_PATH"/*.xcframework "$SCRIPT_DIR/Packages/FFmpegKit/"
echo "    ✅ Done"
echo ""

echo "=========================================="
echo "✅ FFmpegKit build completed!"
echo "   License: LGPL 3.0"
echo "=========================================="

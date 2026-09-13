#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright © 2026 Jia Liu
#
# Convert icon.svg to icon.icns for macOS.

set -e

SVG="Resources/icon.svg"
ICONSET="build/ClipForge.iconset"
ICNS="build/ClipForge.icns"

if [ ! -f "$SVG" ]; then
    echo "Error: $SVG not found."
    exit 1
fi

if command -v rsvg-convert >/dev/null 2>&1; then
    CONVERT="rsvg"
elif command -v magick >/dev/null 2>&1; then
    CONVERT="magick"
elif command -v convert >/dev/null 2>&1; then
    CONVERT="convert"
else
    echo "Error: no SVG converter found. Install librsvg or ImageMagick:"
    echo "  brew install librsvg"
    exit 1
fi

echo "==> Using $CONVERT"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

render() {
    local size=$1
    local out=$2
    case "$CONVERT" in
        rsvg)    rsvg-convert -w "$size" -h "$size" "$SVG" -o "$out" ;;
        magick)  magick -background none -resize "${size}x${size}" "$SVG" "$out" ;;
        convert) convert -background none -resize "${size}x${size}" "$SVG" "$out" ;;
    esac
}

# Generate all required sizes directly into the iconset.
render 16   "$ICONSET/icon_16x16.png"
render 32   "$ICONSET/icon_16x16@2x.png"
render 32   "$ICONSET/icon_32x32.png"
render 64   "$ICONSET/icon_32x32@2x.png"
render 128  "$ICONSET/icon_128x128.png"
render 256  "$ICONSET/icon_128x128@2x.png"
render 256  "$ICONSET/icon_256x256.png"
render 512  "$ICONSET/icon_256x256@2x.png"
render 512  "$ICONSET/icon_512x512.png"
render 1024 "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"

echo "==> Done: $ICNS"

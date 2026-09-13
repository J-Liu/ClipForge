# ClipForge

A native macOS screen recorder and precise video editor, built with pure AppKit and AVFoundation. No third-party dependencies.

## Features

### Recording
- Full screen, single window, or custom region
- System audio + microphone with adjustable gain
- Configurable frame rate (30 / 60 fps), codec (H.264 / H.265), format (MP4 / MOV)
- 3-second countdown with cancel (click the menu bar icon)
- Menu bar controls during recording
- Configurable output folder

### Editing
- Load multiple videos, append, or drag-and-drop
- Precise cut points with frame-level scrubbing
- Delete segments, non-destructive
- Free-form crop with Esc to reset
- Undo / redo for all editing operations
- Volume control and mute

### Export
- Merge multiple sources into one file
- Resolution presets (Original / 1080p / 720p / 480p)
- Frame rate presets (Original / 30 / 60 fps)
- Format presets (MP4 H.264 / MP4 H.265 / MOV)
- Aspect-ratio preservation with letterbox/pillarbox

## Requirements

- **macOS 13.0 (Ventura) or later**
- Screen recording permission (for recording)
- Microphone permission (optional, for mic audio)

## Installation

1. Download the latest `ClipForge.zip` from the [Releases](https://github.com/J-Liu/PixAI/releases) page.
2. Unzip and drag `ClipForge.app` to `/Applications`.
3. Because the app is not code-signed, macOS Gatekeeper will block it on first launch.

### Bypassing Gatekeeper

**Option A — Terminal (fast):**

```bash
xattr -dr com.apple.quarantine /Applications/ClipForge.app
```

Then double-click the app.

**Option B — Finder (graphical):**

1. Right-click (or Control-click) `ClipForge.app`.
2. Choose **Open**.
3. Click **Open** again in the warning dialog.

After doing this once, the app opens normally.

## Build from Source

```bash
git clone https://github.com/J-Liu/PixAI.git
cd PixAI
./build_app.sh
open build/ClipForge.app
```

Requires Swift 5.7+ and Xcode command line tools.

## Project Home

https://github.com/J-Liu/PixAI

## License

This project is licensed under the GNU Affero General Public License v3.0.
See [LICENSE](LICENSE) for details.

Copyright © 2026 Jia Liu.

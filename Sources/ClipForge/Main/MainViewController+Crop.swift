// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

extension MainViewController {

    func updateOverlayContentRect() {
        guard videoNaturalSize.width > 0 else { return }
        let displayRect = playerView.videoDisplayRect(for: videoNaturalSize)
        cropOverlay.contentRect = displayRect
    }

    func updateCropRect(from selectionRect: NSRect) {
        guard videoNaturalSize.width > 0 else { return }
        let displayRect = cropOverlay.contentRect
        guard displayRect.width > 0, displayRect.height > 0 else { return }

        // Get effective (rotated) video size that matches the display
        let effectiveSize = playerView.effectiveVideoSize(for: videoNaturalSize)

        // Scale from screen coordinates to effective video coordinates
        let scaleX = effectiveSize.width / displayRect.width
        let scaleY = effectiveSize.height / displayRect.height

        let effectiveX = (selectionRect.minX - displayRect.minX) * scaleX
        let effectiveY = (selectionRect.minY - displayRect.minY) * scaleY
        let effectiveW = selectionRect.width * scaleX
        let effectiveH = selectionRect.height * scaleY

        // Map effective coordinates back to original video coordinates
        // based on the rotation
        let absRotation = abs(Int(playerView.rotationDegrees) % 360)
        let cropX: CGFloat, cropY: CGFloat, cropW: CGFloat, cropH: CGFloat

        if absRotation == 90 {
            // 90° clockwise: effective X -> original Y, effective Y -> original (width - X - W)
            cropX = effectiveSize.height - effectiveY - effectiveH
            cropY = effectiveX
            cropW = effectiveH
            cropH = effectiveW
        } else if absRotation == 270 {
            // 270° clockwise (90° counter-clockwise)
            cropX = effectiveY
            cropY = effectiveSize.width - effectiveX - effectiveW
            cropW = effectiveH
            cropH = effectiveW
        } else if absRotation == 180 {
            // 180°: everything is inverted
            cropX = effectiveSize.width - effectiveX - effectiveW
            cropY = effectiveSize.height - effectiveY - effectiveH
            cropW = effectiveW
            cropH = effectiveH
        } else {
            // No rotation
            cropX = effectiveX
            cropY = effectiveY
            cropW = effectiveW
            cropH = effectiveH
        }

        // Ensure even dimensions for video encoding
        let evenW = floor(cropW / 2) * 2
        let evenH = floor(cropH / 2) * 2

        cropRect = NSRect(x: cropX, y: cropY, width: evenW, height: evenH)
    }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

extension MainViewController {

    func updateOverlayContentRect() {
        guard videoNaturalSize.width > 0 else { return }
        let displayRect = playerView.videoDisplayRect(for: videoNaturalSize)
        cropOverlay.contentRect = displayRect

        // If there's an existing original crop, convert it to screen coordinates for display
        if let originalCrop = originalCropRect {
            let effectiveSize = playerView.effectiveVideoSize(for: videoNaturalSize)
            let scaleX = displayRect.width / effectiveSize.width
            let scaleY = displayRect.height / effectiveSize.height

            // Convert original crop to effective coordinates based on current rotation
            let effectiveCrop = originalToEffectiveCrop(originalCrop)

            let screenX = displayRect.minX + effectiveCrop.minX * scaleX
            let screenY = displayRect.minY + effectiveCrop.minY * scaleY
            let screenW = effectiveCrop.width * scaleX
            let screenH = effectiveCrop.height * scaleY

            cropOverlay.setSelectionRect(NSRect(x: screenX, y: screenY, width: screenW, height: screenH))
        } else {
            cropOverlay.resetSelection()
        }
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

        let effectiveRect = NSRect(x: effectiveX, y: effectiveY, width: effectiveW, height: effectiveH)

        // Convert effective to original coordinates and store
        originalCropRect = effectiveToOriginalCrop(effectiveRect)
        Log("updateCropRect: originalCropRect=\(originalCropRect!)")
    }

    /// Convert effective (screen-visible) coordinates to original video coordinates
    private func effectiveToOriginalCrop(_ effective: NSRect) -> NSRect {
        let absRotation = abs(Int(playerView.rotationDegrees) % 360)
        let effectiveSize = playerView.effectiveVideoSize(for: videoNaturalSize)

        let cropX: CGFloat, cropY: CGFloat, cropW: CGFloat, cropH: CGFloat

        if absRotation == 90 {
            // 90° clockwise: effective X -> original Y, effective Y -> original (width - X - W)
            cropX = effectiveSize.height - effective.minY - effective.height
            cropY = effective.minX
            cropW = effective.height
            cropH = effective.width
        } else if absRotation == 270 {
            // 270° clockwise (90° counter-clockwise)
            cropX = effective.minY
            cropY = effectiveSize.width - effective.minX - effective.width
            cropW = effective.height
            cropH = effective.width
        } else if absRotation == 180 {
            // 180°: everything is inverted
            cropX = effectiveSize.width - effective.minX - effective.width
            cropY = effectiveSize.height - effective.minY - effective.height
            cropW = effective.width
            cropH = effective.height
        } else {
            // No rotation
            cropX = effective.minX
            cropY = effective.minY
            cropW = effective.width
            cropH = effective.height
        }

        // Ensure even dimensions for video encoding
        let evenW = floor(cropW / 2) * 2
        let evenH = floor(cropH / 2) * 2

        return NSRect(x: cropX, y: cropY, width: evenW, height: evenH)
    }

    /// Convert original video coordinates to effective (screen-visible) coordinates
    private func originalToEffectiveCrop(_ original: NSRect) -> NSRect {
        let absRotation = abs(Int(playerView.rotationDegrees) % 360)

        let effectiveX: CGFloat, effectiveY: CGFloat, effectiveW: CGFloat, effectiveH: CGFloat

        if absRotation == 90 {
            // 90° clockwise: original Y -> effective X, original X -> effective (height - Y - H)
            effectiveX = original.minY
            effectiveY = videoNaturalSize.width - original.minX - original.width
            effectiveW = original.height
            effectiveH = original.width
        } else if absRotation == 270 {
            // 270° clockwise (90° counter-clockwise)
            effectiveX = videoNaturalSize.height - original.minY - original.height
            effectiveY = original.minX
            effectiveW = original.height
            effectiveH = original.width
        } else if absRotation == 180 {
            // 180°: everything is inverted
            effectiveX = videoNaturalSize.width - original.minX - original.width
            effectiveY = videoNaturalSize.height - original.minY - original.height
            effectiveW = original.width
            effectiveH = original.height
        } else {
            // No rotation
            effectiveX = original.minX
            effectiveY = original.minY
            effectiveW = original.width
            effectiveH = original.height
        }

        return NSRect(x: effectiveX, y: effectiveY, width: effectiveW, height: effectiveH)
    }

    /// Get the crop rect for export (already in original coordinates)
    func originalCropRectForExport() -> NSRect? {
        return originalCropRect
    }
}

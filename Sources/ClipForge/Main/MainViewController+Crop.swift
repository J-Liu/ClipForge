// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

extension MainViewController {

    func updateOverlayContentRect() {
        guard videoNaturalSize.width > 0 else { return }
        let displayRect = playerView.videoDisplayRect(for: videoNaturalSize)
        cropOverlay.contentRect = displayRect

        // If there's an existing crop, transform points and display
        if let points = cropPoints {
            let effectiveSize = playerView.effectiveVideoSize(for: videoNaturalSize)
            let scaleX = displayRect.width / effectiveSize.width
            let scaleY = displayRect.height / effectiveSize.height

            // Transform the 4 points from original to effective coordinates
            let transformedPoints = transformCropPoints(points, rotation: playerView.rotationDegrees)

            // Convert to screen coordinates and get bounding rect
            let screenPoints = transformedPoints.map { point in
                CGPoint(
                    x: displayRect.minX + point.x * scaleX,
                    y: displayRect.minY + point.y * scaleY
                )
            }

            // Get bounding rect from 4 points
            let boundingRect = boundingRect(from: screenPoints)

            cropOverlay.setSelectionRect(boundingRect, silent: true)
        } else {
            cropOverlay.resetSelection()
        }
    }

    func updateCropRect(from selectionRect: NSRect) {
        guard videoNaturalSize.width > 0 else { return }
        let displayRect = cropOverlay.contentRect
        guard displayRect.width > 0, displayRect.height > 0 else { return }

        let effectiveSize = playerView.effectiveVideoSize(for: videoNaturalSize)
        let scaleX = effectiveSize.width / displayRect.width
        let scaleY = effectiveSize.height / displayRect.height

        // Convert screen rect to effective video coordinates
        let effectiveX = (selectionRect.minX - displayRect.minX) * scaleX
        let effectiveY = (selectionRect.minY - displayRect.minY) * scaleY
        let effectiveW = selectionRect.width * scaleX
        let effectiveH = selectionRect.height * scaleY

        // 4 corners in effective coordinates (clockwise from top-left)
        let effectivePoints: [CGPoint] = [
            CGPoint(x: effectiveX, y: effectiveY),                           // top-left
            CGPoint(x: effectiveX + effectiveW, y: effectiveY),               // top-right
            CGPoint(x: effectiveX + effectiveW, y: effectiveY + effectiveH), // bottom-right
            CGPoint(x: effectiveX, y: effectiveY + effectiveH)                // bottom-left
        ]

        // Transform back to original coordinates
        let originalPoints = inverseTransformCropPoints(effectivePoints, rotation: playerView.rotationDegrees)
        cropPoints = originalPoints
    }

    /// Transform 4 crop points from original to effective coordinates based on rotation.
    private func transformCropPoints(_ points: [CGPoint], rotation: CGFloat) -> [CGPoint] {
        let normalized = normalizedRotation(rotation)
        let origW = videoNaturalSize.width
        let origH = videoNaturalSize.height
        let hFlip = playerView.isHorizontallyFlipped
        let vFlip = playerView.isVerticallyFlipped

        return points.map { point in
            transformPoint(point, rotation: normalized, hFlip: hFlip, vFlip: vFlip, origW: origW, origH: origH)
        }
    }

    /// Transform a single point from original to effective coordinates.
    /// Uses center-based coordinate system for simpler rotation math.
    private func transformPoint(_ point: CGPoint, rotation: Int, hFlip: Bool, vFlip: Bool, origW: CGFloat, origH: CGFloat) -> CGPoint {
        guard rotation != 0 || hFlip || vFlip else { return point }

        // Convert to center-based coordinates (origin at center, Y up)
        let centerX = origW / 2
        let centerY = origH / 2
        let x = point.x - centerX
        let y = centerY - point.y  // Flip Y for standard math coordinates

        // Video rotates counter-clockwise by `rotation` degrees.
        // In center-based coordinates, we rotate the point in the OPPOSITE direction.
        // So we use NEGATIVE rotation angle.
        let rotationRadians = -Double(rotation) * .pi / 180
        let cosR = cos(rotationRadians)
        let sinR = sin(rotationRadians)
        let newX = x * cosR - y * sinR
        let newY = x * sinR + y * cosR

        // Convert back to video coordinates (origin at top-left, Y down)
        // Effective dimensions swap for 90°/270° rotations
        let effectiveW = (rotation == 90 || rotation == 270) ? origH : origW
        let effectiveH = (rotation == 90 || rotation == 270) ? origW : origH
        let newCenterX = effectiveW / 2
        let newCenterY = effectiveH / 2

        var effectiveX = newCenterX + newX
        var effectiveY = newCenterY - newY

        // Apply flip transformations
        if hFlip {
            effectiveX = effectiveW - effectiveX
        }
        if vFlip {
            effectiveY = effectiveH - effectiveY
        }

        return CGPoint(x: effectiveX, y: effectiveY)
    }

    /// Transform 4 crop points from effective back to original coordinates.
    private func inverseTransformCropPoints(_ points: [CGPoint], rotation: CGFloat) -> [CGPoint] {
        let normalized = normalizedRotation(rotation)
        let origW = videoNaturalSize.width
        let origH = videoNaturalSize.height
        let hFlip = playerView.isHorizontallyFlipped
        let vFlip = playerView.isVerticallyFlipped

        return points.map { point in
            inverseTransformPoint(point, rotation: normalized, hFlip: hFlip, vFlip: vFlip, origW: origW, origH: origH)
        }
    }

    /// Inverse transform a point from effective to original coordinates.
    /// Uses center-based coordinate system - apply the original rotation (not negated).
    private func inverseTransformPoint(_ point: CGPoint, rotation: Int, hFlip: Bool, vFlip: Bool, origW: CGFloat, origH: CGFloat) -> CGPoint {
        guard rotation != 0 || hFlip || vFlip else { return point }

        // Effective dimensions (swapped for 90°/270°)
        let effectiveW = (rotation == 90 || rotation == 270) ? origH : origW
        let effectiveH = (rotation == 90 || rotation == 270) ? origW : origH

        // First undo flip transformations
        var x = point.x
        var y = point.y
        if hFlip {
            x = effectiveW - x
        }
        if vFlip {
            y = effectiveH - y
        }

        // Convert to center-based coordinates
        let centerX = effectiveW / 2
        let centerY = effectiveH / 2
        let relX = x - centerX
        let relY = centerY - y

        // Forward transform uses -rotation, so inverse uses +rotation
        let rotationRadians = Double(rotation) * .pi / 180
        let cosR = cos(rotationRadians)
        let sinR = sin(rotationRadians)
        let newX = relX * cosR - relY * sinR
        let newY = relX * sinR + relY * cosR

        // Convert back to original video coordinates
        let origCenterX = origW / 2
        let origCenterY = origH / 2
        let origX = origCenterX + newX
        let origY = origCenterY - newY

        return CGPoint(x: origX, y: origY)
    }

    /// Normalize rotation to 0-359 range.
    private func normalizedRotation(_ rotation: CGFloat) -> Int {
        var r = Int(rotation) % 360
        if r < 0 { r += 360 }
        return r
    }

    /// Get bounding rect from 4 points.
    private func boundingRect(from points: [CGPoint]) -> NSRect {
        guard points.count == 4 else { return .zero }

        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 0
        let minY = points.map { $0.y }.min() ?? 0
        let maxY = points.map { $0.y }.max() ?? 0

        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Get the crop rect in original video coordinates for export.
    func cropRectForExport() -> NSRect? {
        guard let points = cropPoints else { return nil }

        // The stored points are already in original coordinates
        let rect = boundingRect(from: points)

        // Ensure even dimensions
        let evenW = floor(rect.width / 2) * 2
        let evenH = floor(rect.height / 2) * 2

        let result = NSRect(x: rect.minX, y: rect.minY, width: evenW, height: evenH)
        Log("cropRectForExport: points=\(points), rect=\(result), rotation=\(playerView.rotationDegrees)")
        return result
    }
}

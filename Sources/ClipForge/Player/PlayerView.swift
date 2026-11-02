// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import AVFoundation
import UniformTypeIdentifiers

class PlayerView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var currentRotation: CGFloat = 0
    private var horizontalFlip: Bool = false
    private var verticalFlip: Bool = false

    /// Called when files are dropped. The Bool is true if the user held ⌘ (replace).
    var onFilesDropped: (([URL], Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)

        registerForDraggedTypes([.fileURL])
    }

    override var isFlipped: Bool { true }

    override var acceptsFirstResponder: Bool { true }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        // Disable implicit animations to avoid layer jitter during window resize.
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Reset transform before setting frame
        playerLayer.transform = CATransform3DIdentity

        let absRotation = abs(Int(currentRotation) % 360)
        if absRotation == 90 || absRotation == 270 {
            // Swap the dimensions for 90°/270°
            let newWidth = bounds.height
            let newHeight = bounds.width
            let offsetX = (bounds.width - newWidth) / 2
            let offsetY = (bounds.height - newHeight) / 2
            playerLayer.frame = CGRect(x: offsetX, y: offsetY, width: newWidth, height: newHeight)
        } else {
            playerLayer.frame = bounds
        }

        // Re-apply rotation transform
        playerLayer.transform = CATransform3DMakeRotation(currentRotation * .pi / 180, 0, 0, 1)

        CATransaction.commit()

        // Notify that layout changed so crop overlay can update
        onLayoutChanged?()
    }

    /// Called when the view's layout changes (window resize, etc.)
    var onLayoutChanged: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    func attach(player: AVPlayer) {
        playerLayer.player = player
    }

    /// Rotate video 90 degrees clockwise.
    func rotateClockwise() {
        currentRotation -= 90
        applyRotation()
    }

    /// Rotate video 90 degrees counter-clockwise.
    func rotateCounterClockwise() {
        currentRotation += 90
        applyRotation()
    }

    /// Reset rotation to 0.
    func resetRotation() {
        currentRotation = 0
        applyRotation()
    }

    /// Toggle horizontal flip (mirror left-right).
    func flipHorizontal() {
        horizontalFlip.toggle()
        applyRotation()
    }

    /// Toggle vertical flip (mirror up-down).
    func flipVertical() {
        verticalFlip.toggle()
        applyRotation()
    }

    /// Reset all transforms to default.
    func resetTransforms() {
        currentRotation = 0
        horizontalFlip = false
        verticalFlip = false
        applyRotation()
    }

    /// Current flip state for export.
    var isHorizontallyFlipped: Bool { horizontalFlip }
    var isVerticallyFlipped: Bool { verticalFlip }

    private func applyRotation() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // First reset the transform so we can set frame correctly
        playerLayer.transform = CATransform3DIdentity

        // For 90° and 270° rotations, we need to adjust the layer's frame
        // to properly display the rotated content
        let absRotation = abs(Int(currentRotation) % 360)

        if absRotation == 90 || absRotation == 270 {
            // Swap the dimensions for 90°/270°
            let newWidth = bounds.height
            let newHeight = bounds.width
            let offsetX = (bounds.width - newWidth) / 2
            let offsetY = (bounds.height - newHeight) / 2
            playerLayer.frame = CGRect(x: offsetX, y: offsetY, width: newWidth, height: newHeight)
        } else {
            playerLayer.frame = bounds
        }

        // Build the transform: rotation first, then flip
        var transform = CATransform3DMakeRotation(currentRotation * .pi / 180, 0, 0, 1)

        // Apply horizontal flip (scale X by -1)
        if horizontalFlip {
            transform = CATransform3DScale(transform, -1, 1, 1)
        }

        // Apply vertical flip (scale Y by -1)
        if verticalFlip {
            transform = CATransform3DScale(transform, 1, -1, 1)
        }

        playerLayer.transform = transform

        CATransaction.commit()
    }

    /// Current rotation angle in degrees (0, 90, 180, 270, -90, -180, -270).
    var rotationDegrees: CGFloat {
        return currentRotation
    }

    /// The effective video size after rotation (dimensions may swap).
    func effectiveVideoSize(for naturalSize: CGSize) -> CGSize {
        let absRotation = abs(Int(currentRotation) % 360)
        if absRotation == 90 || absRotation == 270 {
            // Dimensions swap for 90° and 270° rotations
            return CGSize(width: naturalSize.height, height: naturalSize.width)
        }
        return naturalSize
    }

    /// The rect where the video is actually rendered (accounting for aspect fit).
    /// For rotated videos, this returns the rect for the effective (rotated) dimensions.
    func videoDisplayRect(for videoSize: CGSize) -> NSRect {
        guard videoSize.width > 0, videoSize.height > 0 else { return bounds }

        // Use effective size for rotated videos
        let effectiveSize = effectiveVideoSize(for: videoSize)

        let viewAspect = bounds.width / bounds.height
        let videoAspect = effectiveSize.width / effectiveSize.height

        var rect = bounds
        if videoAspect > viewAspect {
            // Video is wider — pillarbox (letterbox on sides).
            let height = bounds.width / videoAspect
            rect = NSRect(x: 0, y: (bounds.height - height) / 2,
                          width: bounds.width, height: height)
        } else {
            // Video is taller — letterbox (bars top/bottom).
            let width = bounds.height * videoAspect
            rect = NSRect(x: (bounds.width - width) / 2, y: 0,
                          width: width, height: bounds.height)
        }
        return rect
    }

    private func mediaURLs(from sender: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [
                UTType.movie.identifier,
                UTType.video.identifier,
                UTType.mp3.identifier,
                UTType.wav.identifier,
                UTType.mpeg4Audio.identifier,
                UTType.audio.identifier
            ]
        ]
        guard let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [URL] else {
            return []
        }
        return urls
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = mediaURLs(from: sender)
        return urls.isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = mediaURLs(from: sender)
        guard !urls.isEmpty else { return false }
        let replace = NSEvent.modifierFlags.contains(.command)
        onFilesDropped?(urls, replace)
        return true
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Update the drop indicator based on the current modifier.
        if NSEvent.modifierFlags.contains(.command) {
            return .generic   // replace indicator
        }
        return .copy          // append indicator
    }
}

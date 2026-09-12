import AppKit
import AVFoundation

class PlayerView: NSView {
    private let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
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
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    func attach(player: AVPlayer) {
        playerLayer.player = player
    }

    /// The rect where the video is actually rendered (accounting for aspect fit).
    func videoDisplayRect(for videoSize: CGSize) -> NSRect {
        guard videoSize.width > 0, videoSize.height > 0 else { return bounds }

        let viewAspect = bounds.width / bounds.height
        let videoAspect = videoSize.width / videoSize.height

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
}

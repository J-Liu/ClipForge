import AppKit
import CoreMedia

/// A horizontal bar overlaid on the timeline, showing segments as colored blocks.
/// Kept segments are green; removed segments are gray with a strikethrough.
class SegmentBarView: NSView {
    var segments: [Segment] = [] {
        didSet { needsDisplay = true }
    }

    var totalDuration: CMTime = .zero {
        didSet { needsDisplay = true }
    }

    /// Called when the user clicks a segment. Passes the segment index.
    var onSegmentClicked: ((Int) -> Void)?

    private let keptColor = NSColor.systemGreen.withAlphaComponent(0.55)
    private let removedColor = NSColor.systemGray.withAlphaComponent(0.45)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard totalDuration.isValid, CMTimeGetSeconds(totalDuration) > 0 else { return }

        let total = CMTimeGetSeconds(totalDuration)
        let w = bounds.width
        let h = bounds.height

        for segment in segments {
            let s = CMTimeGetSeconds(segment.start) / total * w
            let e = CMTimeGetSeconds(segment.end) / total * w
            let rect = NSRect(x: s, y: 0, width: max(1, e - s), height: h)

            let color = segment.isKept ? keptColor : removedColor
            color.setFill()
            rect.fill()

            // Border between segments.
            NSColor.controlBackgroundColor.setStroke()
            let border = NSBezierPath()
            border.move(to: NSPoint(x: e, y: 0))
            border.line(to: NSPoint(x: e, y: h))
            border.lineWidth = 1
            border.stroke()

            // Strikethrough for removed segments.
            if !segment.isKept {
                NSColor.systemRed.setStroke()
                let line = NSBezierPath()
                line.move(to: NSPoint(x: rect.minX + 2, y: rect.midY))
                line.line(to: NSPoint(x: rect.maxX - 2, y: rect.midY))
                line.lineWidth = 1
                line.stroke()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard !segments.isEmpty else { return }
        let point = convert(event.locationInWindow, from: nil)
        let total = CMTimeGetSeconds(totalDuration)
        guard total > 0 else { return }

        let clickTime = Double(point.x / bounds.width) * total

        // Find the segment containing the click, or the nearest one.
        var bestIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for (index, segment) in segments.enumerated() {
            let s = CMTimeGetSeconds(segment.start)
            let e = CMTimeGetSeconds(segment.end)
            if clickTime >= s && clickTime < e {
                bestIndex = index
                bestDistance = 0
                break
            }
            let mid = (s + e) / 2
            let distance = abs(clickTime - mid)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }

        onSegmentClicked?(bestIndex)
    }
}

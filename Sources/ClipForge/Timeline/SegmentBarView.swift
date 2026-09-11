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

    /// Cut point times, sorted. Used for hit-testing and dragging.
    var cutPoints: [CMTime] = [] {
        didSet { needsDisplay = true }
    }

    /// Called continuously while dragging a cut point.
    var onCutPointDragged: ((Int, CMTime) -> Void)?
    /// Called when a cut point drag ends.
    var onCutPointDragEnded: ((Int, CMTime) -> Void)?
    /// Called when a cut point is double-clicked for deletion.
    var onCutPointDeleted: ((Int) -> Void)?

    private var draggingCutIndex: Int?
    private var dragStartTime: CMTime = .zero

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

        // Draw cut point handles on top of the segment colors.
        for cut in cutPoints {
            let x = CMTimeGetSeconds(cut) / total * w
            let handleRect = NSRect(x: x - 3, y: 0, width: 6, height: h)
            NSColor.labelColor.setFill()
            handleRect.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let total = CMTimeGetSeconds(totalDuration)
        guard total > 0 else { return }

        // Check if a cut point handle was hit first.
        if let hitIndex = hitTestCutPoint(at: point) {
            if event.clickCount == 2 {
                onCutPointDeleted?(hitIndex)
                return
            }
            draggingCutIndex = hitIndex
            return
        }

        // Otherwise fall back to segment selection.
        guard !segments.isEmpty else { return }
        let clickTime = Double(point.x / bounds.width) * total

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

    override func mouseDragged(with event: NSEvent) {
        guard let index = draggingCutIndex else { return }
        let point = convert(event.locationInWindow, from: nil)
        let total = CMTimeGetSeconds(totalDuration)
        guard total > 0 else { return }

        let x = max(0, min(point.x, bounds.width))
        let t = Double(x / bounds.width) * total

        // Clamp between neighboring cut points (or timeline bounds).
        let lower = index > 0 ? CMTimeGetSeconds(cutPoints[index - 1]) : 0
        let upper = index < cutPoints.count - 1 ? CMTimeGetSeconds(cutPoints[index + 1]) : total
        let clamped = max(lower + 0.001, min(t, upper - 0.001))

        let newTime = CMTime(seconds: clamped, preferredTimescale: 600)
        onCutPointDragged?(index, newTime)
    }

    override func mouseUp(with event: NSEvent) {
        guard let index = draggingCutIndex else { return }
        draggingCutIndex = nil
        let point = convert(event.locationInWindow, from: nil)
        let total = CMTimeGetSeconds(totalDuration)
        guard total > 0 else { return }

        let x = max(0, min(point.x, bounds.width))
        let t = Double(x / bounds.width) * total
        let lower = index > 0 ? CMTimeGetSeconds(cutPoints[index - 1]) : 0
        let upper = index < cutPoints.count - 1 ? CMTimeGetSeconds(cutPoints[index + 1]) : total
        let clamped = max(lower + 0.001, min(t, upper - 0.001))

        let newTime = CMTime(seconds: clamped, preferredTimescale: 600)
        onCutPointDragEnded?(index, newTime)
    }

    private func hitTestCutPoint(at point: NSPoint) -> Int? {
        let total = CMTimeGetSeconds(totalDuration)
        guard total > 0 else { return nil }
        let w = bounds.width

        for (index, cut) in cutPoints.enumerated() {
            let x = CMTimeGetSeconds(cut) / total * w
            if abs(point.x - x) <= 6 {
                return index
            }
        }
        return nil
    }
}

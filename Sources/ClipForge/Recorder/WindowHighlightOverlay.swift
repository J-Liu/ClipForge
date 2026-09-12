import AppKit
import ScreenCaptureKit

/// A border-only window that follows a target window's frame on screen.
class WindowHighlightOverlay {
    private var window: NSWindow?
    private var updateTimer: Timer?
    private var targetWindowID: CGWindowID?

    /// The window being highlighted, in screen coordinates.
    private var targetFrame: NSRect = .zero

    /// Show the highlight around the given screen-space rect.
    func show(windowID: CGWindowID, initialFrame: NSRect) {
        targetWindowID = windowID
        targetFrame = initialFrame
        if window == nil {
            createWindow()
        }
        updateFrame()
        startTracking()
    }

    func hide() {
        updateTimer?.invalidate()
        updateTimer = nil
        window?.orderOut(nil)
        window = nil
    }

    /// Update the target frame; call this when the target window moves.
    func updateTargetFrame(_ rect: NSRect) {
        targetFrame = rect
        updateFrame()
    }

    private func createWindow() {
        let w = NSWindow(
            contentRect: targetFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .floating
        w.ignoresMouseEvents = true
        w.sharingType = .none   // Exclude from screen capture.
        w.hasShadow = false
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let content = HighlightContentView(frame: NSRect(origin: .zero, size: targetFrame.size))
        content.autoresizingMask = [.width, .height]
        w.contentView = content

        w.orderFront(nil)
        window = w
    }

    private func updateFrame() {
        guard let window else { return }
        let inflated = targetFrame.insetBy(dx: -3, dy: -3)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.05
            window.animator().setFrame(inflated, display: true)
        }
    }

    private func startTracking() {
        updateTimer?.invalidate()
        let t = Timer(timeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self, let id = self.targetWindowID else { return }
            if let rect = Self.currentFrame(for: id) {
                self.targetFrame = rect
                self.updateFrame()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        updateTimer = t
    }

    /// Query the current screen-space frame of a window via CGWindowList.
    static func currentFrame(for windowID: CGWindowID) -> NSRect? {
        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for info in infoList {
            guard let id = info[kCGWindowNumber as String] as? CGWindowID,
                  id == windowID,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat] else {
                continue
            }
            let x = boundsDict["X"] ?? 0
            let y = boundsDict["Y"] ?? 0
            let w = boundsDict["Width"] ?? 0
            let h = boundsDict["Height"] ?? 0

            guard let mainScreen = NSScreen.screens.first else { return nil }
            let screenHeight = mainScreen.frame.height
            return NSRect(
                x: x,
                y: screenHeight - y - h,
                width: w,
                height: h
            )
        }
        return nil
    }
}

/// Draws a colored border inside the overlay window.
private class HighlightContentView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: bounds.insetBy(dx: 1.5, dy: 1.5))
        path.lineWidth = 3
        NSColor.systemBlue.setStroke()
        path.stroke()
    }
}

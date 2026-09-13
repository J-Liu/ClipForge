// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import ScreenCaptureKit

/// A full-screen overlay that lets the user pick a window to record.
/// Shows a highlight border around the window under the cursor,
/// and calls `onPick` when the user clicks.
class WindowPickerOverlay {

    /// Called on the main thread when a window is picked.
    var onPick: ((SCWindow) -> Void)?
    /// Called when the user cancels (Escape).
    var onCancel: (() -> Void)?

    private var windows: [NSWindow] = []   // one per screen
    private var targetWindows: [SCWindow] = []
    private var cursorWindow: SCWindow?

    /// Build the overlay covering all screens and start tracking.
    func present(targetWindows: [SCWindow]) {
        self.targetWindows = targetWindows
        cursorWindow = nil

        for screen in NSScreen.screens {
            let win = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            win.isOpaque = false
            win.backgroundColor = .clear
            win.level = .screenSaver
            win.sharingType = .none
            win.hasShadow = false
            win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            win.acceptsMouseMovedEvents = true
            win.ignoresMouseEvents = false

            let view = PickerContentView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.overlay = self
            win.contentView = view

            win.orderFront(nil)
            windows.append(win)
        }

        // Make sure we get key events for Escape.
        windows.first?.makeKey()
    }

    func dismiss() {
        for win in windows {
            win.orderOut(nil)
        }
        windows.removeAll()
        targetWindows.removeAll()
        cursorWindow = nil
    }

    /// Called by the content view when the mouse moves.
    func handleMouseMoved(at screenPoint: NSPoint) {
        // Find the SCWindow containing this point.
        let hit = targetWindows.first { scWindow in
            let rect = Self.appKitRect(from: scWindow.frame)
            return rect.contains(screenPoint)
        }
        if hit?.windowID != cursorWindow?.windowID {
            cursorWindow = hit
            redrawAll()
        }
    }

    /// Called by the content view when the user clicks.
    func handleClick(at screenPoint: NSPoint) {
        guard let hit = cursorWindow else { return }
        dismiss()
        onPick?(hit)
    }

    func handleEscape() {
        dismiss()
        onCancel?()
    }

    /// Returns the SCWindow the cursor is currently over, if any.
    func currentCursorWindow() -> SCWindow? {
        return cursorWindow
    }

    private func redrawAll() {
        for win in windows {
            win.contentView?.needsDisplay = true
        }
    }

    /// Convert an SCWindow frame (top-left origin) to AppKit screen coords.
    static func appKitRect(from scFrame: CGRect) -> NSRect {
        guard let mainScreen = NSScreen.screens.first else { return .zero }
        let screenHeight = mainScreen.frame.height
        return NSRect(
            x: scFrame.origin.x,
            y: screenHeight - scFrame.origin.y - scFrame.height,
            width: scFrame.width,
            height: scFrame.height
        )
    }
}

/// The view inside each overlay window. Draws the highlight and forwards events.
private class PickerContentView: NSView {
    weak var overlay: WindowPickerOverlay?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let overlay else { return }

        // Dim the entire screen.
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()

        // Draw a highlight around the window under the cursor.
        if let cursor = overlay.currentCursorWindow() {
            let screenRect = WindowPickerOverlay.appKitRect(from: cursor.frame)
            // Convert from screen coordinates to this view's coordinates.
            let localRect = convertFromScreen(screenRect)

            NSColor.clear.setFill()
            localRect.fill(using: .copy)

            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: localRect.insetBy(dx: 1.5, dy: 1.5))
            path.lineWidth = 3
            path.stroke()
        }
    }

    private func convertFromScreen(_ screenRect: NSRect) -> NSRect {
        guard let window = self.window else { return screenRect }
        // screenRect is in screen coords (global). Convert to window coords.
        let windowRect = window.convertFromScreen(screenRect)
        // Then to view coords.
        return convert(windowRect, from: nil)
    }

    override func mouseMoved(with event: NSEvent) {
        overlay?.handleMouseMoved(at: NSEvent.mouseLocation)
    }

    override func mouseDown(with event: NSEvent) {
        overlay?.handleClick(at: NSEvent.mouseLocation)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {   // Escape
            overlay?.handleEscape()
        } else {
            super.keyDown(with: event)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
}

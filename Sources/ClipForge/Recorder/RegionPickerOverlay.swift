// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import ScreenCaptureKit

/// A full-screen overlay that lets the user drag out a rectangular region.
class RegionPickerOverlay {

    /// Called on the main thread with the selected region in AppKit screen coords.
    var onPick: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var windows: [NSWindow] = []

    func present() {
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

            let view = RegionPickerContentView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.overlay = self
            win.contentView = view
            win.orderFront(nil)
            windows.append(win)
        }
        windows.first?.makeKey()
    }

    func dismiss() {
        for win in windows { win.orderOut(nil) }
        windows.removeAll()
    }

    func handleSelection(_ screenRect: NSRect) {
        dismiss()
        onPick?(screenRect)
    }

    func handleCancel() {
        dismiss()
        onCancel?()
    }
}

/// The view inside each overlay window. Draws the dim layer and the drag rectangle.
private class RegionPickerContentView: NSView {
    weak var overlay: RegionPickerOverlay?

    private var dragStart: NSPoint?
    private var dragCurrent: NSPoint?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Dim.
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        // Draw the drag rectangle.
        if let start = dragStart, let current = dragCurrent {
            let rect = NSRect(
                x: min(start.x, current.x),
                y: min(start.y, current.y),
                width: abs(current.x - start.x),
                height: abs(current.y - start.y)
            )

            // Clear the selection area.
            NSColor.clear.setFill()
            rect.fill(using: .copy)

            // Border.
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(rect: rect.insetBy(dx: 1.5, dy: 1.5))
            path.lineWidth = 3
            path.stroke()

            // Size label.
            let sizeText = "\(Int(rect.width)) × \(Int(rect.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let size = sizeText.size(withAttributes: attrs)
            let labelRect = NSRect(
                x: rect.midX - size.width / 2 - 6,
                y: rect.minY - size.height - 12,
                width: size.width + 12,
                height: size.height + 6
            )
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4).fill()
            sizeText.draw(
                at: NSPoint(x: labelRect.minX + 6, y: labelRect.minY + 3),
                withAttributes: attrs
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStart = point
        dragCurrent = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        dragCurrent = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart, let current = dragCurrent else { return }
        let localRect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        dragStart = nil
        dragCurrent = nil

        // Ignore tiny selections.
        guard localRect.width > 20, localRect.height > 20 else {
            needsDisplay = true
            return
        }

        // Convert to screen coordinates.
        guard let window = self.window else { return }
        let windowRect = convert(localRect, to: nil)
        let screenRect = window.convertToScreen(windowRect)
        overlay?.handleSelection(screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {   // Escape
            overlay?.handleCancel()
        } else {
            super.keyDown(with: event)
        }
    }
}

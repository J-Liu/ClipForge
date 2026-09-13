// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// A transparent overlay with a draggable, resizable selection rectangle.
/// The area outside the selection is dimmed.
///
/// Coordinate system: AppKit default (origin at bottom-left, y grows up).
/// The view's `contentRect` defines the visible video frame; the selection
/// is always clamped inside it.
class CropOverlayView: NSView {

    /// The selection rectangle in this view's coordinate space.
    private(set) var selectionRect: NSRect = .zero

    /// The area the selection is allowed to occupy (the visible video frame).
    var contentRect: NSRect = .zero {
        didSet {
            if !hasInitializedSelection, !contentRect.isEmpty {
                selectionRect = contentRect
                hasInitializedSelection = true
                needsDisplay = true
                onSelectionChanged?(selectionRect)
            }
        }
    }

    /// Called whenever the selection changes.
    var onSelectionChanged: ((NSRect) -> Void)?

    /// Reset selection to the full content area (e.g. when a new video loads).
    func resetSelection() {
        hasInitializedSelection = false
        if !contentRect.isEmpty {
            selectionRect = contentRect
            hasInitializedSelection = true
            needsDisplay = true
            onSelectionChanged?(selectionRect)
        }
    }

    // MARK: - Private state

    private var hasInitializedSelection = false

    private let dimColor = NSColor.black.withAlphaComponent(0.55)
    private let borderColor = NSColor.systemBlue
    private let handleSize: CGFloat = 10
    private let minSize: CGFloat = 40

    private enum DragMode {
        case none
        case move
        case topLeft, topRight, bottomLeft, bottomRight
    }
    private var dragMode: DragMode = .none
    private var dragStartPoint: NSPoint = .zero
    private var dragStartRect: NSRect = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !selectionRect.isEmpty else { return }

        // Dim everything, then clear the selection area.
        dimColor.setFill()
        bounds.fill()

        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)

        // Border.
        borderColor.setStroke()
        let border = NSBezierPath(rect: selectionRect)
        border.lineWidth = 1.5
        border.stroke()

        // Corner handles.
        for corner in cornerPoints() {
            let handleRect = NSRect(
                x: corner.x - handleSize / 2,
                y: corner.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            NSColor.white.setFill()
            handleRect.fill()
            borderColor.setStroke()
            let path = NSBezierPath(rect: handleRect)
            path.lineWidth = 1
            path.stroke()
        }
    }

    override var isFlipped: Bool { true }

    private func cornerPoints() -> [NSPoint] {
        [
            NSPoint(x: selectionRect.minX, y: selectionRect.minY),
            NSPoint(x: selectionRect.maxX, y: selectionRect.minY),
            NSPoint(x: selectionRect.minX, y: selectionRect.maxY),
            NSPoint(x: selectionRect.maxX, y: selectionRect.maxY)
        ]
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragStartPoint = point
        dragStartRect = selectionRect
        dragMode = hitTestMode(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragMode != .none, !contentRect.isEmpty else { return }

        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - dragStartPoint.x
        let dy = point.y - dragStartPoint.y

        // Compute the new rect from the drag baseline.
        var newRect = dragStartRect
        switch dragMode {
        case .none:
            return
        case .move:
            newRect.origin.x += dx
            newRect.origin.y += dy
        case .topLeft:      // visual top-left
            newRect.origin.x += dx
            newRect.origin.y += dy
            newRect.size.width -= dx
            newRect.size.height -= dy
        case .topRight:     // visual top-right
            newRect.origin.y += dy
            newRect.size.width += dx
            newRect.size.height -= dy
        case .bottomLeft:   // visual bottom-left
            newRect.origin.x += dx
            newRect.size.width -= dx
            newRect.size.height += dy
        case .bottomRight:  // visual bottom-right
            newRect.size.width += dx
            newRect.size.height += dy
        }

        // Enforce minimum size before clamping.
        if newRect.width < minSize {
            if dragMode == .topLeft || dragMode == .bottomLeft {
                newRect.origin.x = newRect.maxX - minSize
            }
            newRect.size.width = minSize
        }
        if newRect.height < minSize {
            if dragMode == .topLeft || dragMode == .topRight {
                newRect.origin.y = newRect.maxY - minSize
            }
            newRect.size.height = minSize
        }

        // Clamp horizontally without touching vertical.
        if newRect.minX < contentRect.minX {
            let overshoot = contentRect.minX - newRect.minX
            newRect.origin.x = contentRect.minX
            newRect.size.width -= overshoot
        }
        if newRect.maxX > contentRect.maxX {
            let overshoot = newRect.maxX - contentRect.maxX
            newRect.size.width -= overshoot
        }

        // Clamp vertically without touching horizontal.
        if newRect.minY < contentRect.minY {
            let overshoot = contentRect.minY - newRect.minY
            newRect.origin.y = contentRect.minY
            newRect.size.height -= overshoot
        }
        if newRect.maxY > contentRect.maxY {
            let overshoot = newRect.maxY - contentRect.maxY
            newRect.size.height -= overshoot
        }

        // Final min-size guard (rare, only if clamping squeezed us).
        if newRect.width < minSize {
            newRect.size.width = minSize
            if newRect.maxX > contentRect.maxX {
                newRect.origin.x = contentRect.maxX - minSize
            }
        }
        if newRect.height < minSize {
            newRect.size.height = minSize
            if newRect.maxY > contentRect.maxY {
                newRect.origin.y = contentRect.maxY - minSize
            }
        }

        selectionRect = newRect
        needsDisplay = true
        onSelectionChanged?(selectionRect)
    }

    override func mouseUp(with event: NSEvent) {
        dragMode = .none
    }

    private func hitTestMode(at point: NSPoint) -> DragMode {
        let tolerance: CGFloat = handleSize
            let r = selectionRect

            // In a flipped coordinate system (isFlipped = true), minY is the visual top.
            let corners: [(NSPoint, DragMode)] = [
                (NSPoint(x: r.minX, y: r.minY), .topLeft),      // visual top-left
                (NSPoint(x: r.maxX, y: r.minY), .topRight),     // visual top-right
                (NSPoint(x: r.minX, y: r.maxY), .bottomLeft),   // visual bottom-left
                (NSPoint(x: r.maxX, y: r.maxY), .bottomRight)   // visual bottom-right
            ]
            for (corner, mode) in corners {
                if abs(point.x - corner.x) <= tolerance && abs(point.y - corner.y) <= tolerance {
                    return mode
                }
            }
            if selectionRect.contains(point) {
                return .move
            }
            return .none
    }
}

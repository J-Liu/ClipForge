// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Custom slider where knob center aligns with track bounds.
class CustomSlider: NSControl {
    var value: Double = 0.0 {
        didSet {
            needsDisplay = true
        }
    }

    var minValue: Double = 0.0
    var maxValue: Double = 1.0

    private let knobWidth: CGFloat = 14.0
    private let trackHeight: CGFloat = 4.0
    private let knobColor = NSColor.controlAccentColor
    private let trackColor = NSColor.separatorColor
    private let activeTrackColor = NSColor.controlAccentColor.withAlphaComponent(0.3)

    var onValueChanged: ((Double) -> Void)?
    var onDragBegin: (() -> Void)?
    var onDragEnd: (() -> Void)?

    private var isDragging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: knobWidth)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let trackY = bounds.midY - trackHeight / 2
        let trackRect = NSRect(x: 0, y: trackY, width: bounds.width, height: trackHeight)

        // Draw track
        trackColor.setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: trackHeight / 2, yRadius: trackHeight / 2).fill()

        // Draw active track (before knob)
        let progress = CGFloat((value - minValue) / (maxValue - minValue))
        let knobCenterX = progress * bounds.width
        if progress > 0 {
            let activeRect = NSRect(x: 0, y: trackY, width: knobCenterX, height: trackHeight)
            activeTrackColor.setFill()
            NSBezierPath(roundedRect: activeRect, xRadius: trackHeight / 2, yRadius: trackHeight / 2).fill()
        }

        // Draw knob (circle)
        let knobRect = NSRect(
            x: knobCenterX - knobWidth / 2,
            y: bounds.midY - knobWidth / 2,
            width: knobWidth,
            height: knobWidth
        )
        knobColor.setFill()
        NSBezierPath(ovalIn: knobRect).fill()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        onDragBegin?()
        updateValue(from: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateValue(from: event)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        onDragEnd?()
    }

    private func updateValue(from event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let progress = Double(point.x / bounds.width)
        let clamped = max(0, min(1, progress))
        value = minValue + clamped * (maxValue - minValue)
        onValueChanged?(value)
    }
}

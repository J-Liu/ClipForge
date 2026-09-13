// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import CoreMedia

/// A compact input row for precise time entry: HH : MM : SS . mmm
class TimeInputView: NSView {
    private let hoursField = NSTextField(string: "00")
    private let minutesField = NSTextField(string: "00")
    private let secondsField = NSTextField(string: "00")
    private let millisField = NSTextField(string: "000")

    private let colon1 = NSTextField(labelWithString: ":")
    private let colon2 = NSTextField(labelWithString: ":")
    private let dot = NSTextField(labelWithString: ".")

    private let goButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "scope",
                                        accessibilityDescription: "Go to time")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()

    /// Called when the user commits a time value.
    var onSeek: ((CMTime) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        let fields = [hoursField, minutesField, secondsField, millisField]
        for field in fields {
            field.translatesAutoresizingMaskIntoConstraints = false
            field.alignment = .center
            field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            field.target = self
            field.action = #selector(commit)
        }

        // Widths: HH and MM are 2 digits, SS is 2 digits, mmm is 3 digits.
        hoursField.widthAnchor.constraint(equalToConstant: 32).isActive = true
        minutesField.widthAnchor.constraint(equalToConstant: 32).isActive = true
        secondsField.widthAnchor.constraint(equalToConstant: 32).isActive = true
        millisField.widthAnchor.constraint(equalToConstant: 42).isActive = true

        for label in [colon1, colon2, dot] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            label.textColor = .secondaryLabelColor
        }

        goButton.translatesAutoresizingMaskIntoConstraints = false
        goButton.target = self
        goButton.action = #selector(commit)
        goButton.bezelStyle = .rounded
        goButton.toolTip = "Seek to the entered time"

        let stack = NSStackView(views: [
            hoursField, colon1,
            minutesField, colon2,
            secondsField, dot,
            millisField, goButton
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.alignment = .centerY

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    /// Update the fields from a CMTime, without triggering a seek.
    func setTime(_ time: CMTime) {
        guard time.isValid, !time.isIndefinite else { return }
        let total = CMTimeGetSeconds(time)
        guard total.isFinite, total >= 0 else { return }

        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        let s = Int(total) % 60
        let ms = Int((total - floor(total)) * 1000)

        hoursField.stringValue = String(format: "%02d", h)
        minutesField.stringValue = String(format: "%02d", m)
        secondsField.stringValue = String(format: "%02d", s)
        millisField.stringValue = String(format: "%03d", ms)
    }

    @objc private func commit() {
        let h = Double(hoursField.intValue)
        let m = Double(minutesField.intValue)
        let s = Double(secondsField.intValue)
        let ms = Double(millisField.intValue)

        let total = h * 3600 + m * 60 + s + ms / 1000.0
        let time = CMTime(seconds: total, preferredTimescale: 600)
        onSeek?(time)
        window?.selectNextKeyView(nil)
    }
}

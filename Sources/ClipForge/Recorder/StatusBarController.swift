// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Manages the menu bar icon and its state during recording.
class StatusBarController {

    enum State {
        case idle
        case countdown(Int)     // 3, 2, 1
        case recording
        case paused
    }

    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var countdownTimer: Timer?
    private var elapsed: TimeInterval = 0

    /// Called when the user clicks cancel during countdown.
    var onCancel: (() -> Void)?
    /// Called when the user clicks stop during recording or paused.
    var onStop: (() -> Void)?
    /// Called when the user toggles pause.
    var onTogglePause: (() -> Void)?

    private(set) var state: State = .idle

    // MARK: - Public

    func show() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item
        if let button = item.button {
            button.target = self
            button.action = #selector(handleButtonClick)
        }
        updateDisplay()
    }

    @objc private func handleButtonClick() {
        switch state {
        case .idle:
            break
        case .countdown:
            onCancel?()
        case .recording:
            onStop?()
        case .paused:
            onStop?()
        }
    }

    func hide() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        stopTimers()
    }

    func setState(_ newState: State) {
        state = newState
        switch newState {
        case .idle:
            stopTimer()
            countdownTimer?.invalidate()
            countdownTimer = nil
            elapsed = 0
        case .countdown:
            // Don't touch countdownTimer — it's managed by startCountdown.
            stopTimer()
        case .recording:
            startTimer()
        case .paused:
            stopTimer()
        }
        updateDisplay()
    }

    // MARK: - Display

    private func updateDisplay() {
        guard let button = statusItem?.button else { return }
        button.image = nil
        button.title = ""

        switch state {
        case .idle:
            button.image = NSImage(systemSymbolName: "record.circle",
                                   accessibilityDescription: "Record")
        case .countdown(let seconds):
            button.title = "\(seconds)"
        case .recording:
            button.title = " \(formattedTime())"
            button.image = NSImage(systemSymbolName: "stop.circle.fill",
                                   accessibilityDescription: "Stop")
        case .paused:
            button.title = " \(formattedTime())"
            button.image = NSImage(systemSymbolName: "play.circle.fill",
                                   accessibilityDescription: "Resume")
        }
    }

    // MARK: - Timers

    private func startTimer() {
        stopTimer()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsed += 1
            self.updateDisplay()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func stopTimers() {
        stopTimer()
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Start a 3-second countdown, firing onCountdownTick each second.
    func startCountdown(onTick: @escaping (Int) -> Void, onFinish: @escaping () -> Void) {
        let seconds = Settings.shared.countdownSeconds
        if seconds <= 0 {
            onFinish()
            return
        }
        var remaining = seconds
        setState(.countdown(remaining))
        onTick(remaining)

        let t = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { return }
            remaining -= 1
            if remaining <= 0 {
                timer.invalidate()
                self.countdownTimer = nil
                onFinish()
            } else {
                self.setState(.countdown(remaining))
                onTick(remaining)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        countdownTimer = t
    }

    private func formattedTime() -> String {
        let total = Int(elapsed)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Actions

    @objc private func handleCancel() {
        onCancel?()
    }

    @objc private func handleStop() {
        onStop?()
    }

    @objc private func handleTogglePause() {
        onTogglePause?()
    }
}

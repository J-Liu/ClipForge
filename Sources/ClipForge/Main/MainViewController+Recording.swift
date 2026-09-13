import AppKit
import ScreenCaptureKit

extension MainViewController {

    @objc func startRecording() {
        recordButton.isEnabled = false
        statusBar.startCountdown(onTick: { _ in }, onFinish: { [weak self] in
            self?.beginActualRecording()
        })
    }

    func beginActualRecording() {
        recorder.startRecording { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(title: "Recording Failed", message: error.localizedDescription)
                self.statusBar.setState(.idle)
                self.recordButton.isEnabled = true
                return
            }
            self.statusBar.setState(.recording)
            if self.dontHideCheckbox.state == .off {
                self.view.window?.orderOut(nil)
            }
        }
    }

    func cancelRecordingCountdown() {
        statusBar.setState(.idle)
        recordButton.isEnabled = true
    }

    func togglePauseRecording() {
        switch statusBar.state {
        case .recording:
            statusBar.setState(.paused)
        case .paused:
            statusBar.setState(.recording)
        default:
            break
        }
    }

    @objc func stopRecording() {
        recorder.stopRecording { [weak self] url in
            DispatchQueue.main.async {
                guard let self else { return }
                self.statusBar.setState(.idle)
                self.recordButton.isEnabled = true
                self.view.window?.makeKeyAndOrderFront(nil)
                if let url = url {
                    self.showAlert(title: "Recording Saved", message: url.path)
                } else {
                    self.showAlert(title: "Recording Failed", message: "No file was written.")
                }
            }
        }
    }

    @objc func startWindowRecording() {
        Task {
            guard let content = try? await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            ) else { return }

            let myBundleID = Bundle.main.bundleIdentifier
            let candidates = content.windows.filter {
                $0.isOnScreen &&
                $0.frame.width > 100 &&
                $0.frame.height > 100 &&
                $0.owningApplication?.bundleIdentifier != myBundleID &&
                $0.owningApplication?.bundleIdentifier != "com.apple.dock" &&
                $0.owningApplication?.bundleIdentifier != "com.apple.finder" &&
                $0.windowLayer == 0
            }

            await MainActor.run {
                self.windowPicker.onPick = { [weak self] window in
                    self?.beginWindowRecordingAfterCountdown(window: window)
                }
                self.windowPicker.onCancel = { }
                self.windowPicker.present(targetWindows: candidates)
            }
        }
    }

    func beginWindowRecordingAfterCountdown(window: SCWindow) {
        recordButton.isEnabled = false
        statusBar.startCountdown(onTick: { _ in }, onFinish: { [weak self] in
            self?.beginWindowRecording(window: window)
        })
    }

    func beginWindowRecording(window: SCWindow) {
        recorder.startWindowRecording(window: window) { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(title: "Recording Failed", message: error.localizedDescription)
                self.statusBar.setState(.idle)
                self.recordButton.isEnabled = true
                return
            }
            self.statusBar.setState(.recording)
            if self.dontHideCheckbox.state == .off {
                self.view.window?.orderOut(nil)
            }
        }
    }

    @objc func startRegionRecording() {
        regionPicker.onPick = { [weak self] screenRect in
            self?.beginRegionRecordingAfterCountdown(region: screenRect)
        }
        regionPicker.onCancel = { }
        regionPicker.present()
    }

    func beginRegionRecordingAfterCountdown(region: NSRect) {
        recordButton.isEnabled = false
        statusBar.startCountdown(onTick: { _ in }, onFinish: { [weak self] in
            self?.beginRegionRecording(region: region)
        })
    }

    func beginRegionRecording(region: NSRect) {
        recorder.startRegionRecording(region: region) { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(title: "Recording Failed", message: error.localizedDescription)
                self.statusBar.setState(.idle)
                self.recordButton.isEnabled = true
                return
            }
            self.statusBar.setState(.recording)
            if self.dontHideCheckbox.state == .off {
                self.view.window?.orderOut(nil)
            }
        }
    }

    func rebuildRecordModeMenu() {
        recordModeMenu.removeAllItems()

        let style = Settings.shared.recordingButtonStyle
        let modes: [(RecordingMode, String, String)] = [
            (.fullScreen, "Full Screen", "rectangle.inset.filled"),
            (.window, "Window", "macwindow"),
            (.region, "Region", "rectangle.dashed")
        ]

        for (mode, title, iconName) in modes {
            let action: Selector
            if style == .directAction {
                action = #selector(startRecordingWithMode(_:))
            } else {
                action = #selector(selectRecordingMode(_:))
            }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            if style == .modePicker && Settings.shared.recordingMode == mode {
                item.state = .on
            }
            recordModeMenu.addItem(item)
        }
    }

    @objc func startRecordingWithMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = RecordingMode(rawValue: raw) else { return }
        Settings.shared.recordingMode = mode
        updateRecordButtonIcon()
        recordButtonPressed()
    }

    func updateRecordButtonIcon() {
        let name: String
        switch Settings.shared.recordingMode {
        case .fullScreen: name = "rectangle.inset.filled"
        case .window:     name = "macwindow"
        case .region:     name = "rectangle.dashed"
        }
        recordButton.image = NSImage(systemSymbolName: name, accessibilityDescription: "Record")
    }

    @objc func showRecordModeMenu() {
        rebuildRecordModeMenu()
        let point = NSPoint(x: 0, y: recordButton.bounds.height)
        recordModeMenu.popUp(positioning: nil, at: point, in: recordButton)
    }

    @objc func recordButtonPressed() {
        switch Settings.shared.recordingMode {
        case .fullScreen:
            startRecording()
        case .window:
            startWindowRecording()
        case .region:
            startRegionRecording()
        }
    }

    @objc func selectRecordingMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = RecordingMode(rawValue: raw) else { return }
        setRecordingMode(mode)
    }
}


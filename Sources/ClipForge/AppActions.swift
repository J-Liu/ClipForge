// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Receives menu actions and forwards them to the active MainViewController.
class AppActions {
    static let shared = AppActions()

    private var mainViewController: MainViewController? {
        if let vc = NSApp.keyWindow?.contentViewController as? MainViewController {
            return vc
        }
        for window in NSApp.windows {
            if let vc = window.contentViewController as? MainViewController {
                return vc
            }
        }
        return nil
    }

    @objc func openFile() { mainViewController?.openFileAction() }
    @objc func appendVideo() { mainViewController?.appendVideoAction() }
    @objc func exportVideo() { mainViewController?.exportVideoAction() }
    @objc func togglePlay() { mainViewController?.togglePlayAction() }

    @objc func setModeFullScreen() { mainViewController?.setRecordingMode(.fullScreen) }
    @objc func setModeWindow() { mainViewController?.setRecordingMode(.window) }
    @objc func setModeRegion() { mainViewController?.setRecordingMode(.region) }
    @objc func startRecording() { mainViewController?.recordButtonPressedAction() }

    @objc func backOneFrame() { mainViewController?.stepFrames(-1) }
    @objc func forwardOneFrame() { mainViewController?.stepFrames(1) }
    @objc func backFiveSeconds() { mainViewController?.seek(bySeconds: -5) }
    @objc func forwardFiveSeconds() { mainViewController?.seek(bySeconds: 5) }

    @objc func openSettings() {
        SettingsWindowController.shared.present()
    }

    @objc func bringMainWindowFront() {
        for window in NSApp.windows where window.contentViewController is MainViewController {
            window.makeKeyAndOrderFront(nil)
            break
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func checkForUpdates() {
        if let url = URL(string: "https://github.com/J-Liu/PixAI/releases") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func newWindow() {
        for window in NSApp.windows where window.contentViewController is MainViewController {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // No existing window — create one.
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.showMainWindow()
        }
    }

    @objc func toggleMute() { mainViewController?.toggleMuteAction() }
    @objc func increaseVolume() { mainViewController?.adjustVolume(by: 0.1) }
    @objc func decreaseVolume() { mainViewController?.adjustVolume(by: -0.1) }

    @objc func showAbout() {
        let credits = NSMutableAttributedString(
            string: "https://github.com/J-Liu/PixAI",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .link: "https://github.com/J-Liu/PixAI"
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits
        ])
    }
}

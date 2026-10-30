// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Manages the standalone Settings window.
class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()
    private var settingsWindow: SettingsWindow?

    convenience init() {
        self.init(window: nil)
    }

    func present() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
        }
        self.window = settingsWindow
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Show the About tab when opening from menu.
    func showAboutTab() {
        present()
        settingsWindow?.selectTab(withIdentifier: "about")
    }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Manages the standalone Settings window.
class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()
    private let tabViewController = SettingsTabViewController()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("menu.app.settings").replacingOccurrences(of: "…", with: "")
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
    }

    func present() {
        contentViewController = tabViewController
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: .languageChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.window?.title = L("menu.app.settings").replacingOccurrences(of: "…", with: "")
        }
    }
}
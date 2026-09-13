// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import SwiftUI

/// Manages the standalone Settings window.
class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

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

        let hosting = NSHostingView(rootView: SettingsView())
        window.contentView = hosting

        self.init(window: window)
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

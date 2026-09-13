// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

extension Notification.Name {
    static let mainWindowClosed = Notification.Name("ClipForge.mainWindowClosed")
}

class MainWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipForge"
        window.center()
        window.contentViewController = MainViewController()
        self.init(window: window)
        window.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: .mainWindowClosed, object: nil)
    }
}

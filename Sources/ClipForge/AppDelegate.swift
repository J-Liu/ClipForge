import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        showMainWindow()

        NotificationCenter.default.addObserver(
            forName: .mainWindowClosed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.windowController = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        Settings.shared.quitAfterLastWindowClosed
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    private func showMainWindow() {
        if windowController == nil {
            let wc = MainWindowController()
            windowController = wc
        }
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBuilder.build()
        showMainWindow()

        NotificationCenter.default.addObserver(
            forName: .mainWindowClosed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.windowController = nil
        }

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Space key = keyCode 49.
            guard event.keyCode == 49 else { return event }
            // Let text fields handle it.
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSTextView {
                return event
            }
            AppActions.shared.togglePlay()
            return nil   // consume the event
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        Settings.shared.quitAfterLastWindowClosed
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func showMainWindow() {
        if windowController == nil {
            let wc = MainWindowController()
            windowController = wc
        }
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

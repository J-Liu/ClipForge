import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let wc = MainWindowController()
        wc.showWindow(nil)
        windowController = wc
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}


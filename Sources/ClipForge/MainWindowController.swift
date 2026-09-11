import AppKit

class MainWindowController: NSWindowController {
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
    }
}

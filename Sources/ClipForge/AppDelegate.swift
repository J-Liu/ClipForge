// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBuilder.build()
        installKeyMonitor()
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

    func showMainWindow() {
        if windowController == nil {
            let wc = MainWindowController()
            windowController = wc
        }
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func installKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore when a modifier (except shift) is held.
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command) || flags.contains(.option) || flags.contains(.control) {
                return event
            }

            // Let text fields handle everything.
            if let responder = NSApp.keyWindow?.firstResponder,
               responder is NSTextView {
                return event
            }

            if event.keyCode == 49 {
                if let responder = NSApp.keyWindow?.firstResponder,
                   responder is NSButton {
                    return event   // let the button handle it
                }
                AppActions.shared.togglePlay()
                return nil
            }

            // Escape: reset crop selection, unless a text field or overlay is active.
            if event.keyCode == 53 {
                // If a picker overlay is on screen, let it handle Escape.
                let hasOverlay = NSApp.windows.contains {
                    $0.level == .screenSaver && $0.isVisible
                }
                if hasOverlay { return event }

                // Let text fields handle it.
                if let responder = NSApp.keyWindow?.firstResponder,
                   responder is NSTextView {
                    return event
                }

                if let vc = NSApp.keyWindow?.contentViewController as? MainViewController {
                    vc.resetCropSelection()
                    return nil
                }
                return event
            }

            // Map the key to an action.
            switch event.keyCode {
            case 123:   // left arrow
                AppActions.shared.backOneFrame(); return nil
            case 124:   // right arrow
                AppActions.shared.forwardOneFrame(); return nil
            case 125:   // down arrow
                AppActions.shared.backFiveSeconds(); return nil
            case 126:   // up arrow
                AppActions.shared.forwardFiveSeconds(); return nil
            default:
                break
            }

            // Letter keys.
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return event
            }
            switch chars {
            case "a", "h":
                AppActions.shared.backOneFrame(); return nil
            case "d", "l":
                AppActions.shared.forwardOneFrame(); return nil
            case "s", "k":
                AppActions.shared.backFiveSeconds(); return nil
            case "w", "j":
                AppActions.shared.forwardFiveSeconds(); return nil
            default:
                return event
            }
        }
    }
}

import AppKit

/// Builds the app's main menu programmatically.
class MenuBuilder {

    static func build() {
        let mainMenu = NSMenu()

        mainMenu.addItem(makeAppMenu())
        mainMenu.addItem(makeFileMenu())
        mainMenu.addItem(makeEditMenu())
        mainMenu.addItem(makePlaybackMenu())
        mainMenu.addItem(makeRecordMenu())
        mainMenu.addItem(makeWindowMenu())

        NSApp.mainMenu = mainMenu
    }

    // MARK: - App Menu

    private static func makeAppMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu()
        let appName = "ClipForge"

        menu.addItem(withTitle: "About \(appName)",
                     action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                     keyEquivalent: "")

        let updates = NSMenuItem(title: "Check for Updates…",
                                 action: #selector(AppActions.checkForUpdates),
                                 keyEquivalent: "")
        updates.target = AppActions.shared
        menu.addItem(updates)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…",
                                  action: #selector(AppActions.openSettings),
                                  keyEquivalent: ",")
        settings.target = AppActions.shared
        menu.addItem(settings)

        menu.addItem(.separator())

        menu.addItem(withTitle: "Hide \(appName)",
                     action: #selector(NSApplication.hide(_:)),
                     keyEquivalent: "h")

        let hideOthers = NSMenuItem(title: "Hide Others",
                                    action: #selector(NSApplication.hideOtherApplications(_:)),
                                    keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)

        menu.addItem(withTitle: "Show All",
                     action: #selector(NSApplication.unhideAllApplications(_:)),
                     keyEquivalent: "")

        menu.addItem(.separator())

        menu.addItem(withTitle: "Quit \(appName)",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")

        item.submenu = menu
        return item
    }

    // MARK: - File Menu

    private static func makeFileMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "File")

        let newWindow = NSMenuItem(title: "New Window",
                                   action: #selector(AppActions.newWindow),
                                   keyEquivalent: "n")
        newWindow.target = AppActions.shared
        menu.addItem(newWindow)

        menu.addItem(.separator())

        let open = NSMenuItem(title: "Open…",
                              action: #selector(AppActions.openFile),
                              keyEquivalent: "o")
        open.target = AppActions.shared
        menu.addItem(open)

        let append = NSMenuItem(title: "Append Video…",
                                action: #selector(AppActions.appendVideo),
                                keyEquivalent: "o")
        append.keyEquivalentModifierMask = [.command, .shift]
        append.target = AppActions.shared
        menu.addItem(append)

        let export = NSMenuItem(title: "Export…",
                                action: #selector(AppActions.exportVideo),
                                keyEquivalent: "e")
        export.target = AppActions.shared
        menu.addItem(export)

        menu.addItem(.separator())

        menu.addItem(withTitle: "Close",
                     action: #selector(NSWindow.performClose(_:)),
                     keyEquivalent: "w")

        item.submenu = menu
        return item
    }

    // MARK: - Edit Menu

    private static func makeEditMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Edit")

        menu.addItem(withTitle: "Undo",
                     action: Selector(("undo:")),
                     keyEquivalent: "z")

        let redo = NSMenuItem(title: "Redo",
                              action: Selector(("redo:")),
                              keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)

        menu.addItem(.separator())

        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        item.submenu = menu
        return item
    }

    // MARK: - Playback Menu

    private static func makePlaybackMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Playback")

        let play = NSMenuItem(title: "Play/Pause",
                              action: #selector(AppActions.togglePlay),
                              keyEquivalent: " ")
        play.keyEquivalentModifierMask = []
        play.target = AppActions.shared
        menu.addItem(play)

        menu.addItem(.separator())

        addPlaybackItem(to: menu, title: "Back 1 Frame",
                        action: #selector(AppActions.backOneFrame),
                        key: "\u{F702}")   // left arrow
        addPlaybackItem(to: menu, title: "Forward 1 Frame",
                        action: #selector(AppActions.forwardOneFrame),
                        key: "\u{F703}")   // right arrow
        addPlaybackItem(to: menu, title: "Back 5 Seconds",
                        action: #selector(AppActions.backFiveSeconds),
                        key: "\u{F701}")   // down arrow
        addPlaybackItem(to: menu, title: "Forward 5 Seconds",
                        action: #selector(AppActions.forwardFiveSeconds),
                        key: "\u{F700}")   // up arrow

        item.submenu = menu
        return item
    }

    private static func addPlaybackItem(to menu: NSMenu, title: String, action: Selector, key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = []
        item.target = AppActions.shared
        menu.addItem(item)
    }

    // MARK: - Record Menu

    private static func makeRecordMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Record")

        let fullScreen = NSMenuItem(title: "Full Screen",
                                    action: #selector(AppActions.setModeFullScreen),
                                    keyEquivalent: "")
        fullScreen.target = AppActions.shared
        menu.addItem(fullScreen)

        let window = NSMenuItem(title: "Window",
                                action: #selector(AppActions.setModeWindow),
                                keyEquivalent: "")
        window.target = AppActions.shared
        menu.addItem(window)

        let region = NSMenuItem(title: "Region",
                                action: #selector(AppActions.setModeRegion),
                                keyEquivalent: "")
        region.target = AppActions.shared
        menu.addItem(region)

        menu.addItem(.separator())

        let start = NSMenuItem(title: "Start Recording",
                               action: #selector(AppActions.startRecording),
                               keyEquivalent: "r")
        start.target = AppActions.shared
        menu.addItem(start)

        item.submenu = menu
        return item
    }

    // MARK: - Window Menu

    private static func makeWindowMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Window")

        menu.addItem(withTitle: "Minimize",
                     action: #selector(NSWindow.performMiniaturize(_:)),
                     keyEquivalent: "m")

        menu.addItem(withTitle: "Zoom",
                     action: #selector(NSWindow.performZoom(_:)),
                     keyEquivalent: "")

        menu.addItem(.separator())

        let bringFront = NSMenuItem(title: "ClipForge",
                                    action: #selector(AppActions.bringMainWindowFront),
                                    keyEquivalent: "0")
        bringFront.target = AppActions.shared
        menu.addItem(bringFront)

        NSApp.windowsMenu = menu
        item.submenu = menu
        return item
    }
}

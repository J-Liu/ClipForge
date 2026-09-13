// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Builds the app's main menu programmatically.
class MenuBuilder {

    static func build() {
        rebuild()
        NotificationCenter.default.addObserver(
            forName: .languageChanged,
            object: nil,
            queue: .main
        ) { _ in
            rebuild()
        }
    }

    private static func rebuild() {
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

        let about = NSMenuItem(title: L("menu.app.about", appName),
                               action: #selector(AppActions.showAbout),
                               keyEquivalent: "")
        about.target = AppActions.shared
        menu.addItem(about)

        let updates = NSMenuItem(title: L("menu.app.checkForUpdates"),
                                 action: #selector(AppActions.checkForUpdates),
                                 keyEquivalent: "")
        updates.target = AppActions.shared
        menu.addItem(updates)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: L("menu.app.settings"),
                                  action: #selector(AppActions.openSettings),
                                  keyEquivalent: ",")
        settings.target = AppActions.shared
        menu.addItem(settings)

        menu.addItem(.separator())

        menu.addItem(withTitle: L("menu.app.hide", appName),
                     action: #selector(NSApplication.hide(_:)),
                     keyEquivalent: "h")

        let hideOthers = NSMenuItem(title: L("menu.app.hideOthers"),
                                    action: #selector(NSApplication.hideOtherApplications(_:)),
                                    keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)

        menu.addItem(withTitle: L("menu.app.showAll"),
                     action: #selector(NSApplication.unhideAllApplications(_:)),
                     keyEquivalent: "")

        menu.addItem(.separator())

        menu.addItem(withTitle: L("menu.app.quit", appName),
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")

        item.submenu = menu
        return item
    }

    // MARK: - File Menu

    private static func makeFileMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: L("menu.file"))

        let newWindow = NSMenuItem(title: L("menu.file.newWindow"),
                                   action: #selector(AppActions.newWindow),
                                   keyEquivalent: "n")
        newWindow.target = AppActions.shared
        menu.addItem(newWindow)

        menu.addItem(.separator())

        let open = NSMenuItem(title: L("menu.file.open"),
                              action: #selector(AppActions.openFile),
                              keyEquivalent: "o")
        open.target = AppActions.shared
        menu.addItem(open)

        let append = NSMenuItem(title: L("menu.file.appendVideo"),
                                action: #selector(AppActions.appendVideo),
                                keyEquivalent: "o")
        append.keyEquivalentModifierMask = [.command, .shift]
        append.target = AppActions.shared
        menu.addItem(append)

        let export = NSMenuItem(title: L("menu.file.export"),
                                action: #selector(AppActions.exportVideo),
                                keyEquivalent: "e")
        export.target = AppActions.shared
        menu.addItem(export)

        menu.addItem(.separator())

        menu.addItem(withTitle: L("menu.file.close"),
                     action: #selector(NSWindow.performClose(_:)),
                     keyEquivalent: "w")

        item.submenu = menu
        return item
    }

    // MARK: - Edit Menu

    private static func makeEditMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: L("menu.edit"))

        menu.addItem(withTitle: L("menu.edit.undo"),
                     action: Selector(("undo:")),
                     keyEquivalent: "z")

        let redo = NSMenuItem(title: L("menu.edit.redo"),
                              action: Selector(("redo:")),
                              keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)

        menu.addItem(.separator())

        menu.addItem(withTitle: L("menu.edit.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: L("menu.edit.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: L("menu.edit.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: L("menu.edit.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        item.submenu = menu
        return item
    }

    // MARK: - Playback Menu

    private static func makePlaybackMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: L("menu.playback"))

        let play = NSMenuItem(title: L("menu.playback.playPause"),
                              action: #selector(AppActions.togglePlay),
                              keyEquivalent: " ")
        play.keyEquivalentModifierMask = []
        play.target = AppActions.shared
        menu.addItem(play)

        menu.addItem(.separator())

        let mute = NSMenuItem(title: L("menu.playback.mute"),
                              action: #selector(AppActions.toggleMute),
                              keyEquivalent: "m")
        mute.keyEquivalentModifierMask = [.command, .shift]
        mute.target = AppActions.shared
        menu.addItem(mute)

        let volUp = NSMenuItem(title: L("menu.playback.volumeUp"),
                               action: #selector(AppActions.increaseVolume),
                               keyEquivalent: "\u{F700}")   // up arrow
        volUp.keyEquivalentModifierMask = [.command]
        volUp.target = AppActions.shared
        menu.addItem(volUp)

        let volDown = NSMenuItem(title: L("menu.playback.volumeDown"),
                                 action: #selector(AppActions.decreaseVolume),
                                 keyEquivalent: "\u{F701}")   // down arrow
        volDown.keyEquivalentModifierMask = [.command]
        volDown.target = AppActions.shared
        menu.addItem(volDown)

        menu.addItem(.separator())

        addPlaybackItem(to: menu, title: L("menu.playback.back1Frame"),
                        action: #selector(AppActions.backOneFrame),
                        key: "\u{F702}")   // left arrow
        addPlaybackItem(to: menu, title: L("menu.playback.forward1Frame"),
                        action: #selector(AppActions.forwardOneFrame),
                        key: "\u{F703}")   // right arrow
        addPlaybackItem(to: menu, title: L("menu.playback.back5Seconds"),
                        action: #selector(AppActions.backFiveSeconds),
                        key: "\u{F701}")   // down arrow
        addPlaybackItem(to: menu, title: L("menu.playback.forward5Seconds"),
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
        let menu = NSMenu(title: L("menu.record"))

        let fullScreen = NSMenuItem(title: L("menu.record.fullScreen"),
                                    action: #selector(AppActions.setModeFullScreen),
                                    keyEquivalent: "1")
        fullScreen.keyEquivalentModifierMask = [.control]
        fullScreen.target = AppActions.shared
        menu.addItem(fullScreen)

        let window = NSMenuItem(title: L("menu.record.window"),
                                action: #selector(AppActions.setModeWindow),
                                keyEquivalent: "2")
        window.keyEquivalentModifierMask = [.control]
        window.target = AppActions.shared
        menu.addItem(window)

        let region = NSMenuItem(title: L("menu.record.region"),
                                action: #selector(AppActions.setModeRegion),
                                keyEquivalent: "3")
        region.keyEquivalentModifierMask = [.control]
        region.target = AppActions.shared
        menu.addItem(region)

        menu.addItem(.separator())

        let start = NSMenuItem(title: L("menu.record.start"),
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
        let menu = NSMenu(title: L("menu.window"))

        menu.addItem(withTitle: L("menu.window.minimize"),
                     action: #selector(NSWindow.performMiniaturize(_:)),
                     keyEquivalent: "m")

        menu.addItem(withTitle: L("menu.window.zoom"),
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

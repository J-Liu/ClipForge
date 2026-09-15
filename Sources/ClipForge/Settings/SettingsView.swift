// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class SettingsTabViewController: NSTabViewController {

    private let generalVC = GeneralSettingsViewController()
    private let recordingVC = RecordingSettingsViewController()
    private let editingVC = EditingSettingsViewController()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let generalTab = NSTabViewItem(identifier: "general")
        generalTab.viewController = generalVC
        generalTab.label = L("settings.tab.general")
        generalTab.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        addTabViewItem(generalTab)

        let recordingTab = NSTabViewItem(identifier: "recording")
        recordingTab.viewController = recordingVC
        recordingTab.label = L("settings.tab.recording")
        recordingTab.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: nil)
        addTabViewItem(recordingTab)

        let editingTab = NSTabViewItem(identifier: "editing")
        editingTab.viewController = editingVC
        editingTab.label = L("settings.tab.editing")
        editingTab.image = NSImage(systemSymbolName: "scissors", accessibilityDescription: nil)
        addTabViewItem(editingTab)

        tabStyle = .toolbar

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: .languageChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func languageChanged() {
        tabViewItems[0].label = L("settings.tab.general")
        tabViewItems[1].label = L("settings.tab.recording")
        tabViewItems[2].label = L("settings.tab.editing")
    }
}

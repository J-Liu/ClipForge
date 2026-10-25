// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class GeneralSettingsViewController: NSViewController {

    private let languagePopup = NSPopUpButton()
    private let languageLabel = NSTextField(labelWithString: "")
    private let quitCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dontHideCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let countdownPopup = NSPopUpButton()
    private let countdownLabel = NSTextField(labelWithString: "")
    private let updateFrequencyPopup = NSPopUpButton()
    private let updateFrequencyLabel = NSTextField(labelWithString: "")
    private let checkUpdateButton = NSButton()
    private let recentFileCountField = NSTextField()
    private let recentFileCountLabel = NSTextField(labelWithString: "")
    private let logEnabledCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let logPathField = NSTextField()
    private let logPathLabel = NSTextField(labelWithString: "")
    private let revealLogButton = NSButton()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 550))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateLocalizedStrings()
        loadSettings()

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

    private func setupUI() {
        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 20
        stackView.alignment = .leading
        stackView.distribution = .fill

        // Language section
        let languageSection = createSectionView()
        languagePopup.target = self
        languagePopup.action = #selector(languagePopupChanged)
        languageSection.addArrangedSubview(createRowView(label: languageLabel, control: languagePopup))
        stackView.addArrangedSubview(languageSection)

        // Quit checkbox section
        let quitSection = createSectionView()
        quitCheckbox.target = self
        quitCheckbox.action = #selector(quitCheckboxChanged)
        quitSection.addArrangedSubview(quitCheckbox)
        stackView.addArrangedSubview(quitSection)

        // Don't hide section
        let dontHideSection = createSectionView()
        dontHideCheckbox.target = self
        dontHideCheckbox.action = #selector(dontHideCheckboxChanged)
        dontHideSection.addArrangedSubview(dontHideCheckbox)
        stackView.addArrangedSubview(dontHideSection)

        // Countdown section
        let countdownSection = createSectionView()
        countdownPopup.target = self
        countdownPopup.action = #selector(countdownPopupChanged)
        countdownSection.addArrangedSubview(createRowView(label: countdownLabel, control: countdownPopup))
        stackView.addArrangedSubview(countdownSection)

        // Update frequency section
        let updateSection = createSectionView()
        updateFrequencyPopup.target = self
        updateFrequencyPopup.action = #selector(updateFrequencyPopupChanged)
        updateSection.addArrangedSubview(createRowView(label: updateFrequencyLabel, control: updateFrequencyPopup))

        checkUpdateButton.bezelStyle = .rounded
        checkUpdateButton.target = self
        checkUpdateButton.action = #selector(checkForUpdates)
        updateSection.addArrangedSubview(checkUpdateButton)

        stackView.addArrangedSubview(updateSection)

        // Recent file count section
        let recentSection = createSectionView()
        recentFileCountField.isBezeled = true
        recentFileCountField.drawsBackground = true
        recentFileCountField.isEditable = true
        recentFileCountField.isSelectable = true
        recentFileCountField.bezelStyle = .roundedBezel
        recentFileCountField.delegate = self
        recentFileCountField.placeholderString = "20"
        recentFileCountField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            recentFileCountField.widthAnchor.constraint(equalToConstant: 60)
        ])
        let recentRow = createRowView(label: recentFileCountLabel, control: recentFileCountField)
        recentSection.addArrangedSubview(recentRow)
        stackView.addArrangedSubview(recentSection)

        // Log section
        let logSection = createSectionView()
        logEnabledCheckbox.target = self
        logEnabledCheckbox.action = #selector(logEnabledCheckboxChanged)
        logSection.addArrangedSubview(logEnabledCheckbox)

        // Log path row
        logPathField.isBezeled = false
        logPathField.drawsBackground = true
        logPathField.isEditable = false
        logPathField.isSelectable = true
        logPathField.bezelStyle = .roundedBezel
        logPathField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logPathField.widthAnchor.constraint(equalToConstant: 350)
        ])

        revealLogButton.bezelStyle = .rounded
        revealLogButton.target = self
        revealLogButton.action = #selector(revealLogFile)
        revealLogButton.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)

        let logPathRow = createRowView(label: logPathLabel, control: logPathField, trailingButton: revealLogButton)
        logSection.addArrangedSubview(logPathRow)
        stackView.addArrangedSubview(logSection)

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
    }

    private func updateLocalizedStrings() {
        // Save current language selection
        let currentLang = LocalizationManager.shared.currentLanguage

        // Update labels
        languageLabel.stringValue = L("settings.general.language")
        countdownLabel.stringValue = L("settings.general.countdown")
        updateFrequencyLabel.stringValue = L("settings.general.updateFrequency")
        checkUpdateButton.title = L("settings.general.checkForUpdates")
        recentFileCountLabel.stringValue = L("settings.general.recentFileCount")
        logPathLabel.stringValue = L("settings.general.logPath")
        revealLogButton.title = ""
        quitCheckbox.title = L("settings.general.quitAfterLastWindow")
        dontHideCheckbox.title = L("settings.general.dontHideWindow")
        logEnabledCheckbox.title = L("settings.general.enableLog")

        languagePopup.removeAllItems()
        for lang in Language.allCases {
            languagePopup.addItem(withTitle: lang.nativeName)
            languagePopup.lastItem?.representedObject = lang
            // Select the current language
            if lang == currentLang {
                languagePopup.select(languagePopup.lastItem)
            }
        }

        // Save current countdown selection
        let currentCountdownValue = countdownPopup.selectedItem?.representedObject as? Int ?? UserDefaults.standard.integer(forKey: "countdownSeconds")

        countdownPopup.removeAllItems()
        countdownPopup.addItem(withTitle: L("settings.general.countdown.none"))
        countdownPopup.lastItem?.representedObject = 0
        if currentCountdownValue == 0 {
            countdownPopup.select(countdownPopup.lastItem)
        }
        countdownPopup.addItem(withTitle: L("settings.general.countdown.3seconds"))
        countdownPopup.lastItem?.representedObject = 3
        if currentCountdownValue == 3 {
            countdownPopup.select(countdownPopup.lastItem)
        }
        countdownPopup.addItem(withTitle: L("settings.general.countdown.5seconds"))
        countdownPopup.lastItem?.representedObject = 5
        if currentCountdownValue == 5 {
            countdownPopup.select(countdownPopup.lastItem)
        }

        // Update frequency
        let currentFrequency = Settings.shared.updateCheckFrequency
        updateFrequencyPopup.removeAllItems()
        for freq in UpdateCheckFrequency.allCases {
            updateFrequencyPopup.addItem(withTitle: L("settings.general.updateFrequency.\(freq.rawValue)"))
            updateFrequencyPopup.lastItem?.representedObject = freq
            if freq == currentFrequency {
                updateFrequencyPopup.select(updateFrequencyPopup.lastItem)
            }
        }
    }

    private func loadSettings() {
        // Language
        let currentLang = LocalizationManager.shared.currentLanguage
        for item in languagePopup.menu?.items ?? [] {
            if let lang = item.representedObject as? Language, lang == currentLang {
                languagePopup.select(item)
                break
            }
        }

        // Checkboxes
        quitCheckbox.state = UserDefaults.standard.bool(forKey: "quitAfterLastWindowClosed") ? .on : .off
        dontHideCheckbox.state = UserDefaults.standard.bool(forKey: "dontHideWindow") ? .on : .off

        // Countdown
        let countdown = UserDefaults.standard.integer(forKey: "countdownSeconds")
        for item in countdownPopup.menu?.items ?? [] {
            if let value = item.representedObject as? Int, value == countdown {
                countdownPopup.select(item)
                break
            }
        }

        // Recent file count
        recentFileCountField.stringValue = String(Settings.shared.recentFileCount)

        // Log
        logEnabledCheckbox.state = Settings.shared.logEnabled ? .on : .off
        if let path = Logger.shared.logFilePath {
            logPathField.stringValue = path
        } else {
            logPathField.stringValue = L("settings.general.logPath.notAvailable")
        }
    }

    @objc private func languagePopupChanged() {
        guard let lang = languagePopup.selectedItem?.representedObject as? Language else { return }
        LocalizationManager.shared.setLanguage(lang)
    }

    @objc private func quitCheckboxChanged() {
        UserDefaults.standard.set(quitCheckbox.state == .on, forKey: "quitAfterLastWindowClosed")
    }

    @objc private func dontHideCheckboxChanged() {
        UserDefaults.standard.set(dontHideCheckbox.state == .on, forKey: "dontHideWindow")
    }

    @objc private func countdownPopupChanged() {
        guard let value = countdownPopup.selectedItem?.representedObject as? Int else { return }
        UserDefaults.standard.set(value, forKey: "countdownSeconds")
    }

    @objc private func updateFrequencyPopupChanged() {
        guard let freq = updateFrequencyPopup.selectedItem?.representedObject as? UpdateCheckFrequency else { return }
        Settings.shared.updateCheckFrequency = freq
    }

    @objc private func checkForUpdates() {
        AppActions.shared.checkForUpdates()
    }

    @objc private func languageChanged() {
        updateLocalizedStrings()
    }

    @objc private func logEnabledCheckboxChanged() {
        Settings.shared.logEnabled = (logEnabledCheckbox.state == .on)
    }

    @objc private func revealLogFile() {
        guard let path = Logger.shared.logFilePath else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
    }

    // MARK: - Helper methods

    private func createSectionView() -> NSStackView {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.wantsLayer = true
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        stack.layer?.cornerRadius = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return stack
    }

    private func createLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    private func createRowView(label: NSTextField, control: NSControl) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(control)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 180),

            control.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            container.topAnchor.constraint(equalTo: label.topAnchor),
            container.bottomAnchor.constraint(equalTo: label.bottomAnchor)
        ])

        return container
    }

    private func createRowView(label: NSTextField, control: NSControl, trailingButton: NSButton) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        trailingButton.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(control)
        container.addSubview(trailingButton)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 180),

            control.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            trailingButton.leadingAnchor.constraint(equalTo: control.trailingAnchor, constant: 8),
            trailingButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            trailingButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            container.topAnchor.constraint(equalTo: label.topAnchor),
            container.bottomAnchor.constraint(equalTo: label.bottomAnchor)
        ])

        return container
    }
}

// MARK: - NSTextFieldDelegate

extension GeneralSettingsViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, textField == recentFileCountField else { return }
        let value = Int(textField.stringValue) ?? 20
        let clampedValue = max(1, min(100, value))
        Settings.shared.recentFileCount = clampedValue
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField, textField == recentFileCountField else { return }
        let value = Int(textField.stringValue) ?? 20
        let clampedValue = max(1, min(100, value))
        textField.stringValue = String(clampedValue)
        Settings.shared.recentFileCount = clampedValue
    }
}

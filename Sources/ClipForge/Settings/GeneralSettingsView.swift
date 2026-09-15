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

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
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
        quitCheckbox.title = L("settings.general.quitAfterLastWindow")
        dontHideCheckbox.title = L("settings.general.dontHideWindow")

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

    @objc private func languageChanged() {
        updateLocalizedStrings()
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
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class EditingSettingsViewController: NSViewController {

    private let autoPlayCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let playbackEndPopup = NSPopUpButton()
    private let playbackEndLabel = NSTextField(labelWithString: "")
    private let resolutionPopup = NSPopUpButton()
    private let resolutionLabel = NSTextField(labelWithString: "")
    private let frameRatePopup = NSPopUpButton()
    private let frameRateLabel = NSTextField(labelWithString: "")
    private let formatPopup = NSPopUpButton()
    private let formatLabel = NSTextField(labelWithString: "")

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

        // Playback section
        let playbackSection = createSectionView()
        autoPlayCheckbox.target = self
        autoPlayCheckbox.action = #selector(autoPlayChanged)
        playbackSection.addArrangedSubview(autoPlayCheckbox)

        playbackEndPopup.target = self
        playbackEndPopup.action = #selector(playbackEndChanged)
        playbackSection.addArrangedSubview(createRowView(label: playbackEndLabel, control: playbackEndPopup))
        stackView.addArrangedSubview(playbackSection)

        // Export section
        let exportSection = createSectionView()
        resolutionPopup.target = self
        resolutionPopup.action = #selector(resolutionChanged)
        exportSection.addArrangedSubview(createRowView(label: resolutionLabel, control: resolutionPopup))

        frameRatePopup.target = self
        frameRatePopup.action = #selector(frameRateChanged)
        exportSection.addArrangedSubview(createRowView(label: frameRateLabel, control: frameRatePopup))

        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        exportSection.addArrangedSubview(createRowView(label: formatLabel, control: formatPopup))
        stackView.addArrangedSubview(exportSection)

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
    }

    private func updateLocalizedStrings() {
        // Update labels
        playbackEndLabel.stringValue = L("settings.editing.playbackEnd")
        resolutionLabel.stringValue = L("settings.editing.resolution")
        frameRateLabel.stringValue = L("settings.editing.frameRate")
        formatLabel.stringValue = L("settings.editing.format")
        autoPlayCheckbox.title = L("settings.editing.autoPlay")

        // Save current selections
        let currentPlaybackEnd = playbackEndPopup.selectedItem?.representedObject as? String ?? UserDefaults.standard.string(forKey: "playbackEndBehavior") ?? "restart"
        let currentResolution = resolutionPopup.selectedItem?.representedObject as? String ?? UserDefaults.standard.string(forKey: "exportResolution") ?? "original"
        let currentFrameRate = frameRatePopup.selectedItem?.representedObject as? String ?? UserDefaults.standard.string(forKey: "exportFrameRate") ?? "original"
        let currentFormat = formatPopup.selectedItem?.representedObject as? String ?? UserDefaults.standard.string(forKey: "exportFormat") ?? "mp4h264"

        playbackEndPopup.removeAllItems()
        playbackEndPopup.addItem(withTitle: L("settings.editing.playbackEnd.restart"))
        playbackEndPopup.lastItem?.representedObject = "restart"
        if currentPlaybackEnd == "restart" { playbackEndPopup.select(playbackEndPopup.lastItem) }
        playbackEndPopup.addItem(withTitle: L("settings.editing.playbackEnd.next"))
        playbackEndPopup.lastItem?.representedObject = "next"
        if currentPlaybackEnd == "next" { playbackEndPopup.select(playbackEndPopup.lastItem) }
        playbackEndPopup.addItem(withTitle: L("settings.editing.playbackEnd.stop"))
        playbackEndPopup.lastItem?.representedObject = "stop"
        if currentPlaybackEnd == "stop" { playbackEndPopup.select(playbackEndPopup.lastItem) }

        resolutionPopup.removeAllItems()
        for r in ExportResolution.allCases {
            resolutionPopup.addItem(withTitle: r.localizedName)
            resolutionPopup.lastItem?.representedObject = r.rawValue
            if currentResolution == r.rawValue {
                resolutionPopup.select(resolutionPopup.lastItem)
            }
        }

        frameRatePopup.removeAllItems()
        for r in ExportFrameRate.allCases {
            frameRatePopup.addItem(withTitle: r.localizedName)
            frameRatePopup.lastItem?.representedObject = r.rawValue
            if currentFrameRate == r.rawValue {
                frameRatePopup.select(frameRatePopup.lastItem)
            }
        }

        formatPopup.removeAllItems()
        for f in ExportFormat.allCases {
            formatPopup.addItem(withTitle: f.localizedName)
            formatPopup.lastItem?.representedObject = f.rawValue
            if currentFormat == f.rawValue {
                formatPopup.select(formatPopup.lastItem)
            }
        }
    }

    private func loadSettings() {
        autoPlayCheckbox.state = UserDefaults.standard.bool(forKey: "autoPlayOnOpen") ? .on : .off

        let playbackEnd = UserDefaults.standard.string(forKey: "playbackEndBehavior") ?? "restart"
        selectPopupItem(playbackEndPopup, withValue: playbackEnd)

        let resolution = UserDefaults.standard.string(forKey: "exportResolution") ?? "original"
        selectPopupItem(resolutionPopup, withValue: resolution)

        let frameRate = UserDefaults.standard.string(forKey: "exportFrameRate") ?? "original"
        selectPopupItem(frameRatePopup, withValue: frameRate)

        let format = UserDefaults.standard.string(forKey: "exportFormat") ?? "mp4h264"
        selectPopupItem(formatPopup, withValue: format)
    }

    private func selectPopupItem(_ popup: NSPopUpButton, withValue value: String) {
        for item in popup.menu?.items ?? [] {
            if let obj = item.representedObject as? String, obj == value {
                popup.select(item)
                return
            }
        }
    }

    // MARK: - Actions

    @objc private func autoPlayChanged() {
        UserDefaults.standard.set(autoPlayCheckbox.state == .on, forKey: "autoPlayOnOpen")
    }

    @objc private func playbackEndChanged() {
        guard let value = playbackEndPopup.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "playbackEndBehavior")
    }

    @objc private func resolutionChanged() {
        guard let value = resolutionPopup.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "exportResolution")
    }

    @objc private func frameRateChanged() {
        guard let value = frameRatePopup.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "exportFrameRate")
    }

    @objc private func formatChanged() {
        guard let value = formatPopup.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "exportFormat")
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
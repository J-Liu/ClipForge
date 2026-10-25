// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class AudioExportOptionsView: NSView {

    private let formatPopup = NSPopUpButton()
    private let bitRatePopup = NSPopUpButton()
    private let sampleRatePopup = NSPopUpButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading

        // Format row
        let formatLabel = createLabel(L("export.format"))
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        stackView.addArrangedSubview(createRowView(label: formatLabel, control: formatPopup))

        // Bit rate row
        let bitRateLabel = createLabel(L("export.bitRate"))
        bitRatePopup.target = self
        bitRatePopup.action = #selector(bitRateChanged)
        stackView.addArrangedSubview(createRowView(label: bitRateLabel, control: bitRatePopup))

        // Sample rate row
        let sampleRateLabel = createLabel(L("export.sampleRate"))
        sampleRatePopup.target = self
        sampleRatePopup.action = #selector(sampleRateChanged)
        stackView.addArrangedSubview(createRowView(label: sampleRateLabel, control: sampleRatePopup))

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
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
            label.widthAnchor.constraint(equalToConstant: 80),

            control.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.widthAnchor.constraint(equalToConstant: 140),

            container.topAnchor.constraint(equalTo: label.topAnchor),
            container.bottomAnchor.constraint(equalTo: label.bottomAnchor)
        ])

        return container
    }

    private func loadSettings() {
        for f in AudioExportFormat.allCases {
            formatPopup.addItem(withTitle: f.localizedName)
            formatPopup.lastItem?.representedObject = f.rawValue
        }
        for b in AudioBitRate.allCases {
            bitRatePopup.addItem(withTitle: b.localizedName)
            bitRatePopup.lastItem?.representedObject = b.rawValue
        }
        for s in AudioSampleRate.allCases {
            sampleRatePopup.addItem(withTitle: s.localizedName)
            sampleRatePopup.lastItem?.representedObject = s.rawValue
        }

        selectPopupItem(formatPopup, withValue: Settings.shared.audioExportFormat)
        selectPopupItem(bitRatePopup, withValue: Settings.shared.audioBitRate)
        selectPopupItem(sampleRatePopup, withValue: Settings.shared.audioSampleRate)
    }

    private func selectPopupItem(_ popup: NSPopUpButton, withValue value: String) {
        for item in popup.menu?.items ?? [] {
            if let obj = item.representedObject as? String, obj == value {
                popup.select(item)
                return
            }
        }
    }

    @objc private func formatChanged() {
        guard let value = formatPopup.selectedItem?.representedObject as? String else { return }
        Settings.shared.audioExportFormat = value
    }

    @objc private func bitRateChanged() {
        guard let value = bitRatePopup.selectedItem?.representedObject as? String else { return }
        Settings.shared.audioBitRate = value
    }

    @objc private func sampleRateChanged() {
        guard let value = sampleRatePopup.selectedItem?.representedObject as? String else { return }
        Settings.shared.audioSampleRate = value
    }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class ExportOptionsView: NSView {

    private let resolutionPopup = NSPopUpButton()
    private let frameRatePopup = NSPopUpButton()
    private let formatPopup = NSPopUpButton()

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

        // Resolution row
        let resolutionLabel = createLabel(L("export.resolution"))
        resolutionPopup.target = self
        resolutionPopup.action = #selector(resolutionChanged)
        stackView.addArrangedSubview(createRowView(label: resolutionLabel, control: resolutionPopup))

        // Frame rate row
        let frameRateLabel = createLabel(L("export.frameRate"))
        frameRatePopup.target = self
        frameRatePopup.action = #selector(frameRateChanged)
        stackView.addArrangedSubview(createRowView(label: frameRateLabel, control: frameRatePopup))

        // Format row
        let formatLabel = createLabel(L("export.format"))
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        stackView.addArrangedSubview(createRowView(label: formatLabel, control: formatPopup))

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
        for r in ExportResolution.allCases {
            resolutionPopup.addItem(withTitle: r.localizedName)
            resolutionPopup.lastItem?.representedObject = r.rawValue
        }
        for r in ExportFrameRate.allCases {
            frameRatePopup.addItem(withTitle: r.localizedName)
            frameRatePopup.lastItem?.representedObject = r.rawValue
        }
        for f in ExportFormat.allCases {
            formatPopup.addItem(withTitle: f.localizedName)
            formatPopup.lastItem?.representedObject = f.rawValue
        }

        selectPopupItem(resolutionPopup, withValue: UserDefaults.standard.string(forKey: "exportResolution") ?? "original")
        selectPopupItem(frameRatePopup, withValue: UserDefaults.standard.string(forKey: "exportFrameRate") ?? "original")
        selectPopupItem(formatPopup, withValue: UserDefaults.standard.string(forKey: "exportFormat") ?? "mp4h264")
    }

    private func selectPopupItem(_ popup: NSPopUpButton, withValue value: String) {
        for item in popup.menu?.items ?? [] {
            if let obj = item.representedObject as? String, obj == value {
                popup.select(item)
                return
            }
        }
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
}
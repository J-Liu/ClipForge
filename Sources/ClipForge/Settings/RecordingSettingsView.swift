// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

class RecordingSettingsViewController: NSViewController {

    private let modePopup = NSPopUpButton()
    private let modeLabel = NSTextField(labelWithString: "")
    private let buttonStylePopup = NSPopUpButton()
    private let buttonStyleLabel = NSTextField(labelWithString: "")
    private let systemAudioCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let microphoneCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let gainSlider = NSSlider(value: 1.0, minValue: 0.5, maxValue: 30.0, target: nil, action: nil)
    private let gainLabel = NSTextField(labelWithString: "1.0×")
    private let gainTitleLabel = NSTextField(labelWithString: "")
    private let frameRatePopup = NSPopUpButton()
    private let frameRateLabel = NSTextField(labelWithString: "")
    private let codecPopup = NSPopUpButton()
    private let codecLabel = NSTextField(labelWithString: "")
    private let formatPopup = NSPopUpButton()
    private let formatLabel = NSTextField(labelWithString: "")
    private let cursorCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dontHideCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let pathField = NSTextField()
    private let chooseButton = NSButton()
    private let revealButton = NSButton()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 600))
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
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        let clipView = NSClipView()
        clipView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.spacing = 20
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)

        // Default Mode section
        let modeSection = createSectionView()
        modePopup.target = self
        modePopup.action = #selector(modePopupChanged)
        modeSection.addArrangedSubview(createRowView(label: modeLabel, control: modePopup))

        buttonStylePopup.target = self
        buttonStylePopup.action = #selector(buttonStylePopupChanged)
        modeSection.addArrangedSubview(createRowView(label: buttonStyleLabel, control: buttonStylePopup))
        stackView.addArrangedSubview(modeSection)

        // Audio section
        let audioSection = createSectionView()
        systemAudioCheckbox.target = self
        systemAudioCheckbox.action = #selector(systemAudioChanged)
        audioSection.addArrangedSubview(systemAudioCheckbox)

        microphoneCheckbox.target = self
        microphoneCheckbox.action = #selector(microphoneChanged)
        audioSection.addArrangedSubview(microphoneCheckbox)

        let gainRow = createGainRow()
        audioSection.addArrangedSubview(gainRow)
        stackView.addArrangedSubview(audioSection)

        // Video section
        let videoSection = createSectionView()
        frameRatePopup.target = self
        frameRatePopup.action = #selector(frameRateChanged)
        videoSection.addArrangedSubview(createRowView(label: frameRateLabel, control: frameRatePopup))

        codecPopup.target = self
        codecPopup.action = #selector(codecChanged)
        videoSection.addArrangedSubview(createRowView(label: codecLabel, control: codecPopup))

        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        videoSection.addArrangedSubview(createRowView(label: formatLabel, control: formatPopup))

        cursorCheckbox.target = self
        cursorCheckbox.action = #selector(cursorChanged)
        videoSection.addArrangedSubview(cursorCheckbox)
        stackView.addArrangedSubview(videoSection)

        // Window section
        let windowSection = createSectionView()
        dontHideCheckbox.target = self
        dontHideCheckbox.action = #selector(dontHideChanged)
        windowSection.addArrangedSubview(dontHideCheckbox)
        stackView.addArrangedSubview(windowSection)

        // Output folder section
        let outputSection = createSectionView()
        let outputRow = createOutputRow()
        outputSection.addArrangedSubview(outputRow)
        stackView.addArrangedSubview(outputSection)

        clipView.documentView = stackView
        scrollView.contentView = clipView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: clipView.topAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: clipView.bottomAnchor)
        ])
    }

    private func updateLocalizedStrings() {
        // Update labels
        modeLabel.stringValue = L("settings.recording.mode")
        buttonStyleLabel.stringValue = L("settings.recording.buttonStyle")
        gainTitleLabel.stringValue = L("settings.recording.microphoneGain")
        frameRateLabel.stringValue = L("settings.recording.frameRate")
        codecLabel.stringValue = L("settings.recording.codec")
        formatLabel.stringValue = L("settings.recording.format")

        // Save current selections
        let currentMode = modePopup.selectedItem?.representedObject as? String ?? UserDefaults.standard.string(forKey: "recordingMode") ?? "fullScreen"
        let currentButtonStyle = buttonStylePopup.selectedItem?.representedObject as? String ?? UserDefaults.standard.string(forKey: "recordingButtonStyle") ?? "modePicker"
        let currentFrameRate = frameRatePopup.selectedItem?.representedObject as? Int ?? UserDefaults.standard.integer(forKey: "frameRate")
        let currentCodec = codecPopup.selectedItem?.representedObject as? String ?? UserDefaults.standard.string(forKey: "videoCodec") ?? "h264"
        let currentFormat = formatPopup.selectedItem?.representedObject as? String ?? UserDefaults.standard.string(forKey: "recordingFormat") ?? "mp4"

        // Mode popup
        modePopup.removeAllItems()
        modePopup.addItem(withTitle: L("settings.recording.mode.fullScreen"))
        modePopup.lastItem?.representedObject = "fullScreen"
        if currentMode == "fullScreen" { modePopup.select(modePopup.lastItem) }
        modePopup.addItem(withTitle: L("settings.recording.mode.window"))
        modePopup.lastItem?.representedObject = "window"
        if currentMode == "window" { modePopup.select(modePopup.lastItem) }
        modePopup.addItem(withTitle: L("settings.recording.mode.region"))
        modePopup.lastItem?.representedObject = "region"
        if currentMode == "region" { modePopup.select(modePopup.lastItem) }

        // Button style popup
        buttonStylePopup.removeAllItems()
        buttonStylePopup.addItem(withTitle: L("settings.recording.buttonStyle.modePicker"))
        buttonStylePopup.lastItem?.representedObject = "modePicker"
        if currentButtonStyle == "modePicker" { buttonStylePopup.select(buttonStylePopup.lastItem) }
        buttonStylePopup.addItem(withTitle: L("settings.recording.buttonStyle.directAction"))
        buttonStylePopup.lastItem?.representedObject = "directAction"
        if currentButtonStyle == "directAction" { buttonStylePopup.select(buttonStylePopup.lastItem) }

        // Checkboxes
        systemAudioCheckbox.title = L("settings.recording.captureSystemAudio")
        microphoneCheckbox.title = L("settings.recording.captureMicrophone")
        cursorCheckbox.title = L("settings.recording.showCursor")
        dontHideCheckbox.title = L("settings.recording.dontHideMainWindow")

        // Frame rate popup
        frameRatePopup.removeAllItems()
        frameRatePopup.addItem(withTitle: L("settings.recording.30fps"))
        frameRatePopup.lastItem?.representedObject = 30
        if currentFrameRate == 30 { frameRatePopup.select(frameRatePopup.lastItem) }
        frameRatePopup.addItem(withTitle: L("settings.recording.60fps"))
        frameRatePopup.lastItem?.representedObject = 60
        if currentFrameRate == 60 { frameRatePopup.select(frameRatePopup.lastItem) }

        // Codec popup
        codecPopup.removeAllItems()
        codecPopup.addItem(withTitle: L("settings.recording.h264"))
        codecPopup.lastItem?.representedObject = "h264"
        if currentCodec == "h264" { codecPopup.select(codecPopup.lastItem) }
        codecPopup.addItem(withTitle: L("settings.recording.h265"))
        codecPopup.lastItem?.representedObject = "h265"
        if currentCodec == "h265" { codecPopup.select(codecPopup.lastItem) }

        // Format popup
        formatPopup.removeAllItems()
        formatPopup.addItem(withTitle: L("settings.recording.mp4"))
        formatPopup.lastItem?.representedObject = "mp4"
        if currentFormat == "mp4" { formatPopup.select(formatPopup.lastItem) }
        formatPopup.addItem(withTitle: L("settings.recording.mov"))
        formatPopup.lastItem?.representedObject = "mov"
        if currentFormat == "mov" { formatPopup.select(formatPopup.lastItem) }

        // Buttons
        chooseButton.title = L("settings.recording.choose")
        revealButton.title = L("settings.recording.reveal")
    }

    private func loadSettings() {
        // Mode
        let mode = UserDefaults.standard.string(forKey: "recordingMode") ?? "fullScreen"
        selectPopupItem(modePopup, withValue: mode)

        // Button style
        let style = UserDefaults.standard.string(forKey: "recordingButtonStyle") ?? "modePicker"
        selectPopupItem(buttonStylePopup, withValue: style)

        // Checkboxes
        systemAudioCheckbox.state = UserDefaults.standard.bool(forKey: "captureSystemAudio") ? .on : .off
        microphoneCheckbox.state = UserDefaults.standard.bool(forKey: "captureMicrophone") ? .on : .off
        cursorCheckbox.state = UserDefaults.standard.bool(forKey: "showsCursor") ? .on : .off
        dontHideCheckbox.state = UserDefaults.standard.bool(forKey: "dontHideWindow") ? .on : .off

        // Gain
        gainSlider.doubleValue = UserDefaults.standard.double(forKey: "microphoneGain")
        if gainSlider.doubleValue < 0.5 { gainSlider.doubleValue = 1.0 }
        updateGainLabel()

        // Frame rate
        let frameRate = UserDefaults.standard.integer(forKey: "frameRate")
        if frameRate == 0 { selectPopupItem(frameRatePopup, withValue: 30) }
        else { selectPopupItem(frameRatePopup, withValue: frameRate) }

        // Codec
        let codec = UserDefaults.standard.string(forKey: "videoCodec") ?? "h264"
        selectPopupItem(codecPopup, withValue: codec)

        // Format
        let format = UserDefaults.standard.string(forKey: "recordingFormat") ?? "mp4"
        selectPopupItem(formatPopup, withValue: format)

        // Output path
        pathField.stringValue = Settings.shared.recordingOutputDirectory.path
    }

    private func selectPopupItem(_ popup: NSPopUpButton, withValue value: Any) {
        for item in popup.menu?.items ?? [] {
            if let obj = item.representedObject {
                if let val1 = value as? String, let val2 = obj as? String, val1 == val2 {
                    popup.select(item)
                    return
                }
                if let val1 = value as? Int, let val2 = obj as? Int, val1 == val2 {
                    popup.select(item)
                    return
                }
            }
        }
    }

    private func createGainRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        gainTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        gainLabel.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        gainLabel.textColor = .secondaryLabelColor
        gainLabel.translatesAutoresizingMaskIntoConstraints = false
        gainSlider.translatesAutoresizingMaskIntoConstraints = false
        gainSlider.target = self
        gainSlider.action = #selector(gainSliderChanged)
        gainSlider.isContinuous = true

        container.addSubview(gainTitleLabel)
        container.addSubview(gainLabel)
        container.addSubview(gainSlider)

        NSLayoutConstraint.activate([
            gainTitleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gainTitleLabel.topAnchor.constraint(equalTo: container.topAnchor),

            gainLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            gainLabel.centerYAnchor.constraint(equalTo: gainTitleLabel.centerYAnchor),

            gainSlider.topAnchor.constraint(equalTo: gainTitleLabel.bottomAnchor, constant: 4),
            gainSlider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            gainSlider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            gainSlider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func createOutputRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        pathField.translatesAutoresizingMaskIntoConstraints = false
        pathField.isEditable = false
        pathField.isBordered = false
        pathField.drawsBackground = false
        pathField.textColor = .secondaryLabelColor
        pathField.lineBreakMode = .byTruncatingMiddle

        chooseButton.bezelStyle = .rounded
        chooseButton.target = self
        chooseButton.action = #selector(chooseFolder)

        revealButton.bezelStyle = .rounded
        revealButton.target = self
        revealButton.action = #selector(revealFolder)

        let buttonStack = NSStackView(views: [chooseButton, revealButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8

        container.addSubview(pathField)
        container.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            pathField.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pathField.topAnchor.constraint(equalTo: container.topAnchor),
            pathField.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            pathField.trailingAnchor.constraint(lessThanOrEqualTo: buttonStack.leadingAnchor, constant: -8),

            buttonStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    // MARK: - Actions

    @objc private func modePopupChanged() {
        guard let value = modePopup.selectedItem?.representedObject as? String,
              let mode = RecordingMode(rawValue: value) else { return }
        Settings.shared.recordingMode = mode
    }

    @objc private func buttonStylePopupChanged() {
        guard let value = buttonStylePopup.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "recordingButtonStyle")
    }

    @objc private func systemAudioChanged() {
        UserDefaults.standard.set(systemAudioCheckbox.state == .on, forKey: "captureSystemAudio")
    }

    @objc private func microphoneChanged() {
        UserDefaults.standard.set(microphoneCheckbox.state == .on, forKey: "captureMicrophone")
        gainSlider.isEnabled = microphoneCheckbox.state == .on
    }

    @objc private func gainSliderChanged() {
        UserDefaults.standard.set(gainSlider.doubleValue, forKey: "microphoneGain")
        updateGainLabel()
    }

    private func updateGainLabel() {
        gainLabel.stringValue = String(format: "%.1f×", gainSlider.doubleValue)
    }

    @objc private func frameRateChanged() {
        guard let value = frameRatePopup.selectedItem?.representedObject as? Int else { return }
        UserDefaults.standard.set(value, forKey: "frameRate")
    }

    @objc private func codecChanged() {
        guard let value = codecPopup.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "videoCodec")
    }

    @objc private func formatChanged() {
        guard let value = formatPopup.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "recordingFormat")
    }

    @objc private func cursorChanged() {
        UserDefaults.standard.set(cursorCheckbox.state == .on, forKey: "showsCursor")
    }

    @objc private func dontHideChanged() {
        UserDefaults.standard.set(dontHideCheckbox.state == .on, forKey: "dontHideWindow")
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Settings.shared.recordingOutputDirectory
        if panel.runModal() == .OK, let url = panel.url {
            Settings.shared.recordingOutputDirectory = url
            pathField.stringValue = url.path
        }
    }

    @objc private func revealFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: Settings.shared.recordingOutputDirectory.path)
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
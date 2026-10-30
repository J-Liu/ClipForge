// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Settings window with tabs for configuration and About page.
final class SettingsWindow: NSWindow {

    private var tabView: NSTabView!
    private var generalTab: NSView!
    private var recordingTab: NSView!
    private var editingTab: NSView!
    private var aboutTab: NSView!

    // Layout constants
    private let labelWidth: CGFloat = 160
    private let controlWidth: CGFloat = 200
    private let rowSpacing: CGFloat = 16
    private let viewWidth: CGFloat = 520

    init() {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let width: CGFloat = 560
        let height: CGFloat = 620
        let x = screenFrame.midX - width / 2
        let y = screenFrame.midY - height / 2
        let frame = NSRect(x: x, y: y, width: width, height: height)

        super.init(
            contentRect: frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        self.title = L("menu.app.settings").replacingOccurrences(of: "…", with: "")
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 560, height: 500)

        setupUI()
        setupKeyHandlers()

        NotificationCenter.default.addObserver(
            forName: .languageChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recreateUI()
        }
    }

    private func setupUI() {
        tabView = NSTabView(frame: contentView!.bounds.insetBy(dx: 10, dy: 10))
        tabView.autoresizingMask = [.width, .height]
        tabView.delegate = self

        generalTab = createGeneralTab()
        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = L("settings.tab.general")
        generalItem.view = generalTab
        tabView.addTabViewItem(generalItem)

        recordingTab = createRecordingTab()
        let recordingItem = NSTabViewItem(identifier: "recording")
        recordingItem.label = L("settings.tab.recording")
        recordingItem.view = recordingTab
        tabView.addTabViewItem(recordingItem)

        editingTab = createEditingTab()
        let editingItem = NSTabViewItem(identifier: "editing")
        editingItem.label = L("settings.tab.editing")
        editingItem.view = editingTab
        tabView.addTabViewItem(editingItem)

        aboutTab = createAboutTab()
        let aboutItem = NSTabViewItem(identifier: "about")
        aboutItem.label = L("settings.tab.about")
        aboutItem.view = aboutTab
        tabView.addTabViewItem(aboutItem)

        contentView?.addSubview(tabView)
    }

    // MARK: - Layout Helpers

    /// A container view that accepts first responder to handle focus loss from text fields.
    private class FocusableContainerView: NSView {
        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            // When clicked, end editing in any text field
            window?.makeFirstResponder(nil)
        }
    }

    /// Wrap content in a top-aligned container so the stack starts at the top.
    private func wrapInTopAlignedContainer(_ stack: NSStackView) -> NSView {
        let container = FocusableContainerView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor)
        ])
        return container
    }

    /// Build a row: right-aligned label on the left, control on the right.
    private func makeRow(label: String, control: NSView) -> NSStackView {
        let labelField = NSTextField(labelWithString: label)
        labelField.alignment = .right
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        control.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [labelField, control])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    /// Build a vertical stack with consistent spacing.
    private func makeVerticalStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = rowSpacing
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        return stack
    }

    // MARK: - General Tab

    private func createGeneralTab() -> NSView {
        let stack = makeVerticalStack()

        // Row: Language
        let languagePopup = NSPopUpButton()
        for lang in Language.allCases {
            let title: String
            if lang == .system {
                title = L("settings.language.system")
            } else {
                title = lang.nativeName
            }
            languagePopup.addItem(withTitle: title)
            languagePopup.lastItem?.representedObject = lang
            if lang == LocalizationManager.shared.currentLanguage {
                languagePopup.select(languagePopup.lastItem)
            }
        }
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.general.language"), control: languagePopup))

        // Row: Quit after last window
        let quitCheckbox = NSButton(checkboxWithTitle: L("settings.general.quitAfterLastWindow"), target: self, action: #selector(quitCheckboxChanged(_:)))
        quitCheckbox.state = UserDefaults.standard.bool(forKey: "quitAfterLastWindowClosed") ? .on : .off
        stack.addArrangedSubview(makeRow(label: "", control: quitCheckbox))

        // Row: Don't hide window
        let dontHideCheckbox = NSButton(checkboxWithTitle: L("settings.general.dontHideWindow"), target: self, action: #selector(dontHideCheckboxChanged(_:)))
        dontHideCheckbox.state = UserDefaults.standard.bool(forKey: "dontHideWindow") ? .on : .off
        stack.addArrangedSubview(makeRow(label: "", control: dontHideCheckbox))

        // Row: Countdown
        let countdownPopup = NSPopUpButton()
        let countdownValue = UserDefaults.standard.integer(forKey: "countdownSeconds")
        countdownPopup.addItem(withTitle: L("settings.general.countdown.none"))
        countdownPopup.lastItem?.representedObject = 0
        if countdownValue == 0 { countdownPopup.select(countdownPopup.lastItem) }
        countdownPopup.addItem(withTitle: L("settings.general.countdown.3seconds"))
        countdownPopup.lastItem?.representedObject = 3
        if countdownValue == 3 { countdownPopup.select(countdownPopup.lastItem) }
        countdownPopup.addItem(withTitle: L("settings.general.countdown.5seconds"))
        countdownPopup.lastItem?.representedObject = 5
        if countdownValue == 5 { countdownPopup.select(countdownPopup.lastItem) }
        countdownPopup.target = self
        countdownPopup.action = #selector(countdownChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.general.countdown"), control: countdownPopup))

        // Row: Update frequency
        let updateFrequencyPopup = NSPopUpButton()
        let currentFrequency = Settings.shared.updateCheckFrequency
        for freq in UpdateCheckFrequency.allCases {
            updateFrequencyPopup.addItem(withTitle: L("settings.general.updateFrequency.\(freq.rawValue)"))
            updateFrequencyPopup.lastItem?.representedObject = freq
            if freq == currentFrequency {
                updateFrequencyPopup.select(updateFrequencyPopup.lastItem)
            }
        }
        updateFrequencyPopup.target = self
        updateFrequencyPopup.action = #selector(updateFrequencyChanged(_:))
        updateFrequencyPopup.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let checkNowButton = NSButton(title: L("settings.general.checkForUpdates"), target: self, action: #selector(checkForUpdates))
        checkNowButton.bezelStyle = .rounded

        let updateRow = NSStackView(views: [updateFrequencyPopup, checkNowButton])
        updateRow.orientation = .horizontal
        updateRow.spacing = 12
        updateRow.alignment = .centerY
        stack.addArrangedSubview(makeRow(label: L("settings.general.updateFrequency"), control: updateRow))

        // Row: Recent file count
        let recentFileCountField = NSTextField()
        recentFileCountField.stringValue = String(Settings.shared.recentFileCount)
        recentFileCountField.isEditable = true
        recentFileCountField.isBezeled = true
        recentFileCountField.bezelStyle = .roundedBezel
        recentFileCountField.delegate = self
        recentFileCountField.identifier = NSUserInterfaceItemIdentifier("recentFileCount")
        recentFileCountField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        stack.addArrangedSubview(makeRow(label: L("settings.general.recentFileCount"), control: recentFileCountField))

        // Section: Log
        let logLabel = NSTextField(labelWithString: L("settings.general.log"))
        logLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let logLabelContainer = NSView()
        logLabel.translatesAutoresizingMaskIntoConstraints = false
        logLabelContainer.addSubview(logLabel)
        NSLayoutConstraint.activate([
            logLabel.topAnchor.constraint(equalTo: logLabelContainer.topAnchor, constant: 8),
            logLabel.leadingAnchor.constraint(equalTo: logLabelContainer.leadingAnchor),
            logLabel.trailingAnchor.constraint(equalTo: logLabelContainer.trailingAnchor),
            logLabel.bottomAnchor.constraint(equalTo: logLabelContainer.bottomAnchor)
        ])
        stack.addArrangedSubview(logLabelContainer)

        // Row: Enable Log
        let logEnabledCheckbox = NSButton(checkboxWithTitle: L("settings.general.enableLog"), target: self, action: #selector(logEnabledChanged(_:)))
        logEnabledCheckbox.state = Settings.shared.logEnabled ? .on : .off
        stack.addArrangedSubview(makeRow(label: "", control: logEnabledCheckbox))

        // Log path row
        let logPathField = NSTextField()
        logPathField.stringValue = Logger.shared.logFilePath ?? L("settings.general.logPath.notAvailable")
        logPathField.isEditable = false
        logPathField.isBezeled = true
        logPathField.bezelStyle = .roundedBezel
        logPathField.widthAnchor.constraint(equalToConstant: 350).isActive = true

        let revealLogButton = NSButton()
        revealLogButton.bezelStyle = .rounded
        revealLogButton.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        revealLogButton.target = self
        revealLogButton.action = #selector(revealLogFile)

        let logPathRow = NSStackView(views: [logPathField, revealLogButton])
        logPathRow.orientation = .horizontal
        logPathRow.spacing = 8
        logPathRow.alignment = .centerY
        stack.addArrangedSubview(makeRow(label: L("settings.general.logPath"), control: logPathRow))

        return wrapInTopAlignedContainer(stack)
    }

    // MARK: - Recording Tab

    private func createRecordingTab() -> NSView {
        let stack = makeVerticalStack()

        // Row: Default Mode
        let modePopup = NSPopUpButton()
        let currentMode = UserDefaults.standard.string(forKey: "recordingMode") ?? "fullScreen"
        modePopup.addItem(withTitle: L("settings.recording.mode.fullScreen"))
        modePopup.lastItem?.representedObject = "fullScreen"
        if currentMode == "fullScreen" { modePopup.select(modePopup.lastItem) }
        modePopup.addItem(withTitle: L("settings.recording.mode.window"))
        modePopup.lastItem?.representedObject = "window"
        if currentMode == "window" { modePopup.select(modePopup.lastItem) }
        modePopup.addItem(withTitle: L("settings.recording.mode.region"))
        modePopup.lastItem?.representedObject = "region"
        if currentMode == "region" { modePopup.select(modePopup.lastItem) }
        modePopup.target = self
        modePopup.action = #selector(recordingModeChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.recording.mode"), control: modePopup))

        // Row: Button Style
        let buttonStylePopup = NSPopUpButton()
        let currentButtonStyle = UserDefaults.standard.string(forKey: "recordingButtonStyle") ?? "modePicker"
        buttonStylePopup.addItem(withTitle: L("settings.recording.buttonStyle.modePicker"))
        buttonStylePopup.lastItem?.representedObject = "modePicker"
        if currentButtonStyle == "modePicker" { buttonStylePopup.select(buttonStylePopup.lastItem) }
        buttonStylePopup.addItem(withTitle: L("settings.recording.buttonStyle.directAction"))
        buttonStylePopup.lastItem?.representedObject = "directAction"
        if currentButtonStyle == "directAction" { buttonStylePopup.select(buttonStylePopup.lastItem) }
        buttonStylePopup.target = self
        buttonStylePopup.action = #selector(buttonStyleChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.recording.buttonStyle"), control: buttonStylePopup))

        // Section: Audio
        let audioLabel = NSTextField(labelWithString: L("settings.recording.audio"))
        audioLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let audioLabelContainer = NSView()
        audioLabel.translatesAutoresizingMaskIntoConstraints = false
        audioLabelContainer.addSubview(audioLabel)
        NSLayoutConstraint.activate([
            audioLabel.topAnchor.constraint(equalTo: audioLabelContainer.topAnchor, constant: 8),
            audioLabel.leadingAnchor.constraint(equalTo: audioLabelContainer.leadingAnchor),
            audioLabel.trailingAnchor.constraint(equalTo: audioLabelContainer.trailingAnchor),
            audioLabel.bottomAnchor.constraint(equalTo: audioLabelContainer.bottomAnchor)
        ])
        stack.addArrangedSubview(audioLabelContainer)

        // Row: Capture System Audio
        let systemAudioCheckbox = NSButton(checkboxWithTitle: L("settings.recording.captureSystemAudio"), target: self, action: #selector(systemAudioChanged(_:)))
        systemAudioCheckbox.state = UserDefaults.standard.bool(forKey: "captureSystemAudio") ? .on : .off
        stack.addArrangedSubview(makeRow(label: "", control: systemAudioCheckbox))

        // Row: Capture Microphone
        let microphoneCheckbox = NSButton(checkboxWithTitle: L("settings.recording.captureMicrophone"), target: self, action: #selector(microphoneChanged(_:)))
        microphoneCheckbox.identifier = NSUserInterfaceItemIdentifier("microphoneCheckbox")
        microphoneCheckbox.state = UserDefaults.standard.bool(forKey: "captureMicrophone") ? .on : .off
        stack.addArrangedSubview(makeRow(label: "", control: microphoneCheckbox))

        // Row: Microphone Gain
        let gainValueRaw = max(0.5, min(30.0, UserDefaults.standard.double(forKey: "microphoneGain")))
        let gainSlider = NSSlider(value: gainValueRaw, minValue: 0.5, maxValue: 30.0, target: self, action: #selector(gainSliderChanged(_:)))
        gainSlider.isContinuous = true
        gainSlider.identifier = NSUserInterfaceItemIdentifier("gainSlider")
        gainSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        let gainValue = NSTextField(labelWithString: String(format: "%.1f×", gainValueRaw))
        gainValue.identifier = NSUserInterfaceItemIdentifier("gainValue")
        gainValue.widthAnchor.constraint(equalToConstant: 50).isActive = true

        let gainRow = NSStackView(views: [gainSlider, gainValue])
        gainRow.orientation = .horizontal
        gainRow.spacing = 8
        gainRow.alignment = .centerY
        stack.addArrangedSubview(makeRow(label: L("settings.recording.microphoneGain"), control: gainRow))

        // Section: Video
        let videoLabel = NSTextField(labelWithString: L("settings.recording.video"))
        videoLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let videoLabelContainer = NSView()
        videoLabel.translatesAutoresizingMaskIntoConstraints = false
        videoLabelContainer.addSubview(videoLabel)
        NSLayoutConstraint.activate([
            videoLabel.topAnchor.constraint(equalTo: videoLabelContainer.topAnchor, constant: 8),
            videoLabel.leadingAnchor.constraint(equalTo: videoLabelContainer.leadingAnchor),
            videoLabel.trailingAnchor.constraint(equalTo: videoLabelContainer.trailingAnchor),
            videoLabel.bottomAnchor.constraint(equalTo: videoLabelContainer.bottomAnchor)
        ])
        stack.addArrangedSubview(videoLabelContainer)

        // Row: Frame Rate
        let frameRatePopup = NSPopUpButton()
        let currentFrameRate = UserDefaults.standard.integer(forKey: "frameRate")
        frameRatePopup.addItem(withTitle: L("settings.recording.30fps"))
        frameRatePopup.lastItem?.representedObject = 30
        if currentFrameRate == 30 { frameRatePopup.select(frameRatePopup.lastItem) }
        frameRatePopup.addItem(withTitle: L("settings.recording.60fps"))
        frameRatePopup.lastItem?.representedObject = 60
        if currentFrameRate == 60 { frameRatePopup.select(frameRatePopup.lastItem) }
        frameRatePopup.target = self
        frameRatePopup.action = #selector(recordingFrameRateChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.recording.frameRate"), control: frameRatePopup))

        // Row: Codec
        let codecPopup = NSPopUpButton()
        let currentCodec = UserDefaults.standard.string(forKey: "videoCodec") ?? "h264"
        codecPopup.addItem(withTitle: L("settings.recording.h264"))
        codecPopup.lastItem?.representedObject = "h264"
        if currentCodec == "h264" { codecPopup.select(codecPopup.lastItem) }
        codecPopup.addItem(withTitle: L("settings.recording.h265"))
        codecPopup.lastItem?.representedObject = "h265"
        if currentCodec == "h265" { codecPopup.select(codecPopup.lastItem) }
        codecPopup.target = self
        codecPopup.action = #selector(codecChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.recording.codec"), control: codecPopup))

        // Row: Format
        let formatPopup = NSPopUpButton()
        let currentFormat = UserDefaults.standard.string(forKey: "recordingFormat") ?? "mp4"
        formatPopup.addItem(withTitle: L("settings.recording.mp4"))
        formatPopup.lastItem?.representedObject = "mp4"
        if currentFormat == "mp4" { formatPopup.select(formatPopup.lastItem) }
        formatPopup.addItem(withTitle: L("settings.recording.mov"))
        formatPopup.lastItem?.representedObject = "mov"
        if currentFormat == "mov" { formatPopup.select(formatPopup.lastItem) }
        formatPopup.target = self
        formatPopup.action = #selector(recordingFormatChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.recording.format"), control: formatPopup))

        // Row: Show Cursor
        let cursorCheckbox = NSButton(checkboxWithTitle: L("settings.recording.showCursor"), target: self, action: #selector(cursorChanged(_:)))
        cursorCheckbox.state = UserDefaults.standard.bool(forKey: "showsCursor") ? .on : .off
        stack.addArrangedSubview(makeRow(label: "", control: cursorCheckbox))

        // Row: Don't Hide Window
        let dontHideRecordCheckbox = NSButton(checkboxWithTitle: L("settings.recording.dontHideMainWindow"), target: self, action: #selector(dontHideRecordChanged(_:)))
        dontHideRecordCheckbox.state = UserDefaults.standard.bool(forKey: "dontHideWindow") ? .on : .off
        stack.addArrangedSubview(makeRow(label: "", control: dontHideRecordCheckbox))

        // Section: Output
        let outputLabel = NSTextField(labelWithString: L("settings.recording.output"))
        outputLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let outputLabelContainer = NSView()
        outputLabel.translatesAutoresizingMaskIntoConstraints = false
        outputLabelContainer.addSubview(outputLabel)
        NSLayoutConstraint.activate([
            outputLabel.topAnchor.constraint(equalTo: outputLabelContainer.topAnchor, constant: 8),
            outputLabel.leadingAnchor.constraint(equalTo: outputLabelContainer.leadingAnchor),
            outputLabel.trailingAnchor.constraint(equalTo: outputLabelContainer.trailingAnchor),
            outputLabel.bottomAnchor.constraint(equalTo: outputLabelContainer.bottomAnchor)
        ])
        stack.addArrangedSubview(outputLabelContainer)

        // Row: Output Directory
        let pathField = NSTextField()
        pathField.stringValue = Settings.shared.recordingOutputDirectory.path
        pathField.isEditable = false
        pathField.isBezeled = true
        pathField.bezelStyle = .roundedBezel
        pathField.identifier = NSUserInterfaceItemIdentifier("outputPath")
        pathField.widthAnchor.constraint(equalToConstant: 300).isActive = true
        pathField.lineBreakMode = .byTruncatingMiddle

        let chooseButton = NSButton(title: L("settings.recording.choose"), target: self, action: #selector(chooseOutputFolder))
        chooseButton.bezelStyle = .rounded

        let revealButton = NSButton(title: L("settings.recording.reveal"), target: self, action: #selector(revealOutputFolder))
        revealButton.bezelStyle = .rounded

        let outputRow = NSStackView(views: [pathField, chooseButton, revealButton])
        outputRow.orientation = .horizontal
        outputRow.spacing = 8
        outputRow.alignment = .centerY
        stack.addArrangedSubview(makeRow(label: "", control: outputRow))

        return wrapInTopAlignedContainer(stack)
    }

    // MARK: - Editing Tab

    private func createEditingTab() -> NSView {
        let stack = makeVerticalStack()

        // Section: Playback
        let playbackLabel = NSTextField(labelWithString: L("settings.editing.playback"))
        playbackLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let playbackLabelContainer = NSView()
        playbackLabel.translatesAutoresizingMaskIntoConstraints = false
        playbackLabelContainer.addSubview(playbackLabel)
        NSLayoutConstraint.activate([
            playbackLabel.topAnchor.constraint(equalTo: playbackLabelContainer.topAnchor, constant: 8),
            playbackLabel.leadingAnchor.constraint(equalTo: playbackLabelContainer.leadingAnchor),
            playbackLabel.trailingAnchor.constraint(equalTo: playbackLabelContainer.trailingAnchor),
            playbackLabel.bottomAnchor.constraint(equalTo: playbackLabelContainer.bottomAnchor)
        ])
        stack.addArrangedSubview(playbackLabelContainer)

        // Row: Auto Play
        let autoPlayCheckbox = NSButton(checkboxWithTitle: L("settings.editing.autoPlay"), target: self, action: #selector(autoPlayChanged(_:)))
        autoPlayCheckbox.state = UserDefaults.standard.bool(forKey: "autoPlayOnOpen") ? .on : .off
        stack.addArrangedSubview(makeRow(label: "", control: autoPlayCheckbox))

        // Row: Playback End Behavior
        let playbackEndPopup = NSPopUpButton()
        let currentPlaybackEnd = UserDefaults.standard.string(forKey: "playbackEndBehavior") ?? "restart"
        playbackEndPopup.addItem(withTitle: L("settings.editing.playbackEnd.restart"))
        playbackEndPopup.lastItem?.representedObject = "restart"
        if currentPlaybackEnd == "restart" { playbackEndPopup.select(playbackEndPopup.lastItem) }
        playbackEndPopup.addItem(withTitle: L("settings.editing.playbackEnd.next"))
        playbackEndPopup.lastItem?.representedObject = "next"
        if currentPlaybackEnd == "next" { playbackEndPopup.select(playbackEndPopup.lastItem) }
        playbackEndPopup.addItem(withTitle: L("settings.editing.playbackEnd.stop"))
        playbackEndPopup.lastItem?.representedObject = "stop"
        if currentPlaybackEnd == "stop" { playbackEndPopup.select(playbackEndPopup.lastItem) }
        playbackEndPopup.target = self
        playbackEndPopup.action = #selector(playbackEndChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.editing.playbackEnd"), control: playbackEndPopup))

        // Section: Export
        let exportLabel = NSTextField(labelWithString: L("settings.editing.export"))
        exportLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let exportLabelContainer = NSView()
        exportLabel.translatesAutoresizingMaskIntoConstraints = false
        exportLabelContainer.addSubview(exportLabel)
        NSLayoutConstraint.activate([
            exportLabel.topAnchor.constraint(equalTo: exportLabelContainer.topAnchor, constant: 8),
            exportLabel.leadingAnchor.constraint(equalTo: exportLabelContainer.leadingAnchor),
            exportLabel.trailingAnchor.constraint(equalTo: exportLabelContainer.trailingAnchor),
            exportLabel.bottomAnchor.constraint(equalTo: exportLabelContainer.bottomAnchor)
        ])
        stack.addArrangedSubview(exportLabelContainer)

        // Row: Resolution
        let resolutionPopup = NSPopUpButton()
        let currentResolution = UserDefaults.standard.string(forKey: "exportResolution") ?? "original"
        for r in ExportResolution.allCases {
            resolutionPopup.addItem(withTitle: r.localizedName)
            resolutionPopup.lastItem?.representedObject = r.rawValue
            if currentResolution == r.rawValue {
                resolutionPopup.select(resolutionPopup.lastItem)
            }
        }
        resolutionPopup.target = self
        resolutionPopup.action = #selector(exportResolutionChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.editing.resolution"), control: resolutionPopup))

        // Row: Frame Rate
        let frameRatePopup = NSPopUpButton()
        let currentFrameRate = UserDefaults.standard.string(forKey: "exportFrameRate") ?? "original"
        for r in ExportFrameRate.allCases {
            frameRatePopup.addItem(withTitle: r.localizedName)
            frameRatePopup.lastItem?.representedObject = r.rawValue
            if currentFrameRate == r.rawValue {
                frameRatePopup.select(frameRatePopup.lastItem)
            }
        }
        frameRatePopup.target = self
        frameRatePopup.action = #selector(exportFrameRateChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.editing.frameRate"), control: frameRatePopup))

        // Row: Format
        let formatPopup = NSPopUpButton()
        let currentFormat = UserDefaults.standard.string(forKey: "exportFormat") ?? "mp4h264"
        for f in ExportFormat.allCases {
            formatPopup.addItem(withTitle: f.localizedName)
            formatPopup.lastItem?.representedObject = f.rawValue
            if currentFormat == f.rawValue {
                formatPopup.select(formatPopup.lastItem)
            }
        }
        formatPopup.target = self
        formatPopup.action = #selector(exportFormatChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("settings.editing.format"), control: formatPopup))

        // Row: Video Bit Rate
        let bitRatePopup = NSPopUpButton()
        let currentBitRate = Settings.shared.videoBitRate
        for b in VideoBitRate.allCases {
            bitRatePopup.addItem(withTitle: b.localizedName)
            bitRatePopup.lastItem?.representedObject = b.rawValue
            if currentBitRate == b.rawValue {
                bitRatePopup.select(bitRatePopup.lastItem)
            }
        }
        bitRatePopup.target = self
        bitRatePopup.action = #selector(videoBitRateChanged(_:))
        stack.addArrangedSubview(makeRow(label: L("export.bitRate"), control: bitRatePopup))

        return wrapInTopAlignedContainer(stack)
    }

    // MARK: - About Tab

    private func createAboutTab() -> NSView {
        let container = NSView()

        // App Icon
        let appIcon = NSImageView()
        // Try multiple locations for the app icon
        if let image = NSImage(named: NSImage.applicationIconName) {
            appIcon.image = image
        } else if let icnsPath = Bundle.main.path(forResource: "ClipForge", ofType: "icns"),
           let image = NSImage(contentsOfFile: icnsPath) {
            appIcon.image = image
        } else if let compiledPath = Bundle.main.path(forResource: "Compiled/ClipForge", ofType: "icns"),
           let image = NSImage(contentsOfFile: compiledPath) {
            appIcon.image = image
        } else {
            appIcon.image = NSImage(systemSymbolName: "film", accessibilityDescription: nil)
            appIcon.contentTintColor = .controlAccentColor
        }
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.widthAnchor.constraint(equalToConstant: 80).isActive = true
        appIcon.heightAnchor.constraint(equalToConstant: 80).isActive = true
        container.addSubview(appIcon)

        // App Name
        let nameLabel = NSTextField(labelWithString: "ClipForge")
        nameLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        nameLabel.alignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionLabel = NSTextField(labelWithString: String(format: L("settings.about.version"), version, build))
        versionLabel.alignment = .center
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(versionLabel)

        // Copyright
        let copyrightLabel = NSTextField(labelWithString: L("settings.about.copyright"))
        copyrightLabel.alignment = .center
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(copyrightLabel)

        // GitHub link
        let githubButton = NSButton(title: "github.com/J-Liu/ClipForge", target: self, action: #selector(openGitHub))
        githubButton.bezelStyle = .rounded
        githubButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(githubButton)

        // Check for Updates button
        let checkUpdatesButton = NSButton(title: L("menu.app.checkForUpdates"), target: self, action: #selector(checkForUpdates))
        checkUpdatesButton.bezelStyle = .rounded
        checkUpdatesButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(checkUpdatesButton)

        NSLayoutConstraint.activate([
            appIcon.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
            appIcon.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            nameLabel.topAnchor.constraint(equalTo: appIcon.bottomAnchor, constant: 16),
            nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            versionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            versionLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            copyrightLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 8),
            copyrightLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            githubButton.topAnchor.constraint(equalTo: copyrightLabel.bottomAnchor, constant: 24),
            githubButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            checkUpdatesButton.topAnchor.constraint(equalTo: githubButton.bottomAnchor, constant: 12),
            checkUpdatesButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            checkUpdatesButton.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20)
        ])

        return container
    }

    // MARK: - Key Handlers

    private func setupKeyHandlers() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            if event.keyCode == 53 { // Esc
                self.close()
                return nil
            }
            if event.modifierFlags.contains(.command) && event.keyCode == 13 { // Cmd+W
                self.close()
                return nil
            }
            return event
        }
    }

    // MARK: - Actions

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        guard let lang = sender.selectedItem?.representedObject as? Language else { return }
        LocalizationManager.shared.setLanguage(lang)
    }

    @objc private func quitCheckboxChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "quitAfterLastWindowClosed")
    }

    @objc private func dontHideCheckboxChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "dontHideWindow")
    }

    @objc private func countdownChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? Int else { return }
        UserDefaults.standard.set(value, forKey: "countdownSeconds")
    }

    @objc private func updateFrequencyChanged(_ sender: NSPopUpButton) {
        guard let freq = sender.selectedItem?.representedObject as? UpdateCheckFrequency else { return }
        Settings.shared.updateCheckFrequency = freq
    }

    @objc private func checkForUpdates() {
        AppActions.shared.checkForUpdates()
    }

    @objc private func logEnabledChanged(_ sender: NSButton) {
        Settings.shared.logEnabled = (sender.state == .on)
    }

    @objc private func revealLogFile() {
        guard let path = Logger.shared.logFilePath else { return }
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
    }

    // Recording actions
    @objc private func recordingModeChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? String,
              let mode = RecordingMode(rawValue: value) else { return }
        Settings.shared.recordingMode = mode
    }

    @objc private func buttonStyleChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "recordingButtonStyle")
    }

    @objc private func systemAudioChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "captureSystemAudio")
    }

    @objc private func microphoneChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "captureMicrophone")
        // Enable/disable gain slider
        if let gainSlider = recordingTab.findView(withIdentifier: NSUserInterfaceItemIdentifier("gainSlider")) as? NSSlider {
            gainSlider.isEnabled = sender.state == .on
        }
    }

    @objc private func gainSliderChanged(_ sender: NSSlider) {
        UserDefaults.standard.set(sender.doubleValue, forKey: "microphoneGain")
        if let gainValue = recordingTab.findView(withIdentifier: NSUserInterfaceItemIdentifier("gainValue")) as? NSTextField {
            gainValue.stringValue = String(format: "%.1f×", sender.doubleValue)
        }
    }

    @objc private func recordingFrameRateChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? Int else { return }
        UserDefaults.standard.set(value, forKey: "frameRate")
    }

    @objc private func codecChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "videoCodec")
    }

    @objc private func recordingFormatChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "recordingFormat")
    }

    @objc private func cursorChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "showsCursor")
    }

    @objc private func dontHideRecordChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "dontHideWindow")
    }

    @objc private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = Settings.shared.recordingOutputDirectory
        if panel.runModal() == .OK, let url = panel.url {
            Settings.shared.recordingOutputDirectory = url
            // Update the text field with identifier "outputPath"
            if let pathField = recordingTab.findView(withIdentifier: NSUserInterfaceItemIdentifier("outputPath")) as? NSTextField {
                pathField.stringValue = url.path
            }
        }
    }

    @objc private func revealOutputFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: Settings.shared.recordingOutputDirectory.path)
    }

    // Editing actions
    @objc private func autoPlayChanged(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "autoPlayOnOpen")
    }

    @objc private func playbackEndChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "playbackEndBehavior")
    }

    @objc private func exportResolutionChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "exportResolution")
    }

    @objc private func exportFrameRateChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "exportFrameRate")
    }

    @objc private func exportFormatChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? String else { return }
        UserDefaults.standard.set(value, forKey: "exportFormat")
    }

    @objc private func videoBitRateChanged(_ sender: NSPopUpButton) {
        guard let value = sender.selectedItem?.representedObject as? String else { return }
        Settings.shared.videoBitRate = value
    }

    // About actions
    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/J-Liu/ClipForge") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Tab Selection

    func selectTab(withIdentifier identifier: String) {
        tabView.selectTabViewItem(withIdentifier: identifier)
    }

    /// Returns the identifier of the currently selected tab.
    func currentTabIdentifier() -> String? {
        return tabView.selectedTabViewItem?.identifier as? String
    }

    // MARK: - UI Recreation

    private func recreateUI() {
        self.title = L("menu.app.settings").replacingOccurrences(of: "…", with: "")

        while let tab = tabView.tabViewItems.first {
            tabView.removeTabViewItem(tab)
        }

        generalTab = createGeneralTab()
        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = L("settings.tab.general")
        generalItem.view = generalTab
        tabView.addTabViewItem(generalItem)

        recordingTab = createRecordingTab()
        let recordingItem = NSTabViewItem(identifier: "recording")
        recordingItem.label = L("settings.tab.recording")
        recordingItem.view = recordingTab
        tabView.addTabViewItem(recordingItem)

        editingTab = createEditingTab()
        let editingItem = NSTabViewItem(identifier: "editing")
        editingItem.label = L("settings.tab.editing")
        editingItem.view = editingTab
        tabView.addTabViewItem(editingItem)

        aboutTab = createAboutTab()
        let aboutItem = NSTabViewItem(identifier: "about")
        aboutItem.label = L("settings.tab.about")
        aboutItem.view = aboutTab
        tabView.addTabViewItem(aboutItem)
    }
}

// MARK: - NSTextFieldDelegate

extension SettingsWindow: NSTextFieldDelegate {
    /// Only allow digits in the recent file count field
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Handle tab/return/escape to end editing
        if commandSelector == #selector(NSResponder.insertTab(_:)) ||
           commandSelector == #selector(NSResponder.insertNewline(_:)) ||
           commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            control.window?.makeFirstResponder(nil)
            return true
        }
        return false
    }

    /// Filter non-digit characters in real-time
    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField.identifier?.rawValue == "recentFileCount" else { return }

        // Only keep digits
        let filtered = textField.stringValue.filter { $0.isNumber }
        if filtered != textField.stringValue {
            textField.stringValue = filtered
        }
    }

    /// Clamp value when editing ends
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField,
              textField.identifier?.rawValue == "recentFileCount" else { return }
        let value = Int(textField.stringValue) ?? 20
        let clampedValue = max(0, min(100, value))
        textField.stringValue = String(clampedValue)
        Settings.shared.recentFileCount = clampedValue
    }
}

// MARK: - NSView Extension for Finding Subviews

extension NSView {
    func findView(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSView? {
        if self.identifier == identifier { return self }
        for subview in subviews {
            if let found = subview.findView(withIdentifier: identifier) {
                return found
            }
        }
        return nil
    }
}

// MARK: - NSTabViewDelegate

extension SettingsWindow: NSTabViewDelegate {
    /// End editing when switching tabs
    func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        // End editing on current first responder
        makeFirstResponder(nil)
        return true
    }
}

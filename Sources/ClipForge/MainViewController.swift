import AppKit
import AVFoundation
import ScreenCaptureKit

class MainViewController: NSViewController {
    private let playerController = PlayerController()
    private let playerView = PlayerView()

    private let openButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "folder", accessibilityDescription: "Open")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()
    private let playButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let currentTimeLabel = NSTextField(labelWithString: "00:00.000")
    private let durationLabel = NSTextField(labelWithString: "00:00.000")

    /// Set to true while the user is dragging the slider, so periodic
    /// time updates don't fight with the drag position.
    private var isScrubbing = false

    private let timeInputView = TimeInputView()

    private let segmentBar = SegmentBarView()
    private let setButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "scissors", accessibilityDescription: "Set cut point")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()
    private var cutPoints: [CMTime] = []
    private var segments: [Segment] = []
    private var isSkipping = false

    private let exportButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "arrow.down.doc",
                                        accessibilityDescription: "Export")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()

    private let cropOverlay = CropOverlayView()
    private var videoNaturalSize: CGSize = .zero
    private var cropRect: NSRect?   // in video pixel coordinates, nil = no crop

    private let recorder = RecorderController()
    private let recordButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "record.circle",
                                        accessibilityDescription: "Record")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        b.imagePosition = .imageLeading
        return b
    }()

    private let recordModeMenu = NSMenu()
    private let separator: NSBox = {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }()

    private let statusBar = StatusBarController()
    private let dontHideCheckbox = NSButton(checkboxWithTitle: "Don't hide", target: nil, action: nil)

    private let windowPicker = WindowPickerOverlay()
    private let regionPicker = RegionPickerOverlay()

    private let volumeSlider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let muteButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "speaker.wave.2.fill",
                                        accessibilityDescription: "Mute")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateRecordButtonIcon()
        applyVolume()
        updateMuteButtonIcon()

        statusBar.show()
        statusBar.onCancel = { [weak self] in
            self?.cancelRecordingCountdown()
        }
        statusBar.onStop = { [weak self] in
            self?.stopRecording()
        }
        statusBar.onTogglePause = { [weak self] in
            self?.togglePauseRecording()
        }

        setupCallbacks()
    }

    private func setupUI() {
        playerView.translatesAutoresizingMaskIntoConstraints = false
        openButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        timeInputView.translatesAutoresizingMaskIntoConstraints = false
        segmentBar.translatesAutoresizingMaskIntoConstraints = false
        setButton.translatesAutoresizingMaskIntoConstraints = false
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        cropOverlay.translatesAutoresizingMaskIntoConstraints = false
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        dontHideCheckbox.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        muteButton.translatesAutoresizingMaskIntoConstraints = false

        setButton.target = self
        setButton.action = #selector(addCutPoint)

        openButton.target = self
        openButton.action = #selector(openFile)

        playButton.target = self
        playButton.action = #selector(togglePlay)

        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.isContinuous = true
        // Detect drag start/end via the cell's send action behavior.
        slider.sendAction(on: [.leftMouseDown, .leftMouseDragged, .leftMouseUp])

        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        durationLabel.textColor = .secondaryLabelColor
        durationLabel.alignment = .right

        exportButton.target = self
        exportButton.action = #selector(exportVideo)

        dontHideCheckbox.target = self
        dontHideCheckbox.action = #selector(dontHideChanged)
        dontHideCheckbox.state = Settings.shared.dontHideWindow ? .on : .off

        recordButton.target = self
        recordButton.action = #selector(recordButtonPressed)
        recordButton.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Long-press or right-click shows the mode menu.
        // For simplicity, we use a separate small button for the dropdown.
        let menuButton = NSButton(image: NSImage(systemSymbolName: "chevron.down",
                                                  accessibilityDescription: "Mode")!,
                                  target: self,
                                  action: #selector(showRecordModeMenu))
        menuButton.isBordered = false
        // menuButton.bezelStyle = .rounded
        menuButton.translatesAutoresizingMaskIntoConstraints = false

        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged)
        volumeSlider.isContinuous = true
        volumeSlider.doubleValue = Double(Settings.shared.volume)

        muteButton.target = self
        muteButton.action = #selector(toggleMute)

        view.addSubview(playerView)
        view.addSubview(openButton)
        view.addSubview(playButton)
        view.addSubview(slider)
        view.addSubview(currentTimeLabel)
        view.addSubview(durationLabel)
        view.addSubview(timeInputView)
        view.addSubview(segmentBar)
        view.addSubview(setButton)
        view.addSubview(exportButton)
        view.addSubview(cropOverlay)
        view.addSubview(recordButton)
        view.addSubview(menuButton)
        view.addSubview(separator)
        view.addSubview(dontHideCheckbox)
        view.addSubview(volumeSlider)
        view.addSubview(muteButton)

        timeInputView.onSeek = { [weak self] time in
            self?.playerController.seek(to: time)
            self?.currentTimeLabel.stringValue = TimeFormatter.displayString(from: time)
        }

        segmentBar.onSegmentClicked = { [weak self] index in
            self?.toggleSegment(at: index)
        }

        segmentBar.onCutPointDragged = { [weak self] index, time in
            guard let self, index < self.cutPoints.count else { return }
            self.cutPoints[index] = time
            self.rebuildSegments()
            // Update the time input field live.
            self.timeInputView.setTime(time)
            self.currentTimeLabel.stringValue = TimeFormatter.displayString(from: time)
        }

        segmentBar.onCutPointDragEnded = { [weak self] index, time in
            guard let self, index < self.cutPoints.count else { return }
            self.cutPoints[index] = time
            self.cutPoints.sort { CMTimeGetSeconds($0) < CMTimeGetSeconds($1) }
            self.rebuildSegments()
            self.playerController.seek(to: time)
        }

        segmentBar.onCutPointDeleted = { [weak self] index in
            guard let self, index < self.cutPoints.count else { return }
            self.cutPoints.remove(at: index)
            self.rebuildSegments()
        }

        // Pin to playerView exactly.
        NSLayoutConstraint.activate([
            cropOverlay.topAnchor.constraint(equalTo: playerView.topAnchor),
            cropOverlay.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
            cropOverlay.trailingAnchor.constraint(equalTo: playerView.trailingAnchor),
            cropOverlay.bottomAnchor.constraint(equalTo: playerView.bottomAnchor)
        ])

        cropOverlay.onSelectionChanged = { [weak self] rect in
            self?.updateCropRect(from: rect)
        }

        NSLayoutConstraint.activate([
            // Player view — fills the top, bottom anchored above the segment bar.
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: segmentBar.topAnchor, constant: -12),

            // Segment bar — above the slider.
            segmentBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentBar.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: -6),
            segmentBar.heightAnchor.constraint(equalToConstant: 14),

            // Slider — above row 1.
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            slider.bottomAnchor.constraint(equalTo: openButton.topAnchor, constant: -12),

            // Row 1: Open | Play/Pause | currentTime ......... duration
            openButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            openButton.bottomAnchor.constraint(equalTo: setButton.topAnchor, constant: -8),

            playButton.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 8),
            playButton.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),

            currentTimeLabel.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 12),
            currentTimeLabel.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),

            durationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            durationLabel.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 80),

            // Row 2: Set | timeInputView
            setButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            setButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            timeInputView.leadingAnchor.constraint(equalTo: setButton.trailingAnchor, constant: 12),
            timeInputView.centerYAnchor.constraint(equalTo: setButton.centerYAnchor),

            // Export button now sits after timeInputView, on the left group.
            exportButton.leadingAnchor.constraint(equalTo: timeInputView.trailingAnchor, constant: 12),
            exportButton.centerYAnchor.constraint(equalTo: setButton.centerYAnchor),

            // Separator — pushed to the right by a flexible spacer.
            separator.leadingAnchor.constraint(greaterThanOrEqualTo: exportButton.trailingAnchor, constant: 12),
            separator.trailingAnchor.constraint(equalTo: recordButton.leadingAnchor, constant: -12),
            separator.centerYAnchor.constraint(equalTo: setButton.centerYAnchor),
            separator.heightAnchor.constraint(equalToConstant: 20),
            separator.widthAnchor.constraint(equalToConstant: 1),

            recordButton.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -4),
            recordButton.centerYAnchor.constraint(equalTo: setButton.centerYAnchor),

            menuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            menuButton.centerYAnchor.constraint(equalTo: setButton.centerYAnchor),

            dontHideCheckbox.trailingAnchor.constraint(equalTo: recordButton.leadingAnchor, constant: -8),
            dontHideCheckbox.centerYAnchor.constraint(equalTo: setButton.centerYAnchor),

            volumeSlider.trailingAnchor.constraint(equalTo: muteButton.leadingAnchor, constant: -8),
            volumeSlider.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),
            volumeSlider.widthAnchor.constraint(equalToConstant: 50),

            muteButton.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -12),
            muteButton.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),
        ])
    }

    private func setupCallbacks() {
        playerController.onTimeUpdate = { [weak self] time in
            guard let self, !self.isScrubbing else { return }

            // Auto-skip removed segments.
            if !self.isSkipping, !self.segments.isEmpty {
                if let current = self.segments.first(where: { $0.contains(time) }), !current.isKept {
                    self.isSkipping = true
                    // Jump to the next kept segment's start.
                    if let nextKept = self.segments.first(where: {
                        CMTimeCompare($0.start, current.end) >= 0 && $0.isKept
                    }) {
                        self.playerController.seek(to: nextKept.start)
                    } else {
                        // No kept segment after; jump to end.
                        self.playerController.seek(to: self.playerController.totalDuration)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isSkipping = false
                    }
                    return
                }
            }

            self.currentTimeLabel.stringValue = TimeFormatter.displayString(from: time)
            self.updateSliderPosition(for: time)
            self.timeInputView.setTime(time)
            updatePlayButtonIcon()
        }

        playerController.onPlaybackEnded = { [weak self] in
            self?.playerController.seek(to: .zero)
            self?.updatePlayButtonIcon()
        }
    }

    private func updateSliderPosition(for time: CMTime) {
        let duration = CMTimeGetSeconds(playerController.totalDuration)
        guard duration > 0 else { return }
        let current = CMTimeGetSeconds(time)
        slider.doubleValue = current / duration
    }

    // MARK: - Actions

    func openFileAction() { openFile() }
    func exportVideoAction() { exportVideo() }
    func togglePlayAction() { togglePlay() }
    func recordButtonPressedAction() { recordButtonPressed() }

    func setRecordingMode(_ mode: RecordingMode) {
        Settings.shared.recordingMode = mode
        updateRecordButtonIcon()
        rebuildRecordModeMenu()
    }

    @objc private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            let urls = panel.urls
            guard !urls.isEmpty else { return }
            self?.loadVideos(urls: urls)
        }
    }

    private func loadVideos(urls: [URL], preserveEdits: Bool = false) {
        playerController.load(urls: urls)
        playerView.attach(player: playerController.player)

        if !preserveEdits {
            cutPoints = []
        }
        rebuildSegments()

        // Update duration label after durations load.
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self.durationLabel.stringValue = TimeFormatter.displayString(from: self.playerController.totalDuration)
            }
        }

        // Load natural size of the first video for the crop overlay.
        guard let firstURL = urls.first else { return }
        Task {
            let asset = AVURLAsset(url: firstURL)
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let size = try? await track.load(.naturalSize)
                await MainActor.run {
                    self.videoNaturalSize = size ?? .zero
                    self.updateOverlayContentRect()
                }
            }
        }

        // Auto-play only if the user opted in.
        if Settings.shared.autoPlayOnOpen {
            playerController.play()
        } else {
            // Show the first frame without playing.
            playerController.seek(to: .zero)
        }
        updatePlayButtonIcon()
    }

    func appendVideoAction() { appendVideo() }

    @objc private func appendVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK, let self else { return }
            let urls = panel.urls
            guard !urls.isEmpty else { return }
            self.appendVideos(urls: urls)
        }
    }

    private func appendVideos(urls: [URL]) {
        guard let currentURLs = playerController.urls.isEmpty ? nil : playerController.urls else {
            // No current video — treat as a fresh load.
            loadVideos(urls: urls)
            return
        }
        let combined = currentURLs + urls
        // Preserve existing cutPoints and segments, but their times are on the old timeline.
        // For now, reload the whole thing.
        loadVideos(urls: combined)
    }

    @objc private func togglePlay() {
        playerController.togglePlay()
        updatePlayButtonIcon()
    }

    private func updatePlayButtonIcon() {
        let isPlaying = playerController.player.timeControlStatus == .playing
        let name = isPlaying ? "pause.fill" : "play.fill"
        playButton.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    @objc private func sliderChanged() {
        let event = NSApp.currentEvent
        switch event?.type {
        case .leftMouseDown:
            isScrubbing = true
        case .leftMouseUp:
            isScrubbing = false
        default:
            break
        }

        // Seek to the slider position.
        let duration = CMTimeGetSeconds(playerController.totalDuration)
        guard duration > 0 else { return }
        let target = CMTime(seconds: slider.doubleValue * duration, preferredTimescale: 600)
        playerController.seek(to: target)
        currentTimeLabel.stringValue = TimeFormatter.displayString(from: target)
    }

    @objc private func addCutPoint() {
        guard playerController.totalDuration.isValid else { return }
        let current = playerController.player.currentTime()
        let total = CMTimeGetSeconds(playerController.totalDuration)
        let t = CMTimeGetSeconds(current)
        guard t > 0, t < total else { return }

        // Ignore duplicate cut points (within 1ms).
        if cutPoints.contains(where: { abs(CMTimeGetSeconds($0) - t) < 0.001 }) { return }

        cutPoints.append(current)
        cutPoints.sort { CMTimeGetSeconds($0) < CMTimeGetSeconds($1) }
        rebuildSegments()
    }

    private func rebuildSegments() {
        let total = playerController.totalDuration
        guard total.isValid, CMTimeGetSeconds(total) > 0 else {
            segments = []
            segmentBar.segments = []
            return
        }

        // Preserve existing isKept states by matching ranges.
        let oldSegments = segments

        var boundaries: [CMTime] = [.zero]
        boundaries.append(contentsOf: cutPoints)
        boundaries.append(total)

        var newSegments: [Segment] = []
        for i in 0..<(boundaries.count - 1) {
            let start = boundaries[i]
            let end = boundaries[i + 1]
            let range = CMTimeRange(start: start, end: end)
            // Try to inherit isKept from an old segment with the same start.
            let matched = oldSegments.first(where: { CMTimeCompare($0.start, start) == 0 })
            let inherited: Bool = matched?.isKept ?? true
            newSegments.append(Segment(range: range, isKept: inherited))
        }

        segments = newSegments
        segmentBar.segments = newSegments
        segmentBar.totalDuration = total
        segmentBar.cutPoints = cutPoints
    }

    private func toggleSegment(at index: Int) {
        guard index >= 0, index < segments.count else { return }
        segments[index].isKept.toggle()
        segmentBar.segments = segments
    }

    @objc private func exportVideo() {
        guard !playerController.urls.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        panel.nameFieldStringValue = "ClipForge-\(timestamp).mp4"
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let outputURL = panel.url else { return }
            self?.performExport(outputURL: outputURL)
        }
    }

    private func performExport(outputURL: URL) {
        // Pause playback during export.
        playerController.pause()

        // Simple blocking-free progress: use the window title.
        let originalTitle = view.window?.title ?? "ClipForge"
        view.window?.title = "Exporting… 0%"

        CompositionBuilder.export(
            clips: playerController.clips,
            segments: segments,
            cropRect: cropRect,
            outputURL: outputURL,
            progress: { [weak self] value in
                self?.view.window?.title = String(format: "Exporting… %.0f%%", value * 100)
            },
            completion: { [weak self] result in
                self?.view.window?.title = originalTitle
                switch result {
                case .success:
                    self?.showAlert(title: "Export Complete",
                                    message: outputURL.lastPathComponent)
                case .failure(let error):
                    self?.showAlert(title: "Export Failed",
                                    message: error.localizedDescription)
                }
            }
        )
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateOverlayContentRect()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(playerView)
    }

    private func updateOverlayContentRect() {
        guard videoNaturalSize.width > 0 else { return }
        let displayRect = playerView.videoDisplayRect(for: videoNaturalSize)

        cropOverlay.contentRect = displayRect
    }

    private func updateCropRect(from selectionRect: NSRect) {
        guard videoNaturalSize.width > 0 else { return }
        let displayRect = cropOverlay.contentRect
        guard displayRect.width > 0, displayRect.height > 0 else { return }

        let scaleX = videoNaturalSize.width / displayRect.width
        let scaleY = videoNaturalSize.height / displayRect.height

        let cropX = (selectionRect.minX - displayRect.minX) * scaleX
        let cropY = (selectionRect.minY - displayRect.minY) * scaleY
        let cropW = selectionRect.width * scaleX
        let cropH = selectionRect.height * scaleY

        // Force even dimensions — H.264 requires it.
        let evenW = floor(cropW / 2) * 2
        let evenH = floor(cropH / 2) * 2

        cropRect = NSRect(x: cropX, y: cropY, width: evenW, height: evenH)
    }

    @objc private func startRecording() {
        // Disable UI during countdown.
        recordButton.isEnabled = false

        statusBar.startCountdown(onTick: { _ in
            // The status bar handles its own display.
        }, onFinish: { [weak self] in
            self?.beginActualRecording()
        })
    }

    private func beginActualRecording() {
        recorder.startRecording { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(title: "Recording Failed", message: error.localizedDescription)
                self.statusBar.setState(.idle)
                self.recordButton.isEnabled = true
                return
            }
            self.statusBar.setState(.recording)
            if self.dontHideCheckbox.state == .off {
                self.view.window?.orderOut(nil)
            }
        }
    }

    private func cancelRecordingCountdown() {
        statusBar.setState(.idle)
        recordButton.isEnabled = true
    }

    private func togglePauseRecording() {
        // Placeholder: ScreenCaptureKit doesn't have a native pause.
        // We'll implement pause by stopping and restarting, or by
        // ignoring frames during the pause window.
        // For now, just toggle the status bar state.
        switch statusBar.state {
        case .recording:
            statusBar.setState(.paused)
        case .paused:
            statusBar.setState(.recording)
        default:
            break
        }
    }

    @objc private func stopRecording() {
        recorder.stopRecording { [weak self] url in
            DispatchQueue.main.async {
                guard let self else { return }
                self.statusBar.setState(.idle)
                self.recordButton.isEnabled = true
                self.view.window?.makeKeyAndOrderFront(nil)
                if let url = url {
                    self.showAlert(title: "Recording Saved", message: url.path)
                } else {
                    self.showAlert(title: "Recording Failed", message: "No file was written.")
                }
            }
        }
    }

    @objc private func startWindowRecording() {
        Task {
            guard let content = try? await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            ) else { return }

            // Filter out our own windows and tiny windows.
            let myBundleID = Bundle.main.bundleIdentifier
            let candidates = content.windows.filter {
                $0.isOnScreen &&
                $0.frame.width > 100 &&
                $0.frame.height > 100 &&
                $0.owningApplication?.bundleIdentifier != myBundleID &&
                $0.owningApplication?.bundleIdentifier != "com.apple.dock" &&
                $0.owningApplication?.bundleIdentifier != "com.apple.finder" &&
                $0.windowLayer == 0   // normal app windows only
            }

            await MainActor.run {
                self.windowPicker.onPick = { [weak self] window in
                    self?.beginWindowRecordingAfterCountdown(window: window)
                }
                self.windowPicker.onCancel = {
                    // Nothing to do; overlay already dismissed.
                }
                self.windowPicker.present(targetWindows: candidates)
            }
        }
    }

    private func beginWindowRecordingAfterCountdown(window: SCWindow) {
        recordButton.isEnabled = false
        statusBar.startCountdown(onTick: { _ in }, onFinish: { [weak self] in
            self?.beginWindowRecording(window: window)
        })
    }

    private func beginWindowRecording(window: SCWindow) {
        recorder.startWindowRecording(window: window) { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(title: "Recording Failed", message: error.localizedDescription)
                self.statusBar.setState(.idle)
                self.recordButton.isEnabled = true
                return
            }
            self.statusBar.setState(.recording)
            if self.dontHideCheckbox.state == .off {
                self.view.window?.orderOut(nil)
            }
        }
    }

    @objc private func startRegionRecording() {
        regionPicker.onPick = { [weak self] screenRect in
            self?.beginRegionRecordingAfterCountdown(region: screenRect)
        }
        regionPicker.onCancel = { }
        regionPicker.present()
    }

    private func beginRegionRecordingAfterCountdown(region: NSRect) {
        recordButton.isEnabled = false
        statusBar.startCountdown(onTick: { _ in }, onFinish: { [weak self] in
            self?.beginRegionRecording(region: region)
        })
    }

    private func beginRegionRecording(region: NSRect) {
        recorder.startRegionRecording(region: region) { [weak self] error in
            guard let self else { return }
            if let error = error {
                self.showAlert(title: "Recording Failed", message: error.localizedDescription)
                self.statusBar.setState(.idle)
                self.recordButton.isEnabled = true
                return
            }
            self.statusBar.setState(.recording)
            if self.dontHideCheckbox.state == .off {
                self.view.window?.orderOut(nil)
            }
        }
    }

    private func rebuildRecordModeMenu() {
        recordModeMenu.removeAllItems()

        let modes: [(RecordingMode, String, String)] = [
            (.fullScreen, "Full Screen", "rectangle.inset.filled"),
            (.window, "Window", "macwindow"),
            (.region, "Region", "rectangle.dashed")
        ]

        for (mode, title, iconName) in modes {
            let item = NSMenuItem(title: title,
                                  action: #selector(selectRecordingMode(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            if Settings.shared.recordingMode == mode {
                item.state = .on
            }
            recordModeMenu.addItem(item)
        }
    }

    private func updateRecordButtonIcon() {
        let name: String
        switch Settings.shared.recordingMode {
        case .fullScreen: name = "rectangle.inset.filled"
        case .window:     name = "macwindow"
        case .region:     name = "rectangle.dashed"
        }
        recordButton.image = NSImage(systemSymbolName: name, accessibilityDescription: "Record")
    }

    @objc private func showRecordModeMenu() {
        rebuildRecordModeMenu()
        let point = NSPoint(x: 0, y: recordButton.bounds.height)
        recordModeMenu.popUp(positioning: nil, at: point, in: recordButton)
    }

    @objc private func recordButtonPressed() {
        switch Settings.shared.recordingMode {
        case .fullScreen:
            startRecording()
        case .window:
            startWindowRecording()
        case .region:
            startRegionRecording()
        }
    }

    @objc private func selectRecordingMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = RecordingMode(rawValue: raw) else { return }
        setRecordingMode(mode)
    }

    /// Step playback by N frames (positive = forward).
    func stepFrames(_ count: Int) {
        guard playerController.totalDuration.isValid else { return }
        let current = CMTimeGetSeconds(playerController.player.currentTime())
        // Assume 30 fps; refine when we expose frame rate in settings.
        let frameDuration = 1.0 / 30.0
        let target = max(0, min(
            current + Double(count) * frameDuration,
            CMTimeGetSeconds(playerController.totalDuration)
        ))
        playerController.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    /// Seek by a relative number of seconds.
    func seek(bySeconds seconds: Double) {
        playerController.seek(bySeconds: seconds)
    }

    @objc private func dontHideChanged() {
        Settings.shared.dontHideWindow = (dontHideCheckbox.state == .on)
    }

    @objc private func volumeChanged() {
        let v = Float(volumeSlider.doubleValue)
        Settings.shared.volume = v
        if v <= 0 {
            Settings.shared.isMuted = true
        } else if Settings.shared.isMuted {
            Settings.shared.isMuted = false
        }
        applyVolume()
        updateMuteButtonIcon()
    }

    @objc private func toggleMute() {
        Settings.shared.isMuted.toggle()
        applyVolume()
        updateMuteButtonIcon()
        updateVolumeSlider()
    }

    private func applyVolume() {
        let effective = Settings.shared.isMuted ? 0 : Settings.shared.volume
        playerController.player.volume = effective
    }

    private func updateMuteButtonIcon() {
        let name = Settings.shared.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteButton.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    func toggleMuteAction() { toggleMute() }

    func adjustVolume(by delta: Float) {
        let base = Settings.shared.isMuted ? 0 : Settings.shared.volume
        let v = max(0, min(1, base + delta))
        Settings.shared.volume = v
        if v <= 0 {
            Settings.shared.isMuted = true
        } else if Settings.shared.isMuted {
            Settings.shared.isMuted = false
        }
        applyVolume()
        updateMuteButtonIcon()
        updateVolumeSlider()
    }

    private func updateVolumeSlider() {
        let effective = Settings.shared.isMuted ? 0 : Settings.shared.volume
        volumeSlider.doubleValue = Double(effective)
    }
}

import AppKit
import AVFoundation
import ScreenCaptureKit
import SwiftUI
import UniformTypeIdentifiers

class MainViewController: NSViewController {
    let playerController = PlayerController()
    let playerView = PlayerView()

    let openButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "folder", accessibilityDescription: "Open")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()
    let playButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()
    let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    let currentTimeLabel = NSTextField(labelWithString: "00:00.000")
    let durationLabel = NSTextField(labelWithString: "00:00.000")

    var isScrubbing = false

    let timeInputView = TimeInputView()

    let segmentBar = SegmentBarView()
    let setButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "scissors", accessibilityDescription: "Set cut point")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()
    var cutPoints: [CMTime] = []
    var segments: [Segment] = []
    var isSkipping = false

    let exportButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "arrow.down.doc",
                                        accessibilityDescription: "Export")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        return b
    }()

    let cropOverlay = CropOverlayView()
    var videoNaturalSize: CGSize = .zero
    var cropRect: NSRect?

    let recorder = RecorderController()
    let recordButton: NSButton = {
        let b = NSButton(image: NSImage(systemSymbolName: "record.circle",
                                        accessibilityDescription: "Record")!,
                         target: nil, action: nil)
        b.bezelStyle = .rounded
        b.imagePosition = .imageLeading
        return b
    }()

    let recordModeMenu = NSMenu()
    let separator: NSBox = {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }()

    let statusBar = StatusBarController()
    let dontHideCheckbox = NSButton(checkboxWithTitle: "Don't hide", target: nil, action: nil)

    let windowPicker = WindowPickerOverlay()
    let regionPicker = RegionPickerOverlay()

    let volumeSlider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
    let muteButton: NSButton = {
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

        playerController.onClipsLoaded = { [weak self] in
            guard let self else { return }
            self.refreshTimelineUI()
            self.durationLabel.stringValue = TimeFormatter.displayString(
                from: self.playerController.totalDuration
            )
        }

        recorder.onUnexpectedStop = { [weak self] error in
            guard let self else { return }
            self.showError(ClipForgeError.from(error))
            self.statusBar.setState(.idle)
            self.recordButton.isEnabled = true
            // Try to save whatever was recorded.
            self.recorder.stopRecording { url in
                if let url = url {
                    self.showAlert(title: "Recording Saved (partial)",
                                   message: url.path)
                }
            }
        }

        setupCallbacks()
    }

    func setupUI() {
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

        let menuButton = NSButton(image: NSImage(systemSymbolName: "chevron.down",
                                                  accessibilityDescription: "Mode")!,
                                  target: self,
                                  action: #selector(showRecordModeMenu))
        menuButton.isBordered = false
        menuButton.translatesAutoresizingMaskIntoConstraints = false

        volumeSlider.target = self
        volumeSlider.action = #selector(volumeChanged)
        volumeSlider.isContinuous = true
        volumeSlider.doubleValue = Double(Settings.shared.volume)

        muteButton.target = self
        muteButton.action = #selector(toggleMute)

        segmentBar.onCutPointAdded = { [weak self] time in
            self?.addCutPointAt(time)
        }
        segmentBar.toolTip = "Click to add a cut point. Right-click a segment to keep/remove it. Double-click a cut point to delete."

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
            self.registerUndo()
            self.cutPoints.remove(at: index)
            self.rebuildSegments()
        }

        segmentBar.onCutPointDragBegan = { [weak self] in
            self?.registerUndo()
        }

        NSLayoutConstraint.activate([
            cropOverlay.topAnchor.constraint(equalTo: playerView.topAnchor),
            cropOverlay.leadingAnchor.constraint(equalTo: playerView.leadingAnchor),
            cropOverlay.trailingAnchor.constraint(equalTo: playerView.trailingAnchor),
            cropOverlay.bottomAnchor.constraint(equalTo: playerView.bottomAnchor)
        ])

        cropOverlay.onSelectionChanged = { [weak self] rect in
            self?.updateCropRect(from: rect)
        }

        playerView.onFilesDropped = { [weak self] urls, replace in
            guard let self else { return }
            if replace || self.playerController.urls.isEmpty {
                self.loadVideos(urls: urls)
            } else {
                self.appendVideos(urls: urls)
            }
        }

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: segmentBar.topAnchor, constant: -12),

            segmentBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentBar.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: -6),
            segmentBar.heightAnchor.constraint(equalToConstant: 14),

            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            slider.bottomAnchor.constraint(equalTo: openButton.topAnchor, constant: -12),

            openButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            openButton.bottomAnchor.constraint(equalTo: setButton.topAnchor, constant: -8),

            playButton.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 8),
            playButton.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),

            currentTimeLabel.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 12),
            currentTimeLabel.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),

            durationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            durationLabel.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 80),

            setButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            setButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            timeInputView.leadingAnchor.constraint(equalTo: setButton.trailingAnchor, constant: 12),
            timeInputView.centerYAnchor.constraint(equalTo: setButton.centerYAnchor),

            exportButton.leadingAnchor.constraint(equalTo: timeInputView.trailingAnchor, constant: 12),
            exportButton.centerYAnchor.constraint(equalTo: setButton.centerYAnchor),

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

    func setupCallbacks() {
        playerController.onTimeUpdate = { [weak self] time in
            guard let self, !self.isScrubbing else { return }

            if !self.isSkipping, !self.segments.isEmpty {
                if let current = self.segments.first(where: { $0.contains(time) }), !current.isKept {
                    self.isSkipping = true
                    if let nextKept = self.segments.first(where: {
                        CMTimeCompare($0.start, current.end) >= 0 && $0.isKept
                    }) {
                        self.playerController.seek(to: nextKept.start)
                    } else {
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
            self.updatePlayButtonIcon()
        }

        playerController.onPlaybackEnded = { [weak self] in
            self?.playerController.seek(to: .zero)
            self?.updatePlayButtonIcon()
        }
    }

    func updateSliderPosition(for time: CMTime) {
        let duration = CMTimeGetSeconds(playerController.totalDuration)
        guard duration > 0 else { return }
        let current = CMTimeGetSeconds(time)
        slider.doubleValue = current / duration
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        updateOverlayContentRect()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(playerView)
    }

    func showAlert(title: String, message: String, recovery: String? = nil) {
        let alert = NSAlert()
        alert.messageText = title
        var info = message
        if let recovery = recovery, !recovery.isEmpty {
            if !info.isEmpty {
                info += "\n\n"
            }
            info += recovery
        }
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    func showError(_ error: Error) {
        let cf = ClipForgeError.from(error)
        let alert = NSAlert()
        alert.messageText = cf.errorDescription ?? "Error"
        alert.informativeText = cf.recoverySuggestion ?? ""
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        // Special case: permission errors offer a shortcut to System Settings.
        switch cf {
        case .screenRecordingPermissionDenied, .microphonePermissionDenied:
            alert.addButton(withTitle: "Open System Settings")
        default:
            break
        }

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            if response == .alertSecondButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                NSWorkspace.shared.open(url)
            }
        }

        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }

    // MARK: - Actions exposed to AppActions

    func openFileAction() { openFile() }
    func appendVideoAction() { appendVideo() }
    func exportVideoAction() { exportVideo() }
    func togglePlayAction() { togglePlay() }
    func recordButtonPressedAction() { recordButtonPressed() }
    func toggleMuteAction() { toggleMute() }

    func setRecordingMode(_ mode: RecordingMode) {
        Settings.shared.recordingMode = mode
        updateRecordButtonIcon()
        rebuildRecordModeMenu()
    }

    func stepFrames(_ count: Int) {
        guard playerController.totalDuration.isValid else { return }
        let globalCurrent = playerController.globalCurrentTime()
        let current = CMTimeGetSeconds(globalCurrent)
        let frameDuration = 1.0 / 30.0
        let target = max(0, min(
            current + Double(count) * frameDuration,
            CMTimeGetSeconds(playerController.totalDuration)
        ))
        playerController.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    func seek(bySeconds seconds: Double) {
        playerController.seek(bySeconds: seconds)
    }

    func resetCropSelection() {
        cropOverlay.resetSelection()
    }
}

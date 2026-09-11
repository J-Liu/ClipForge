import AppKit
import AVFoundation

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

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
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
        exportButton.target = self

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
        exportButton.action = #selector(exportVideo)

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

            // Place it on row 2, right side.
            exportButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            exportButton.centerYAnchor.constraint(equalTo: setButton.centerYAnchor),
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
                        self.playerController.seek(to: self.playerController.duration)
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
        let duration = CMTimeGetSeconds(playerController.duration)
        guard duration > 0 else { return }
        let current = CMTimeGetSeconds(time)
        slider.doubleValue = current / duration
    }

    // MARK: - Actions

    @objc private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadVideo(url: url)
        }
    }

    private func loadVideo(url: URL) {
        playerController.load(url: url)
        playerView.attach(player: playerController.player)
        playerController.play()

        cutPoints = []
        rebuildSegments()

        // Wait a tick for duration to load, then update the duration label.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.durationLabel.stringValue = TimeFormatter.displayString(from: self.playerController.duration)
        }
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
        let duration = CMTimeGetSeconds(playerController.duration)
        guard duration > 0 else { return }
        let target = CMTime(seconds: slider.doubleValue * duration, preferredTimescale: 600)
        playerController.seek(to: target)
        currentTimeLabel.stringValue = TimeFormatter.displayString(from: target)
    }

    @objc private func addCutPoint() {
        guard playerController.duration.isValid else { return }
        let current = playerController.player.currentTime()
        let total = CMTimeGetSeconds(playerController.duration)
        let t = CMTimeGetSeconds(current)
        guard t > 0, t < total else { return }

        // Ignore duplicate cut points (within 1ms).
        if cutPoints.contains(where: { abs(CMTimeGetSeconds($0) - t) < 0.001 }) { return }

        cutPoints.append(current)
        cutPoints.sort { CMTimeGetSeconds($0) < CMTimeGetSeconds($1) }
        rebuildSegments()
    }

    private func rebuildSegments() {
        let total = playerController.duration
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
        guard let sourceURL = playerController.currentURL else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "ClipForge-export.mp4"
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let outputURL = panel.url else { return }
            self?.performExport(sourceURL: sourceURL, outputURL: outputURL)
        }
    }

    private func performExport(sourceURL: URL, outputURL: URL) {
        // Pause playback during export.
        playerController.pause()

        // Simple blocking-free progress: use the window title.
        let originalTitle = view.window?.title ?? "ClipForge"
        view.window?.title = "Exporting… 0%"

        CompositionBuilder.export(
            sourceURL: sourceURL,
            segments: segments,
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
}

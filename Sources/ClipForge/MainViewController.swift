import AppKit
import AVFoundation

class MainViewController: NSViewController {
    private let playerController = PlayerController()
    private let playerView = PlayerView()

    private let openButton = NSButton(title: "Open Video…", target: nil, action: nil)
    private let playButton = NSButton(title: "Play / Pause", target: nil, action: nil)
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let currentTimeLabel = NSTextField(labelWithString: "00:00.000")
    private let durationLabel = NSTextField(labelWithString: "00:00.000")

    /// Set to true while the user is dragging the slider, so periodic
    /// time updates don't fight with the drag position.
    private var isScrubbing = false

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

        view.addSubview(playerView)
        view.addSubview(openButton)
        view.addSubview(playButton)
        view.addSubview(slider)
        view.addSubview(currentTimeLabel)
        view.addSubview(durationLabel)

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: view.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: -12),

            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            slider.bottomAnchor.constraint(equalTo: openButton.topAnchor, constant: -12),

            openButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            openButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            playButton.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 12),
            playButton.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),

            currentTimeLabel.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 12),
            currentTimeLabel.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),

            durationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            durationLabel.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 80)
        ])
    }

    private func setupCallbacks() {
        playerController.onTimeUpdate = { [weak self] time in
            guard let self, !self.isScrubbing else { return }
            self.currentTimeLabel.stringValue = TimeFormatter.displayString(from: time)
            self.updateSliderPosition(for: time)
        }

        playerController.onPlaybackEnded = { [weak self] in
            self?.playerController.seek(to: .zero)
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

        // Wait a tick for duration to load, then update the duration label.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.durationLabel.stringValue = TimeFormatter.displayString(from: self.playerController.duration)
        }
    }

    @objc private func togglePlay() {
        playerController.togglePlay()
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
}

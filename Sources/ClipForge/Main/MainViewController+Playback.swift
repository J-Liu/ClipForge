import AppKit
import AVFoundation

extension MainViewController {

    @objc func openFile() {
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

    func loadVideos(urls: [URL], preserveEdits: Bool = false) {
        playerController.load(urls: urls)
        playerView.attach(player: playerController.player)

        if !preserveEdits {
            cutPoints = []
        }
        rebuildSegments()

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

        if Settings.shared.autoPlayOnOpen {
            playerController.play()
        } else {
            playerController.seek(to: .zero)
        }
        updatePlayButtonIcon()
    }

    @objc func appendVideo() {
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

    func appendVideos(urls: [URL]) {
        guard !playerController.urls.isEmpty else {
            loadVideos(urls: urls)
            return
        }
        let combined = playerController.urls + urls
        loadVideos(urls: combined, preserveEdits: true)
    }

    @objc func togglePlay() {
        guard requireVideoLoaded() else { return }
        playerController.togglePlay()
        updatePlayButtonIcon()
    }

    func updatePlayButtonIcon() {
        let isPlaying = playerController.player.timeControlStatus == .playing
        let name = isPlaying ? "pause.fill" : "play.fill"
        playButton.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    @objc func sliderChanged() {
        let event = NSApp.currentEvent
        switch event?.type {
        case .leftMouseDown:
            isScrubbing = true
        case .leftMouseUp:
            isScrubbing = false
        default:
            break
        }

        let duration = CMTimeGetSeconds(playerController.totalDuration)
        guard duration > 0 else { return }
        let target = CMTime(seconds: slider.doubleValue * duration, preferredTimescale: 600)
        playerController.seek(to: target)
        currentTimeLabel.stringValue = TimeFormatter.displayString(from: target)
    }

    @objc func dontHideChanged() {
        Settings.shared.dontHideWindow = (dontHideCheckbox.state == .on)
    }

    @objc func volumeChanged() {
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

    @objc func toggleMute() {
        Settings.shared.isMuted.toggle()
        applyVolume()
        updateMuteButtonIcon()
        updateVolumeSlider()
    }

    func applyVolume() {
        let effective = Settings.shared.isMuted ? 0 : Settings.shared.volume
        playerController.player.volume = effective
    }

    func updateMuteButtonIcon() {
        let name = Settings.shared.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteButton.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

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

    func updateVolumeSlider() {
        let effective = Settings.shared.isMuted ? 0 : Settings.shared.volume
        volumeSlider.doubleValue = Double(effective)
    }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import AVFoundation

extension MainViewController {

    @objc func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .mp3, .wav, .audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            let urls = panel.urls
            guard !urls.isEmpty else { return }
            self?.loadVideos(urls: urls)
            if let firstURL = urls.first {
                Settings.shared.addRecentFile(firstURL)
            }
        }
    }

    func openFileAt(_ url: URL) {
        loadVideos(urls: [url])
        Settings.shared.addRecentFile(url)
    }

    func loadVideos(urls: [URL], preserveEdits: Bool = false) {
        playerController.load(urls: urls)
        playerView.attach(player: playerController.player)

        if !preserveEdits {
            cutPoints = []
        }
        rebuildSegments()

        guard let firstURL = urls.first else { return }

        // Set default audio export format based on source file extension
        let ext = firstURL.pathExtension.lowercased()
        switch ext {
        case "mp3":
            Settings.shared.audioExportFormat = "mp3"
        case "m4a", "aac":
            Settings.shared.audioExportFormat = "aac"
        case "wav":
            Settings.shared.audioExportFormat = "wav"
        default:
            break  // Keep current setting
        }

        // Load waveform for audio files
        Task {
            do {
                let data = try await WaveformLoader.load(from: firstURL)
                await MainActor.run {
                    Log("Waveform loaded: \(data.sampleCount) samples")
                    self.waveformView.setWaveformData(data)
                    self.updateWaveformVisibility()
                    Log("WaveformView hidden: \(self.waveformView.isHidden), isAudioOnly: \(self.playerController.isAudioOnly)")
                }
            } catch {
                await MainActor.run {
                    Log("Waveform load failed: \(error)")
                    self.waveformView.setWaveformData(nil)
                    self.updateWaveformVisibility()
                }
            }
        }

        Task {
            let asset = AVURLAsset(url: firstURL)
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let size = try? await track.load(.naturalSize)
                await MainActor.run {
                    self.videoNaturalSize = size ?? .zero
                    self.updateOverlayContentRect()
                    self.updateWaveformVisibility()
                }
            } else {
                // No video track - this is audio-only
                await MainActor.run {
                    self.videoNaturalSize = .zero
                    self.updateWaveformVisibility()
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

    func updateWaveformVisibility() {
        let isAudioOnly = playerController.isAudioOnly
        playerView.isHidden = isAudioOnly
        // WaveformView controls its own visibility based on having data
        // For video files, we should hide the waveform
        if !isAudioOnly {
            waveformView.isHidden = true
        }
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
    }

    func updatePlayButtonIcon() {
        let isPlaying = playerController.player.timeControlStatus == .playing
        let name = isPlaying ? "pause.fill" : "play.fill"
        playButton.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    func sliderValueChanged(_ value: Double) {
        let duration = CMTimeGetSeconds(playerController.totalDuration)
        guard duration > 0 else { return }

        let target = CMTime(seconds: value * duration, preferredTimescale: 600)
        playerController.seek(to: target)
        currentTimeLabel.stringValue = TimeFormatter.displayString(from: target)
        timeInputView.setTime(target)
        updateWaveformProgress(target)
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

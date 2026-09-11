import AppKit
import AVFoundation

class PlayerController {
    let player = AVPlayer()
    private(set) var currentURL: URL?
    private(set) var duration: CMTime = .zero

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    /// Called on the main thread whenever playback time changes.
    var onTimeUpdate: ((CMTime) -> Void)?
    /// Called on the main thread when the item finishes playing.
    var onPlaybackEnded: (() -> Void)?

    deinit {
        removeObservers()
    }

    func load(url: URL) {
        removeObservers()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        currentURL = url

        // Duration may not be available immediately; read it asynchronously.
        Task {
            let loadedDuration = try? await asset.load(.duration)
            await MainActor.run {
                self.duration = loadedDuration ?? .zero
            }
        }

        addObservers(for: item)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlay() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    /// Seek to a specific time, with optional tolerance for speed.
    func seek(to time: CMTime, toleranceBefore: CMTime = .zero, toleranceAfter: CMTime = .zero) {
        player.seek(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter)
    }

    /// Seek by a relative offset in seconds (negative = backward).
    func seek(bySeconds offset: Double) {
        guard duration.isValid else { return }
        let current = CMTimeGetSeconds(player.currentTime())
        let target = max(0, min(current + offset, CMTimeGetSeconds(duration)))
        seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    // MARK: - Observers

    private func addObservers(for item: AVPlayerItem) {
        // Periodic time observer (fires ~10 times per second).
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            self?.onTimeUpdate?(time)
        }

        // End-of-playback notification.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onPlaybackEnded?()
        }
    }

    private func removeObservers() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
    }
}

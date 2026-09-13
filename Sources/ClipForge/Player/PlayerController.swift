import AppKit
import AVFoundation

class PlayerController {
    let player = AVPlayer()
    private(set) var urls: [URL] = []
    private(set) var durations: [CMTime] = []
    private(set) var currentIndex: Int = 0

    /// Global timeline duration (sum of all videos).
    private(set) var totalDuration: CMTime = .zero

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    /// Called on the main thread whenever playback time changes.
    /// The time is the GLOBAL timeline time.
    var onTimeUpdate: ((CMTime) -> Void)?
    /// Called on the main thread when the last video finishes.
    var onPlaybackEnded: (() -> Void)?
    /// Called when the current item changes (e.g. moving to the next video).
    var onCurrentItemChanged: ((Int) -> Void)?

    var onLoadFailed: ((Int) -> Void)?

    var clips: [VideoClip] {
        var result: [VideoClip] = []
        var cursor = CMTime.zero
        for (i, url) in urls.enumerated() {
            let d = i < durations.count ? durations[i] : .zero
            result.append(VideoClip(url: url, duration: d, startOnTimeline: cursor))
            cursor = CMTimeAdd(cursor, d)
        }
        return result
    }

    /// Called on the main thread after all clip durations are loaded.
    var onClipsLoaded: (() -> Void)?

    deinit {
        removeObservers()
    }

    // MARK: - Loading

    func load(urls: [URL]) {
        removeObservers()
        self.urls = []
        self.durations = []
        self.currentIndex = 0
        self.totalDuration = .zero

        guard !urls.isEmpty else {
            player.replaceCurrentItem(with: nil)
            return
        }

        Task {
            var loadedURLs: [URL] = []
            var loadedDurations: [CMTime] = []
            var total = CMTime.zero
            var failedCount = 0

            for url in urls {
                let asset = AVURLAsset(url: url)
                if let d = try? await asset.load(.duration),
                   d.isValid,
                   CMTimeGetSeconds(d) > 0 {
                    loadedURLs.append(url)
                    loadedDurations.append(d)
                    total = CMTimeAdd(total, d)
                } else {
                    NSLog("Skipping unloadable video: \(url)")
                    failedCount += 1
                }
            }

            let finalURLs = loadedURLs
            let finalDurations = loadedDurations
            let finalTotal = total
            let finalFailed = failedCount

            await MainActor.run {
                self.urls = finalURLs
                self.durations = finalDurations
                self.totalDuration = finalTotal
                if !finalURLs.isEmpty {
                    self.playItem(at: 0, seekTo: .zero)
                    self.addObservers()
                } else {
                    self.player.replaceCurrentItem(with: nil)
                }
                self.onClipsLoaded?()
                if finalFailed > 0 {
                    self.onLoadFailed?(finalFailed)
                }
            }
        }
    }

    // MARK: - Playback

    func play() { player.play() }
    func pause() { player.pause() }

    func togglePlay() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    /// Seek to a global timeline time.
    func seek(to globalTime: CMTime,
              toleranceBefore: CMTime = .zero,
              toleranceAfter: CMTime = .zero) {
        guard !urls.isEmpty, !durations.isEmpty else { return }

        // Find the clip containing this time.
        var cursor = CMTime.zero
        for (index, d) in durations.enumerated() {
            let end = CMTimeAdd(cursor, d)
            if CMTimeCompare(globalTime, end) < 0 || index == durations.count - 1 {
                let local = CMTimeSubtract(globalTime, cursor)
                let clamped = max(.zero, min(local, d))
                if index != currentIndex {
                    playItem(at: index, seekTo: clamped,
                             toleranceBefore: toleranceBefore,
                             toleranceAfter: toleranceAfter)
                } else {
                    player.seek(to: clamped,
                                toleranceBefore: toleranceBefore,
                                toleranceAfter: toleranceAfter)
                }
                return
            }
            cursor = end
        }
    }

    /// Seek by a relative offset in seconds on the global timeline.
    func seek(bySeconds offset: Double) {
        guard totalDuration.isValid else { return }
        let current = globalCurrentTime()
        let target = max(0, min(CMTimeGetSeconds(current) + offset,
                                 CMTimeGetSeconds(totalDuration)))
        seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    /// Current playback position on the GLOBAL timeline.
    func globalCurrentTime() -> CMTime {
        guard currentIndex < durations.count else { return .zero }
        var offset = CMTime.zero
        for i in 0..<currentIndex {
            offset = CMTimeAdd(offset, durations[i])
        }
        return CMTimeAdd(offset, player.currentTime())
    }

    // MARK: - Private

    private func playItem(at index: Int,
                          seekTo localTime: CMTime,
                          toleranceBefore: CMTime = .zero,
                          toleranceAfter: CMTime = .zero) {
        guard index >= 0, index < urls.count else { return }
        currentIndex = index
        let item = AVPlayerItem(url: urls[index])
        player.replaceCurrentItem(with: item)
        player.seek(to: localTime,
                    toleranceBefore: toleranceBefore,
                    toleranceAfter: toleranceAfter)
        onCurrentItemChanged?(index)
    }

    private func addObservers() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.onTimeUpdate?(self.globalCurrentTime())
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            // Only handle the end of our current item.
            guard let item = note.object as? AVPlayerItem,
                  item == self.player.currentItem else { return }

            if self.currentIndex + 1 < self.urls.count {
                // Move to the next video.
                self.playItem(at: self.currentIndex + 1, seekTo: .zero)
                self.player.play()
            } else {
                // Last video ended.
                self.onPlaybackEnded?()
            }
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

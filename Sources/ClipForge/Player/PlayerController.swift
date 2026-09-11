import AppKit
import AVFoundation

class PlayerController {
    let player = AVPlayer()
    private(set) var currentURL: URL?

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        currentURL = url
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
}


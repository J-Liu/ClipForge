// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AVFoundation
import CoreMedia

/// Manages the ordered list of video clips and the global timeline.
class TimelineModel {
    private(set) var clips: [VideoClip] = []

    /// Total duration of all clips combined.
    var totalDuration: CMTime {
        clips.last?.endOnTimeline ?? .zero
    }

    /// Rebuild the timeline from a list of URLs.
    func setClips(_ urls: [URL]) async throws {
        var newClips: [VideoClip] = []
        var cursor = CMTime.zero
        for url in urls {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            newClips.append(VideoClip(url: url,
                                      duration: duration,
                                      startOnTimeline: cursor))
            cursor = CMTimeAdd(cursor, duration)
        }
        clips = newClips
    }

    /// Set the clips directly (durations already known).
    func setClipsSync(_ clips: [VideoClip]) {
        self.clips = clips
    }

    /// Append more videos to the end of the timeline.
    func appendClips(_ urls: [URL]) async throws {
        var cursor = totalDuration
        var newClips: [VideoClip] = []
        for url in urls {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            newClips.append(VideoClip(url: url,
                                      duration: duration,
                                      startOnTimeline: cursor))
            cursor = CMTimeAdd(cursor, duration)
        }
        clips.append(contentsOf: newClips)
    }

    /// Clear all clips.
    func clear() {
        clips = []
    }

    /// Find the clip that contains the given global time.
    func clip(at globalTime: CMTime) -> VideoClip? {
        clips.first { $0.contains(globalTime) }
    }

    /// Convert a global time range into (clip, local range) pairs.
    /// A range may span multiple clips.
    func localRanges(for globalRange: CMTimeRange) -> [(clip: VideoClip, range: CMTimeRange)] {
        var result: [(VideoClip, CMTimeRange)] = []
        let globalStart = globalRange.start
        let globalEnd = CMTimeAdd(globalRange.start, globalRange.duration)

        for clip in clips {
            let clipStart = clip.startOnTimeline
            let clipEnd = clip.endOnTimeline

            // No overlap.
            if CMTimeCompare(globalEnd, clipStart) <= 0 { continue }
            if CMTimeCompare(globalStart, clipEnd) >= 0 { continue }

            // Compute overlap.
            let overlapStart = CMTimeCompare(globalStart, clipStart) > 0 ? globalStart : clipStart
            let overlapEnd = CMTimeCompare(globalEnd, clipEnd) < 0 ? globalEnd : clipEnd
            let overlapDuration = CMTimeSubtract(overlapEnd, overlapStart)
            guard CMTimeCompare(overlapDuration, .zero) > 0 else { continue }

            let localStart = CMTimeSubtract(overlapStart, clip.startOnTimeline)
            let localRange = CMTimeRange(start: localStart, duration: overlapDuration)
            result.append((clip, localRange))
        }
        return result
    }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AVFoundation
import CoreMedia

/// One video file loaded into the editor, with its position on the global timeline.
struct VideoClip {
    let url: URL
    let duration: CMTime
    /// Offset of this clip's start on the global timeline.
    let startOnTimeline: CMTime

    /// End of this clip on the global timeline.
    var endOnTimeline: CMTime {
        CMTimeAdd(startOnTimeline, duration)
    }

    /// Does this clip contain the given global time?
    func contains(_ globalTime: CMTime) -> Bool {
        let t = CMTimeGetSeconds(globalTime)
        let s = CMTimeGetSeconds(startOnTimeline)
        let e = CMTimeGetSeconds(endOnTimeline)
        return t >= s && t < e
    }

    /// Convert a global time to this clip's local time.
    /// Returns nil if the time is outside the clip.
    func localTime(for globalTime: CMTime) -> CMTime? {
        guard contains(globalTime) else { return nil }
        return CMTimeSubtract(globalTime, startOnTimeline)
    }
}

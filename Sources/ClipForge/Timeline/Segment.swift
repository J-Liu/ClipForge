import CoreMedia

/// A segment between two cut points (or timeline boundaries).
struct Segment {
    var range: CMTimeRange
    var isKept: Bool

    var start: CMTime { range.start }
    var end: CMTime { CMTimeAdd(range.start, range.duration) }

    func contains(_ time: CMTime) -> Bool {
        let t = CMTimeGetSeconds(time)
        let s = CMTimeGetSeconds(range.start)
        let e = CMTimeGetSeconds(end)
        return t >= s && t < e
    }
}


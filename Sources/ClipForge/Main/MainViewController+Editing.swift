import AppKit
import AVFoundation

extension MainViewController {

    @objc func addCutPoint() {
        guard requireVideoLoaded() else { return }
        guard playerController.totalDuration.isValid else { return }

        let current = playerController.globalCurrentTime()
        let total = CMTimeGetSeconds(playerController.totalDuration)
        let t = CMTimeGetSeconds(current)
        guard t > 0, t < total else { return }
        let minInterval = 1.0 / Double(Settings.shared.frameRate)
        if cutPoints.contains(where: { abs(CMTimeGetSeconds($0) - t) < minInterval }) {
            showAlert(title: "Cut point too close",
                      message: "There is already a cut point within \(Int(minInterval * 1000)) ms.")
            return
        }

        registerUndo()
        cutPoints.append(current)
        cutPoints.sort { CMTimeGetSeconds($0) < CMTimeGetSeconds($1) }
        rebuildSegments()
    }

    func addCutPointAt(_ time: CMTime) {
        guard requireVideoLoaded() else { return }
        guard playerController.totalDuration.isValid else { return }

        let total = CMTimeGetSeconds(playerController.totalDuration)
        let t = CMTimeGetSeconds(time)
        guard t > 0, t < total else { return }
        let minInterval = 1.0 / Double(Settings.shared.frameRate)
        if cutPoints.contains(where: { abs(CMTimeGetSeconds($0) - t) < minInterval }) {
            showAlert(title: "Cut point too close",
                      message: "There is already a cut point within \(Int(minInterval * 1000)) ms.")
            return
        }

        registerUndo()
        cutPoints.append(time)
        cutPoints.sort { CMTimeGetSeconds($0) < CMTimeGetSeconds($1) }
        rebuildSegments()
    }

    func rebuildSegments() {
        let total = playerController.totalDuration
        guard total.isValid, CMTimeGetSeconds(total) > 0 else {
            segments = []
            segmentBar.segments = []
            return
        }

        let oldSegments = segments

        var boundaries: [CMTime] = [.zero]
        boundaries.append(contentsOf: cutPoints)
        boundaries.append(total)

        var newSegments: [Segment] = []
        for i in 0..<(boundaries.count - 1) {
            let start = boundaries[i]
            let end = boundaries[i + 1]
            let range = CMTimeRange(start: start, end: end)
            let matched = oldSegments.first(where: { CMTimeCompare($0.start, start) == 0 })
            let inherited: Bool = matched?.isKept ?? true
            newSegments.append(Segment(range: range, isKept: inherited))
        }

        segments = newSegments
        segmentBar.segments = newSegments
        segmentBar.totalDuration = total
        segmentBar.cutPoints = cutPoints
    }

    func toggleSegment(at index: Int) {
        guard index >= 0, index < segments.count else { return }
        registerUndo()
        segments[index].isKept.toggle()
        segmentBar.segments = segments
    }

    func refreshTimelineUI(rebuild: Bool = true) {
        if rebuild {
            rebuildSegments()
        } else {
            segmentBar.segments = segments
            segmentBar.cutPoints = cutPoints
            segmentBar.totalDuration = playerController.totalDuration
        }
        segmentBar.clipBoundaries = playerController.clips.dropFirst().map { $0.startOnTimeline }
    }

    func registerUndo() {
        guard let undoManager = view.window?.undoManager else { return }
        let oldCutPoints = cutPoints
        let oldSegments = segments

        undoManager.registerUndo(withTarget: self) { target in
            let currentCutPoints = target.cutPoints
            let currentSegments = target.segments

            target.cutPoints = oldCutPoints
            target.segments = oldSegments
            target.refreshTimelineUI(rebuild: false)

            target.view.window?.undoManager?.registerUndo(withTarget: target) { t in
                t.cutPoints = currentCutPoints
                t.segments = currentSegments
                t.refreshTimelineUI(rebuild: false)
            }
        }
    }
}

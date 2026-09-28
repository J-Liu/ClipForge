// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit

/// Window controller for the segment list window
class SegmentListWindowController: NSWindowController {
    private var listView: SegmentListView!
    private weak var mainViewController: MainViewController?

    convenience init(mainViewController: MainViewController) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 300),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered,
                              defer: false)
        self.init(window: window)
        self.mainViewController = mainViewController
        setupUI()
    }

    private func setupUI() {
        guard let window else { return }
        window.title = L("main.segmentList.title")
        window.center()

        listView = SegmentListView()
        window.contentView = listView

        listView.onSegmentToggled = { [weak self] index in
            guard let self, let mainVC = self.mainViewController else { return }
            mainVC.toggleSegment(at: index)
            self.listView.updateSegments(mainVC.segments)
        }

        listView.onSegmentSelected = { [weak self] index in
            guard let self, let mainVC = self.mainViewController else { return }
            guard index >= 0, index < mainVC.segments.count else { return }
            let segment = mainVC.segments[index]
            mainVC.playerController.seek(to: segment.start)
        }
    }

    func updateSegments(_ segments: [Segment]) {
        listView.updateSegments(segments)
    }
}

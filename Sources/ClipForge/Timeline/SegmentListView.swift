// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import CoreMedia

/// A list view showing all segments with the ability to toggle keep/delete.
class SegmentListView: NSView {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private var segments: [Segment] = []

    /// Called when a segment's keep state is toggled.
    var onSegmentToggled: ((Int) -> Void)?
    /// Called when a segment is clicked to navigate to it.
    var onSegmentSelected: ((Int) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.style = .plain
        tableView.rowHeight = 24
        tableView.headerView = nil
        tableView.allowsColumnSelection = false
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true

        let col1 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("toggle"))
        col1.width = 40
        tableView.addTableColumn(col1)

        let col2 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        col2.width = 180
        tableView.addTableColumn(col2)

        let col3 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        col3.width = 80
        tableView.addTableColumn(col3)

        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func updateSegments(_ segments: [Segment]) {
        self.segments = segments
        tableView.reloadData()
    }

    func highlightSegment(at index: Int) {
        guard index >= 0, index < segments.count else { return }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }
}

extension SegmentListView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return segments.count
    }
}

extension SegmentListView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < segments.count else { return nil }
        let segment = segments[row]

        let identifier = tableColumn?.identifier.rawValue ?? ""

        switch identifier {
        case "toggle":
            let button = NSButton(checkboxWithTitle: "", target: nil, action: nil)
            button.state = segment.isKept ? .on : .off
            button.tag = row
            button.target = self
            button.action = #selector(toggleButtonClicked(_:))
            return button

        case "time":
            let label = NSTextField(labelWithString: "")
            let startStr = TimeFormatter.displayString(from: segment.start)
            let endStr = TimeFormatter.displayString(from: segment.end)
            label.stringValue = "\(startStr) - \(endStr)"
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            return label

        case "duration":
            let label = NSTextField(labelWithString: "")
            let duration = CMTimeGetSeconds(segment.end) - CMTimeGetSeconds(segment.start)
            label.stringValue = String(format: "%.3fs", duration)
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            return label

        default:
            return nil
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        onSegmentSelected?(row)
    }

    @objc private func toggleButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        onSegmentToggled?(index)
    }
}

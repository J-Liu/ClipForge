// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import AVFoundation
import UniformTypeIdentifiers

extension MainViewController {

    static var exportSession: AVAssetExportSession?

    @objc func exportVideo() {
        guard requireVideoLoaded() else { return }
        guard !playerController.urls.isEmpty else { return }

        let panel = NSSavePanel()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())

        let format = ExportFormat(rawValue: Settings.shared.exportFormat) ?? .mp4h264
        panel.nameFieldStringValue = "ClipForge-\(timestamp).\(format.fileExtension)"
        switch format {
        case .mov:
            panel.allowedContentTypes = [.quickTimeMovie]
        default:
            panel.allowedContentTypes = [.mpeg4Movie]
        }
        panel.canCreateDirectories = true

        let optionsView = ExportOptionsView(frame: NSRect(x: 0, y: 0, width: 280, height: 140))
        panel.accessoryView = optionsView

        panel.begin { [weak self] response in
            guard response == .OK, var outputURL = panel.url else { return }
            // Ensure the file extension matches the selected format
            let selectedFormat = ExportFormat(rawValue: Settings.shared.exportFormat) ?? .mp4h264
            outputURL.deletePathExtension()
            outputURL.appendPathExtension(selectedFormat.fileExtension)
            self?.performExport(outputURL: outputURL)
        }
    }

    func performExport(outputURL: URL) {
        playerController.pause()

        let resolution = ExportResolution(rawValue: Settings.shared.exportResolution) ?? .original
        let frameRate = ExportFrameRate(rawValue: Settings.shared.exportFrameRate) ?? .original
        let format = ExportFormat(rawValue: Settings.shared.exportFormat) ?? .mp4h264

        // Create progress sheet
        let progressSheet = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
                                      styleMask: [.titled],
                                      backing: .buffered,
                                      defer: false)
        progressSheet.title = L("alert.exporting", 0)
        progressSheet.isReleasedWhenClosed = false

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 140))
        progressSheet.contentView = containerView

        let messageLabel = NSTextField(labelWithString: L("alert.exporting.message"))
        messageLabel.frame = NSRect(x: 20, y: 100, width: 280, height: 20)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.font = .systemFont(ofSize: 12)

        let progressBar = NSProgressIndicator(frame: NSRect(x: 20, y: 65, width: 280, height: 20))
        progressBar.style = .bar
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.doubleValue = 0
        progressBar.isIndeterminate = false

        let cancelButton = NSButton(frame: NSRect(x: 120, y: 20, width: 80, height: 24))
        cancelButton.title = L("alert.cancel")
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelExport)

        containerView.addSubview(messageLabel)
        containerView.addSubview(progressBar)
        containerView.addSubview(cancelButton)

        guard let window = view.window else { return }
        window.beginSheet(progressSheet) { [weak self] _ in
            self?.cleanupExportSheet(progressSheet)
        }

        CompositionBuilder.export(
            clips: playerController.clips,
            segments: segments,
            cropRect: cropRect,
            resolution: resolution,
            frameRate: frameRate,
            format: format,
            outputURL: outputURL,
            progress: { [weak progressBar, weak progressSheet] value in
                DispatchQueue.main.async {
                    let percent = Int(value * 100)
                    progressBar?.doubleValue = Double(percent)
                    progressSheet?.title = L("alert.exporting", percent)
                }
            },
            completion: { [weak self, weak progressSheet, weak window] result in
                DispatchQueue.main.async {
                    if let sheet = progressSheet, let w = window {
                        w.endSheet(sheet)
                    }
                    switch result {
                    case .success:
                        self?.showAlert(title: L("alert.exportComplete.title"),
                                        message: outputURL.lastPathComponent)
                    case .failure(let error):
                        self?.showError(error)
                    }
                }
            }
        )
    }

    @objc private func cancelExport() {
        Self.exportSession?.cancelExport()
    }

    private func cleanupExportSheet(_ sheet: NSWindow) {
        sheet.close()
        Self.exportSession = nil
    }
}

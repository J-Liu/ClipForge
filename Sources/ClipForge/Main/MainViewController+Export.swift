// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension MainViewController {

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

        let optionsView = ExportOptionsView()
        let hosting = NSHostingView(rootView: optionsView)
        hosting.frame = NSRect(x: 0, y: 0, width: 280, height: 140)
        panel.accessoryView = hosting

        panel.begin { [weak self] response in
            guard response == .OK, let outputURL = panel.url else { return }
            self?.performExport(outputURL: outputURL)
        }
    }

    func performExport(outputURL: URL) {
        playerController.pause()

        let resolution = ExportResolution(rawValue: Settings.shared.exportResolution) ?? .original
        let frameRate = ExportFrameRate(rawValue: Settings.shared.exportFrameRate) ?? .original
        let format = ExportFormat(rawValue: Settings.shared.exportFormat) ?? .mp4h264

        let originalTitle = view.window?.title ?? "ClipForge"
        view.window?.title = "Exporting… 0%"

        CompositionBuilder.export(
            clips: playerController.clips,
            segments: segments,
            cropRect: cropRect,
            resolution: resolution,
            frameRate: frameRate,
            format: format,
            outputURL: outputURL,
            progress: { [weak self] value in
                self?.view.window?.title = L("alert.exporting", value * 100)
            },
            completion: { [weak self] result in
                self?.view.window?.title = originalTitle
                switch result {
                case .success:
                    self?.showAlert(title: L("alert.exportComplete.title"),
                                    message: outputURL.lastPathComponent)
                case .failure(let error):
                    self?.showError(error)
                }
            }
        )
    }
}

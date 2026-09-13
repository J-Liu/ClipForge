// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AppKit
import AVFoundation
import ScreenCaptureKit

extension RecorderController {

    /// Start recording the main display with system audio.
    func startRecording(completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false, onScreenWindowsOnly: true
                )
                guard let display = content.displays.first else {
                    throw NSError(domain: "ClipForge", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No display found"])
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])

                let config = makeBaseConfig()
                config.width = display.width
                config.height = display.height

                let outputURL = Self.makeOutputURL()
                let recorder = ScreenRecorder(outputURL: outputURL)
                try recorder.start(
                    width: config.width,
                    height: config.height,
                    includeSystemAudio: Settings.shared.captureSystemAudio,
                    includeMicrophone: Settings.shared.captureMicrophone,
                    codec: Settings.shared.videoCodec
                )
                self.recorder = recorder

                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
                try await stream.startCapture()
                self.stream = stream
                self.isRecording = true

                try startMicrophoneIfNeeded()

                await MainActor.run { completion(nil) }
            } catch {
                await MainActor.run {
                    completion(ClipForgeError.from(error))
                }
            }
        }
    }
}

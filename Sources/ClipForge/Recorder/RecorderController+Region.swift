import AppKit
import AVFoundation
import ScreenCaptureKit

extension RecorderController {

    func startRegionRecording(region: NSRect, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false, onScreenWindowsOnly: true
                )
                guard let display = content.displays.first else {
                    throw NSError(domain: "ClipForge", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No display"])
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])

                // Convert AppKit screen rect to display-relative coordinates.
                guard let targetScreen = NSScreen.screens.first(where: { $0.frame.intersects(region) }) else {
                    throw NSError(domain: "ClipForge", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No screen for region"])
                }
                let screenHeight = targetScreen.frame.height
                let displayRelativeX = region.origin.x - targetScreen.frame.origin.x
                let displayRelativeY = screenHeight - region.origin.y - region.height

                let config = makeBaseConfig()
                config.sourceRect = CGRect(
                    x: displayRelativeX,
                    y: displayRelativeY,
                    width: region.width,
                    height: region.height
                )
                config.width = Int(region.width)
                config.height = Int(region.height)

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

                await MainActor.run {
                    self.highlight.showFixed(around: region)
                    completion(nil)
                }
            } catch {
                await MainActor.run { completion(error) }
            }
        }
    }
}

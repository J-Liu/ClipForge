import AppKit
import AVFoundation
import ScreenCaptureKit

extension RecorderController {

    /// Start recording a single window.
    func startWindowRecording(window: SCWindow, completion: @escaping (Error?) -> Void) {
        Task {
            do {
                let filter = SCContentFilter(desktopIndependentWindow: window)

                let config = makeBaseConfig()
                config.width = Int(window.frame.width) * 2
                config.height = Int(window.frame.height) * 2

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

                // Show the highlight around the target window.
                let screenRect = Self.screenRect(from: window.frame)
                await MainActor.run {
                    self.highlight.show(windowID: window.windowID, initialFrame: screenRect)
                }

                await MainActor.run { completion(nil) }
            } catch {
                await MainActor.run { completion(error) }
            }
        }
    }
}

import AppKit
import AVFoundation
import ScreenCaptureKit

/// Manages a full-screen recording session with system audio.
class RecorderController: NSObject {
    private var stream: SCStream?
    private var recorder: ScreenRecorder?
    private let sampleQueue = DispatchQueue(label: "ClipForge.recorder.samples")
    private let mic = MicrophoneCapture()

    private(set) var isRecording = false

    /// Start recording the main display with system audio.
    func startRecording(completion: @escaping (Error?) -> Void) {
        Task {
            do {
                // 1. Get shareable content.
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
                guard let display = content.displays.first else {
                    throw NSError(domain: "ClipForge", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "No display found"])
                }

                // 2. Build filter for the whole display.
                let filter = SCContentFilter(display: display, excludingWindows: [])

                // 3. Configure stream.
                let config = SCStreamConfiguration()
                config.width = display.width
                config.height = display.height
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                config.queueDepth = 6
                config.capturesAudio = true
                config.excludesCurrentProcessAudio = true
                config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

                // 4. Prepare writer.
                let outputURL = Self.makeOutputURL()
                let recorder = ScreenRecorder(outputURL: outputURL)
                try recorder.start(width: display.width, height: display.height)
                self.recorder = recorder

                // 5. Create and start stream.
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: sampleQueue)
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
                try await stream.startCapture()
                self.stream = stream
                self.isRecording = true

                mic.onSampleBuffer = { [weak self] buffer in
                    self?.recorder?.appendMicrophone(buffer)
                }
                try mic.start()

                await MainActor.run { completion(nil) }
            } catch {
                await MainActor.run { completion(error) }
            }
        }
    }

    /// Stop recording and finish writing the file.
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard let stream = stream, let recorder = recorder else {
            completion(nil)
            return
        }
        Task {
            try? await stream.stopCapture()
            mic.stop()
            self.stream = nil
            self.isRecording = false
            recorder.finish { url in
                self.recorder = nil
                completion(url)
            }
        }
    }

    // MARK: - Helpers

    private static func makeOutputURL() -> URL {
        let dir = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "ClipForge-\(formatter.string(from: Date())).mp4"
        return dir.appendingPathComponent(name)
    }
}

// MARK: - SCStreamOutput

extension RecorderController: SCStreamOutput {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        // Audio passes straight through.
        guard type == .screen else {
            recorder?.append(sampleBuffer, ofType: type)
            return
        }

        // Only forward complete screen frames.
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer, createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
        let attachments = attachmentsArray.first else {
            return
        }

        guard let statusRawValue = attachments[.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete else {
            // print("Skipping incomplete frame")
            return
        }

        recorder?.append(sampleBuffer, ofType: type)
    }
}

// MARK: - SCStreamDelegate

extension RecorderController: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("SCStream stopped with error: \(error)")
        isRecording = false
    }
}

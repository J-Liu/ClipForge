import AppKit
import AVFoundation
import ScreenCaptureKit

/// Manages screen recording sessions (full screen, window, or region).
class RecorderController: NSObject {
    var stream: SCStream?
    var recorder: ScreenRecorder?
    let sampleQueue = DispatchQueue(label: "ClipForge.recorder.samples")
    let mic = MicrophoneCapture()
    let highlight = WindowHighlightOverlay()

    var isRecording = false
    var onUnexpectedStop: ((Error) -> Void)?

    /// Stop recording and finish writing the file.
    func stopRecording(completion: @escaping (URL?) -> Void) {
        highlight.hide()
        guard let stream = stream, let recorder = recorder else {
            completion(nil)
            return
        }
        Task {
            do {
                try await stream.stopCapture()
            } catch {
                NSLog("stopCapture failed: \(error)")
            }
            mic.stop()
            self.stream = nil
            self.isRecording = false
            recorder.finish { url in
                self.recorder = nil
                completion(url)
            }
        }
    }

    // MARK: - Shared helpers

    /// Build the output file URL in the configured directory.
    static func makeOutputURL() -> URL {
        let dir = Settings.shared.recordingOutputDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let ext = Settings.shared.recordingFormat == "mov" ? "mov" : "mp4"
        let name = "ClipForge-\(formatter.string(from: Date())).\(ext)"
        return dir.appendingPathComponent(name)
    }

    /// Convert an SCWindow frame (top-left origin) to AppKit screen coords.
    static func screenRect(from scFrame: CGRect) -> NSRect {
        guard let mainScreen = NSScreen.screens.first else { return .zero }
        let screenHeight = mainScreen.frame.height
        return NSRect(
            x: scFrame.origin.x,
            y: screenHeight - scFrame.origin.y - scFrame.height,
            width: scFrame.width,
            height: scFrame.height
        )
    }

    /// Start the microphone if the user enabled it.
    func startMicrophoneIfNeeded() throws {
        guard Settings.shared.captureMicrophone else { return }
        mic.onSampleBuffer = { [weak self] buffer in
            self?.recorder?.appendMicrophone(buffer)
        }
        try mic.start()
    }

    /// Build an SCStreamConfiguration with the common settings.
    func makeBaseConfig() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        let fps = Settings.shared.frameRate
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.queueDepth = 6
        config.capturesAudio = Settings.shared.captureSystemAudio
        config.excludesCurrentProcessAudio = true
        config.showsCursor = Settings.shared.showsCursor
        return config
    }
}

// MARK: - SCStreamOutput

extension RecorderController: SCStreamOutput {
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen else {
            recorder?.append(sampleBuffer, ofType: type)
            return
        }

        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer, createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
        let attachments = attachmentsArray.first,
        let statusRawValue = attachments[.status] as? Int,
        let status = SCFrameStatus(rawValue: statusRawValue) else {
            return
        }

        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        switch status {
        case .complete:
            recorder?.appendCompleteFrame(sampleBuffer)
        case .idle, .blank:
            recorder?.appendIdleFrame(atTime: pts)
        case .suspended:
            break
        default:
            break
        }
    }
}

// MARK: - SCStreamDelegate

extension RecorderController: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("SCStream stopped with error: \(error)")
        isRecording = false
        onUnexpectedStop?(error)
    }
}

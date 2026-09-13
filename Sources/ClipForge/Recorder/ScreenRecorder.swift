import AVFoundation
import ScreenCaptureKit

/// Writes video and audio sample buffers into an .mp4 file.
class ScreenRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var micInput: AVAssetWriterInput?
    private var isSessionStarted = false
    private let outputURL: URL
    private var lastCompleteBuffer: CMSampleBuffer?
    private var lastWrittenTime: CMTime = .zero

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    /// Create the writer and all inputs.
    func start(width: Int,
               height: Int,
               includeSystemAudio: Bool,
               includeMicrophone: Bool,
               codec: String) throws {
        try? FileManager.default.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        self.assetWriter = writer

        let codecType: AVVideoCodecType
        switch codec {
        case "h265": codecType = .hevc
        default:     codecType = .h264
        }
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: codecType,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        video.expectsMediaDataInRealTime = true
        writer.add(video)
        self.videoInput = video

        if includeSystemAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000
            ]
            let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audio.expectsMediaDataInRealTime = true
            writer.add(audio)
            self.audioInput = audio
        }
        if includeMicrophone {
            let micSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64000
            ]
            let mic = AVAssetWriterInput(mediaType: .audio, outputSettings: micSettings)
            mic.expectsMediaDataInRealTime = true
            writer.add(mic)
            self.micInput = mic
        }

        writer.startWriting()
    }

    func append(_ sampleBuffer: CMSampleBuffer, ofType type: SCStreamOutputType) {
        guard let writer = assetWriter, writer.status == .writing else { return }

        if !isSessionStarted {
            if type == .screen {
                writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                isSessionStarted = true
            } else {
                return
            }
        }

        switch type {
        case .screen:
            if let input = videoInput, input.isReadyForMoreMediaData {
                let ok = input.append(sampleBuffer)
                if !ok { print("video append failed: \(String(describing: writer.error))") }
            }
        case .audio:
            if let input = audioInput, input.isReadyForMoreMediaData {
                let ok = input.append(sampleBuffer)
                if !ok { print("audio append failed: \(String(describing: writer.error))") }
            }
        default:
            break
        }
    }

    func appendMicrophone(_ sampleBuffer: CMSampleBuffer) {
        guard let writer = assetWriter, writer.status == .writing, isSessionStarted else { return }
        if let input = micInput, input.isReadyForMoreMediaData {
            let ok = input.append(sampleBuffer)
            if !ok {
                print("mic append failed: \(String(describing: writer.error))")
            }
        }
    }

    func finish(completion: @escaping (URL?) -> Void) {
        guard let writer = assetWriter, writer.status == .writing else {
            completion(nil)
            return
        }
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        micInput?.markAsFinished()
        writer.finishWriting {
            DispatchQueue.main.async {
                completion(writer.status == .completed ? self.outputURL : nil)
            }
        }
    }

    /// Append a complete frame and remember it for idle-frame duplication.
    func appendCompleteFrame(_ sampleBuffer: CMSampleBuffer) {
        lastCompleteBuffer = sampleBuffer
        lastWrittenTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        append(sampleBuffer, ofType: .screen)
    }

    /// Duplicate the last complete frame with a new timestamp, to keep the frame rate stable.
    func appendIdleFrame(atTime time: CMTime) {
        guard let last = lastCompleteBuffer,
              let writer = assetWriter,
              writer.status == .writing,
              isSessionStarted else { return }

        // Only duplicate if enough time has passed since the last write.
        let elapsed = CMTimeGetSeconds(CMTimeSubtract(time, lastWrittenTime))
        let frameInterval = 1.0 / Double(Settings.shared.frameRate)
        guard elapsed >= frameInterval * 0.9 else { return }

        guard let newBuffer = Self.duplicateFrame(from: last, at: time) else { return }

        if let input = videoInput, input.isReadyForMoreMediaData {
            let ok = input.append(newBuffer)
            if !ok {
                print("idle append failed: \(String(describing: writer.error))")
            }
        }

        lastWrittenTime = time
    }

    /// Deep-copy a frame's pixel buffer and re-wrap it with a new presentation time.
    private static func duplicateFrame(from buffer: CMSampleBuffer, at time: CMTime) -> CMSampleBuffer? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let format = CVPixelBufferGetPixelFormatType(imageBuffer)

        var newPixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            attrs as CFDictionary,
            &newPixelBuffer
        )
        guard status == kCVReturnSuccess, let newPB = newPixelBuffer else { return nil }

        // Lock both buffers.
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(newPB, [])

        let planeCount = CVPixelBufferGetPlaneCount(imageBuffer)
        if planeCount == 0 {
            // Single-plane format.
            if let src = CVPixelBufferGetBaseAddress(imageBuffer),
               let dst = CVPixelBufferGetBaseAddress(newPB) {
                let srcBytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
                let dstBytesPerRow = CVPixelBufferGetBytesPerRow(newPB)
                let bytesToCopy = min(srcBytesPerRow, dstBytesPerRow)
                for row in 0..<height {
                    memcpy(dst.advanced(by: row * dstBytesPerRow),
                           src.advanced(by: row * srcBytesPerRow),
                           bytesToCopy)
                }
            }
        } else {
            // Multi-plane format (e.g. 420YpCbCr8BiPlanar).
            for plane in 0..<planeCount {
                guard let src = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, plane),
                      let dst = CVPixelBufferGetBaseAddressOfPlane(newPB, plane) else { continue }
                let srcBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, plane)
                let dstBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(newPB, plane)
                let planeHeight = CVPixelBufferGetHeightOfPlane(imageBuffer, plane)
                let bytesToCopy = min(srcBytesPerRow, dstBytesPerRow)
                for row in 0..<planeHeight {
                    memcpy(dst.advanced(by: row * dstBytesPerRow),
                           src.advanced(by: row * srcBytesPerRow),
                           bytesToCopy)
                }
            }
        }

        CVPixelBufferUnlockBaseAddress(newPB, [])
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

        // Build the CMSampleBuffer.
        var formatDesc: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: newPB,
            formatDescriptionOut: &formatDesc
        )
        guard let fd = formatDesc else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(buffer),
            presentationTimeStamp: time,
            decodeTimeStamp: .invalid
        )

        var newBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: newPB,
            formatDescription: fd,
            sampleTiming: &timing,
            sampleBufferOut: &newBuffer
        )
        return createStatus == noErr ? newBuffer : nil
    }
}

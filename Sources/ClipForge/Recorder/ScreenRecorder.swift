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
}

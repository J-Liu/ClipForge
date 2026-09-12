import AVFoundation

/// Records audio from the default microphone into an .m4a file.
class AudioRecorder: NSObject  {
    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "ClipForge.audio")

    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var isSessionStarted = false
    private let outputURL: URL

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    /// Start capturing from the default microphone.
    func start() throws {
        try? FileManager.default.removeItem(at: outputURL)

        // Writer.
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        self.assetWriter = writer

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64000
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        self.audioInput = input

        writer.startWriting()

        // Capture session.
        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(for: .audio) else {
            throw NSError(domain: "ClipForge", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No microphone available"])
        }
        let deviceInput = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(deviceInput) else {
            throw NSError(domain: "ClipForge", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot add microphone input"])
        }
        session.addInput(deviceInput)

        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            throw NSError(domain: "ClipForge", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot add audio output"])
        }
        session.addOutput(output)

        session.commitConfiguration()
        session.startRunning()
    }

    /// Stop capture and finish writing.
    func stop(completion: @escaping (URL?) -> Void) {
        if session.isRunning {
            session.stopRunning()
        }
        guard let writer = assetWriter, writer.status == .writing else {
            completion(nil)
            return
        }
        audioInput?.markAsFinished()
        writer.finishWriting {
            DispatchQueue.main.async {
                completion(writer.status == .completed ? self.outputURL : nil)
            }
        }
    }

    private func append(_ sampleBuffer: CMSampleBuffer) {
        guard let writer = assetWriter, writer.status == .writing else { return }

        if !isSessionStarted {
            writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            isSessionStarted = true
        }

        if let input = audioInput, input.isReadyForMoreMediaData {
            let ok = input.append(sampleBuffer)
            if !ok {
                print("audio append failed: \(String(describing: writer.error))")
            }
        }
    }
}

extension AudioRecorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        append(sampleBuffer)
    }
}

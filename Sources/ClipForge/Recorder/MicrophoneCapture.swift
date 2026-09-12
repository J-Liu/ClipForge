import AVFoundation

/// Captures audio from the default microphone and delivers sample buffers.
class MicrophoneCapture: NSObject  {
    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let queue = DispatchQueue(label: "ClipForge.mic")

    /// Called on the capture queue with each audio sample buffer.
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?

    /// Start capturing from the default audio input device.
    func start() throws {
        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(for: .audio) else {
            throw NSError(domain: "ClipForge", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No microphone available"])
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw NSError(domain: "ClipForge", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot add microphone input"])
        }
        session.addInput(input)

        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            throw NSError(domain: "ClipForge", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot add audio output"])
        }
        session.addOutput(output)

        session.commitConfiguration()
        session.startRunning()
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }
}

extension MicrophoneCapture: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onSampleBuffer?(sampleBuffer)
    }
}

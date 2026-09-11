import AVFoundation
import CoreMedia

/// Builds an AVComposition from kept segments and exports it to a new file.
class CompositionBuilder {

    enum BuildError: Error {
        case noKeptSegments
        case trackLoadFailed
        case exportFailed(Error)
        case exportCancelled
    }

    /// Export kept segments to the given output URL.
    /// - Parameters:
    ///   - sourceURL: original video file
    ///   - segments: all segments, with isKept marking which to include
    ///   - outputURL: destination file URL
    ///   - progress: called on main thread with 0.0...1.0
    ///   - completion: called on main thread with success or error
    static func export(
        sourceURL: URL,
        segments: [Segment],
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let kept = segments.filter { $0.isKept }.sorted {
            CMTimeCompare($0.start, $1.start) < 0
        }
        guard !kept.isEmpty else {
            completion(.failure(BuildError.noKeptSegments))
            return
        }

        let asset = AVURLAsset(url: sourceURL)
        let composition = AVMutableComposition()

        Task {
            do {
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                guard let sourceVideoTrack = videoTracks.first else {
                    throw BuildError.trackLoadFailed
                }

                let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                let compositionAudioTrack = audioTracks.first != nil
                    ? composition.addMutableTrack(
                        withMediaType: .audio,
                        preferredTrackID: kCMPersistentTrackID_Invalid)
                    : nil

                var cursor = CMTime.zero
                for segment in kept {
                    try compositionVideoTrack?.insertTimeRange(
                        segment.range,
                        of: sourceVideoTrack,
                        at: cursor
                    )
                    if let sourceAudioTrack = audioTracks.first,
                       let compositionAudioTrack = compositionAudioTrack {
                        try compositionAudioTrack.insertTimeRange(
                            segment.range,
                            of: sourceAudioTrack,
                            at: cursor
                        )
                    }
                    cursor = CMTimeAdd(cursor, segment.range.duration)
                }

                // Preserve the source's preferred transform (rotation).
                if let compositionVideoTrack = compositionVideoTrack {
                    let transform = try await sourceVideoTrack.load(.preferredTransform)
                    compositionVideoTrack.preferredTransform = transform
                }

                runExport(
                    composition: composition,
                    outputURL: outputURL,
                    progress: progress,
                    completion: completion
                )
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func runExport(
        composition: AVMutableComposition,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Remove existing file at destination.
        try? FileManager.default.removeItem(at: outputURL)

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            completion(.failure(BuildError.exportFailed(NSError(domain: "ClipForge", code: -1))))
            return
        }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        // Poll progress on a timer.
        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            progress(Double(session.progress))
        }

        session.exportAsynchronously {
            timer.invalidate()
            DispatchQueue.main.async {
                switch session.status {
                case .completed:
                    progress(1.0)
                    completion(.success(()))
                case .cancelled:
                    completion(.failure(BuildError.exportCancelled))
                case .failed:
                    completion(.failure(BuildError.exportFailed(
                        session.error ?? NSError(domain: "ClipForge", code: -1)
                    )))
                default:
                    completion(.failure(BuildError.exportFailed(
                        NSError(domain: "ClipForge", code: -1)
                    )))
                }
            }
        }
    }
}

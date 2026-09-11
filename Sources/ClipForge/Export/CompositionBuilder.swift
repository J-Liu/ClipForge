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
    ///   - cropRect: optional crop rectangle in video pixel coordinates
    ///   - outputURL: destination file URL
    ///   - progress: called on main thread with 0.0...1.0
    ///   - completion: called on main thread with success or error
    static func export(
        sourceURL: URL,
        segments: [Segment],
        cropRect: NSRect?,
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

                // Build the video composition for cropping, if needed.
                var videoComposition: AVMutableVideoComposition? = nil
                if let cropRect = cropRect, cropRect.width > 0, cropRect.height > 0 {
                    videoComposition = makeVideoComposition(
                        composition: composition,
                        cropRect: cropRect
                    )
                }

                runExport(
                    composition: composition,
                    videoComposition: videoComposition,
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

    /// Build an AVMutableVideoComposition that crops every frame to `cropRect`.
    private static func makeVideoComposition(
        composition: AVMutableComposition,
        cropRect: NSRect
    ) -> AVMutableVideoComposition? {
        guard let videoTrack = composition.tracks(withMediaType: .video).first else {
            return nil
        }

        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        // Crop the full video frame first.
        let fullSize = videoTrack.naturalSize
        let fullCrop = CGRect(x: 0, y: 0, width: fullSize.width, height: fullSize.height)
        instruction.setCropRectangle(fullCrop, at: .zero)

        // Translate so the desired region lands at (0, 0).
        // cropRect.origin.y is top-down; CG transform y is bottom-up.
        let translate = CGAffineTransform(
            translationX: -cropRect.origin.x,
            y: -(fullSize.height - cropRect.origin.y - cropRect.height)
        )
        instruction.setTransform(translate, at: .zero)

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = cropRect.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instructionGroup = AVMutableVideoCompositionInstruction()
        instructionGroup.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        instructionGroup.layerInstructions = [instruction]
        videoComposition.instructions = [instructionGroup]

        return videoComposition
    }

    private static func runExport(
        composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition?,
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

        // Attach the crop composition if present.
        if let videoComposition = videoComposition {
            session.videoComposition = videoComposition
        }

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

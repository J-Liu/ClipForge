import AVFoundation
import CoreMedia

/// Builds an AVComposition from kept segments across multiple video sources.
class CompositionBuilder {

    enum BuildError: LocalizedError {
        case noKeptSegments
        case trackLoadFailed
        case exportFailed(String)
        case exportCancelled

        var errorDescription: String? {
            switch self {
            case .noKeptSegments: return "Nothing to export"
            case .trackLoadFailed: return "Failed to load video track"
            case .exportFailed(let msg): return "Export failed: \(msg)"
            case .exportCancelled: return "Export cancelled"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .noKeptSegments:
                return "Keep at least one segment before exporting."
            case .trackLoadFailed:
                return "The file may be corrupted or use an unsupported codec."
            case .exportFailed:
                return "Try a different output location or a lower resolution."
            case .exportCancelled:
                return nil
            }
        }
    }

    /// Export kept segments to the given output URL.
    /// - Parameters:
    ///   - clips: all loaded video clips (with their URLs and timeline positions)
    ///   - segments: all segments on the global timeline, with isKept marking which to include
    ///   - cropRect: optional crop rectangle in video pixel coordinates
    ///   - outputURL: destination file URL
    ///   - progress: called on main thread with 0.0...1.0
    ///   - completion: called on main thread with success or error
    static func export(
        clips: [VideoClip],
        segments: [Segment],
        cropRect: NSRect?,
        resolution: ExportResolution,
        frameRate: ExportFrameRate,
        format: ExportFormat,
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

        let timeline = TimelineModel()
        // Populate timeline with the clips (no async needed; we already have durations).
        timeline.setClipsSync(clips)

        let composition = AVMutableComposition()

        Task {
            do {
                // Create one composition track for video and one for audio.
                let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )

                // Cache source tracks per URL to avoid re-loading.
                var videoTrackCache: [URL: AVAssetTrack] = [:]
                var audioTrackCache: [URL: AVAssetTrack] = [:]
                var transformCache: [URL: CGAffineTransform] = [:]

                var cursor = CMTime.zero

                for segment in kept {
                    let pieces = timeline.localRanges(for: segment.range)
                    for piece in pieces {
                        let url = piece.clip.url
                        let asset = AVURLAsset(url: url)

                        // Load and cache tracks.
                        let videoTrack: AVAssetTrack
                        if let cached = videoTrackCache[url] {
                            videoTrack = cached
                        } else {
                            guard let t = try await asset.loadTracks(withMediaType: .video).first else {
                                throw BuildError.trackLoadFailed
                            }
                            videoTrackCache[url] = t
                            videoTrack = t
                        }

                        let audioTrack: AVAssetTrack?
                        if let cached = audioTrackCache[url] {
                            audioTrack = cached
                        } else {
                            audioTrack = try await asset.loadTracks(withMediaType: .audio).first
                            if let t = audioTrack { audioTrackCache[url] = t }
                        }

                        let transform: CGAffineTransform
                        if let cached = transformCache[url] {
                            transform = cached
                        } else {
                            transform = try await videoTrack.load(.preferredTransform)
                            transformCache[url] = transform
                        }

                        try compositionVideoTrack?.insertTimeRange(
                            piece.range,
                            of: videoTrack,
                            at: cursor
                        )
                        if let audioTrack = audioTrack {
                            try compositionAudioTrack?.insertTimeRange(
                                piece.range,
                                of: audioTrack,
                                at: cursor
                            )
                        }
                        cursor = CMTimeAdd(cursor, piece.range.duration)
                    }
                }

                // Apply the first clip's preferred transform.
                if let firstURL = clips.first?.url, let transform = transformCache[firstURL] {
                    compositionVideoTrack?.preferredTransform = transform
                }

                // Build the video composition for cropping, if needed.
                let videoComposition = makeVideoComposition(
                    composition: composition,
                    cropRect: cropRect,
                    targetSize: resolution.size,
                    targetFPS: frameRate.value
                )

                runExport(
                    composition: composition,
                    videoComposition: videoComposition,
                    format: format,
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
        cropRect: NSRect?,
        targetSize: CGSize?,
        targetFPS: Int?
    ) -> AVMutableVideoComposition? {
        guard let videoTrack = composition.tracks(withMediaType: .video).first else {
            return nil
        }

        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        let fullSize = videoTrack.naturalSize
        let hasCrop = (cropRect != nil && cropRect!.width > 0 && cropRect!.height > 0)

        // The source region we actually use (crop or full).
        let sourceSize = hasCrop ? cropRect!.size : fullSize

        // Build the transform: first translate the crop region to (0,0),
        // then scale to fit the target size, then center.
        var transform = CGAffineTransform.identity

        if hasCrop, let cropRect = cropRect {
            // Crop rect is in top-left origin coordinates; CG transform is bottom-left.
            let translateY = -(fullSize.height - cropRect.origin.y - cropRect.height)
            transform = CGAffineTransform(translationX: -cropRect.origin.x, y: translateY)
        }

        let videoComposition = AVMutableVideoComposition()

        if let targetSize = targetSize {
            // Compute the scale to fit source into target, keeping aspect ratio.
            let srcAspect = sourceSize.width / sourceSize.height
            let dstAspect = targetSize.width / targetSize.height

            let scale: CGFloat
            if srcAspect > dstAspect {
                // Source is wider — fit by width.
                scale = targetSize.width / sourceSize.width
            } else {
                // Source is taller — fit by height.
                scale = targetSize.height / sourceSize.height
            }

            let scaledWidth = sourceSize.width * scale
            let scaledHeight = sourceSize.height * scale
            let offsetX = (targetSize.width - scaledWidth) / 2
            let offsetY = (targetSize.height - scaledHeight) / 2

            // Compose: translate crop → scale → translate to center.
            let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
            let centerTransform = CGAffineTransform(translationX: offsetX, y: offsetY)
            transform = transform.concatenating(scaleTransform).concatenating(centerTransform)

            videoComposition.renderSize = targetSize
        } else {
            videoComposition.renderSize = sourceSize
        }

        instruction.setTransform(transform, at: .zero)

        let fps = targetFPS ?? 30
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

        let instructionGroup = AVMutableVideoCompositionInstruction()
        instructionGroup.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        instructionGroup.layerInstructions = [instruction]
        videoComposition.instructions = [instructionGroup]

        return videoComposition
    }

    private static func runExport(
        composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition?,
        format: ExportFormat,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Remove existing file at destination.
        try? FileManager.default.removeItem(at: outputURL)

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: format.exportPreset
        ) else {
            completion(.failure(BuildError.exportFailed("Could not create export session")))
            return
        }

        session.outputURL = outputURL
        session.outputFileType = format.fileType
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
                        session.error?.localizedDescription ?? "Unknown error"
                    )))
                default:
                    completion(.failure(BuildError.exportFailed("Could not create export session")))
                }
            }
        }
    }
}

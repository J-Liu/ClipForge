// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

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
            case .noKeptSegments: return L("error.noKeptSegments")
            case .trackLoadFailed: return L("error.trackLoadFailed", "")
            case .exportFailed(let msg): return L("error.exportFailed", msg)
            case .exportCancelled: return L("error.exportCancelled")
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .noKeptSegments:
                return L("error.recovery.noKeptSegments")
            case .trackLoadFailed:
                return L("error.recovery.trackLoadFailed")
            case .exportFailed:
                return L("error.recovery.exportFailed")
            case .exportCancelled:
                return nil
            }
        }
    }

    /// Export audio-only clips.
    static func exportAudio(
        clips: [VideoClip],
        segments: [Segment],
        format: AudioExportFormat,
        bitRate: AudioBitRate,
        sampleRate: AudioSampleRate,
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
        timeline.setClipsSync(clips)

        let composition = AVMutableComposition()

        Task {
            do {
                let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )

                var audioTrackCache: [URL: AVAssetTrack] = [:]
                var cursor = CMTime.zero

                for segment in kept {
                    let pieces = timeline.localRanges(for: segment.range)
                    for piece in pieces {
                        let url = piece.clip.url
                        let asset = AVURLAsset(url: url)

                        let audioTrack: AVAssetTrack?
                        if let cached = audioTrackCache[url] {
                            audioTrack = cached
                        } else {
                            audioTrack = try await asset.loadTracks(withMediaType: .audio).first
                            if let t = audioTrack { audioTrackCache[url] = t }
                        }

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

                runAudioExport(
                    composition: composition,
                    format: format,
                    bitRate: bitRate,
                    sampleRate: sampleRate,
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

    private static func runAudioExport(
        composition: AVMutableComposition,
        format: AudioExportFormat,
        bitRate: AudioBitRate,
        sampleRate: AudioSampleRate,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        try? FileManager.default.removeItem(at: outputURL)

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: format.exportPreset
        ) else {
            completion(.failure(BuildError.exportFailed(L("internalError.cannotCreateExportSession"))))
            return
        }

        session.outputURL = outputURL
        session.outputFileType = format.fileType
        session.audioTimePitchAlgorithm = .spectral

        MainViewController.exportSession = session
        PowerManagement.shared.preventSleep()

        var timer: Timer?
        DispatchQueue.main.async {
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let p = Double(session.progress)
                progress(p)
            }
            if let t = timer {
                RunLoop.main.add(t, forMode: .common)
            }
        }

        session.exportAsynchronously {
            DispatchQueue.main.async {
                timer?.invalidate()
                timer = nil
                MainViewController.exportSession = nil
                PowerManagement.shared.allowSleep()
            }
            DispatchQueue.main.async {
                switch session.status {
                case .completed:
                    progress(1.0)
                    completion(.success(()))
                case .cancelled:
                    completion(.failure(BuildError.exportCancelled))
                case .failed:
                    completion(.failure(BuildError.exportFailed(
                        session.error?.localizedDescription ?? L("internalError.unknownError")
                    )))
                default:
                    completion(.failure(BuildError.exportFailed(L("internalError.cannotCreateExportSession"))))
                }
            }
        }
    }

    /// Export kept segments to the given output URL.
    /// - Parameters:
    ///   - clips: all loaded video clips (with their URLs and timeline positions)
    ///   - segments: all segments on the global timeline, with isKept marking which to include
    ///   - cropRect: optional crop rectangle in video pixel coordinates
    ///   - rotation: additional rotation angle in degrees (0, 90, -90, 180, -180, 270, -270)
    ///   - horizontalFlip: whether to flip the video horizontally
    ///   - verticalFlip: whether to flip the video vertically
    ///   - outputURL: destination file URL
    ///   - progress: called on main thread with 0.0...1.0
    ///   - completion: called on main thread with success or error
    static func export(
        clips: [VideoClip],
        segments: [Segment],
        cropRect: NSRect?,
        rotation: CGFloat,
        horizontalFlip: Bool,
        verticalFlip: Bool,
        resolution: ExportResolution,
        frameRate: ExportFrameRate,
        format: ExportFormat,
        videoBitRate: VideoBitRate,
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
                var baseTransform = CGAffineTransform.identity
                if let firstURL = clips.first?.url, let transform = transformCache[firstURL] {
                    baseTransform = transform
                }

                // Get source video bitrate for "Original" option
                var sourceBitRate: Int = 10_000_000 // Default fallback
                if let firstClip = clips.first {
                    let sourceAsset = AVAsset(url: firstClip.url)
                    if let videoTrack = try? await sourceAsset.loadTracks(withMediaType: .video).first {
                        if let rate = try? await videoTrack.load(.estimatedDataRate) {
                            sourceBitRate = Int(rate)
                        }
                    }
                }

                // Apply rotation to preferredTransform
                if rotation != 0 {
                    let rotationRadians = rotation * .pi / 180
                    let rotationTransform = CGAffineTransform(rotationAngle: rotationRadians)
                    baseTransform = baseTransform.concatenating(rotationTransform)
                }

                compositionVideoTrack?.preferredTransform = baseTransform

                // Build the video composition for cropping, if needed.
                // Pass the rotation so it can be applied in videoComposition for writer export
                let videoComposition = makeVideoComposition(
                    composition: composition,
                    cropRect: cropRect,
                    targetSize: resolution.size,
                    targetFPS: frameRate.value,
                    rotation: rotation,
                    horizontalFlip: horizontalFlip,
                    verticalFlip: verticalFlip
                )

                // Get metadata from first clip
                let firstClipMetadata = clips.first?.metadata

                runExport(
                    composition: composition,
                    videoComposition: videoComposition,
                    format: format,
                    videoBitRate: videoBitRate,
                    sourceBitRate: sourceBitRate,
                    metadata: firstClipMetadata,
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
    /// Also applies rotation if specified.
    private static func makeVideoComposition(
        composition: AVMutableComposition,
        cropRect: NSRect?,
        targetSize: CGSize?,
        targetFPS: Int?,
        rotation: CGFloat = 0,
        horizontalFlip: Bool = false,
        verticalFlip: Bool = false
    ) -> AVMutableVideoComposition? {
        guard let videoTrack = composition.tracks(withMediaType: .video).first else {
            return nil
        }

        let hasCrop = (cropRect != nil && cropRect!.width > 0 && cropRect!.height > 0)

        // Check if crop is effectively the full frame (no actual cropping)
        let isFullFrameCrop: Bool
        if hasCrop, let cropRect = cropRect {
            let trackSize = videoTrack.naturalSize
            isFullFrameCrop = (cropRect.origin.x == 0 && cropRect.origin.y == 0 &&
                               abs(cropRect.width - trackSize.width) < 1 &&
                               abs(cropRect.height - trackSize.height) < 1)
        } else {
            isFullFrameCrop = false
        }

        // If crop is the full frame, treat it as no crop
        let effectiveHasCrop = hasCrop && !isFullFrameCrop

        let hasTargetSize = targetSize != nil
        let hasTargetFPS = targetFPS != nil
        let hasRotation = rotation != 0

        Log("makeVideoComposition: cropRect=\(cropRect ?? .zero), rotation=\(rotation), hasCrop=\(effectiveHasCrop), hasRotation=\(hasRotation)")

        // Rotation is handled via preferredTransform for passthrough export.
        // Only create videoComposition if there's actual crop, target size, or target FPS.
        // If ONLY rotation, return nil to allow passthrough (rotation via preferredTransform).
        if !effectiveHasCrop && !hasTargetSize && !hasTargetFPS {
            return nil
        }

        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)

        let fullSize = videoTrack.naturalSize
        // The source region we actually use (crop or full).
        let sourceSize = effectiveHasCrop ? cropRect!.size : fullSize

        // Determine render sizes
        let baseRenderSize: CGSize
        if let targetSize = targetSize {
            baseRenderSize = targetSize
        } else {
            baseRenderSize = sourceSize
        }

        // Final render size accounting for rotation (swapped dimensions for 90°/270°)
        var finalRenderSize = baseRenderSize
        if hasRotation {
            let absRotation = abs(Int(rotation) % 360)
            if absRotation == 90 || absRotation == 270 {
                finalRenderSize = CGSize(width: baseRenderSize.height, height: baseRenderSize.width)
            }
        }

        Log("makeVideoComposition: sourceSize=\(sourceSize), baseRenderSize=\(baseRenderSize), finalRenderSize=\(finalRenderSize), hasRotation=\(hasRotation)")

        // Build the transform
        // When there's rotation AND crop, we need to:
        // 1. Rotate the source frame first
        // 2. Then crop in the rotated coordinate system
        var transform = CGAffineTransform.identity

        if hasRotation {
            // First apply rotation around the center of the FULL source frame
            let rotationRadians = rotation * .pi / 180
            let centerX = fullSize.width / 2
            let centerY = fullSize.height / 2

            let fromCenter = CGAffineTransform(translationX: -centerX, y: -centerY)
            let rotate = CGAffineTransform(rotationAngle: rotationRadians)
            let toCenter = CGAffineTransform(translationX: centerX, y: centerY)

            transform = transform.concatenating(fromCenter).concatenating(rotate).concatenating(toCenter)
            Log("makeVideoComposition: applying rotation=\(rotation)° around center (\(centerX), \(centerY))")
        }

        if effectiveHasCrop, let cropRect = cropRect {
            // Crop is in original coordinates. After rotation, we need to transform the crop position.

            if hasRotation {
                // When there's rotation, transform crop coordinates to the rotated system
                let absRotation = abs(Int(rotation) % 360)

                // Calculate where the crop region ends up after rotation
                let cropCenterX = cropRect.origin.x + cropRect.width / 2
                let cropCenterY = cropRect.origin.y + cropRect.height / 2

                // Center of original frame
                let frameCenterX = fullSize.width / 2
                let frameCenterY = fullSize.height / 2

                // Rotate crop center around frame center
                let dx = cropCenterX - frameCenterX
                let dy = frameCenterY - cropCenterY  // Flip Y for bottom-left origin

                var newCenterX: CGFloat, newCenterY: CGFloat
                if absRotation == 90 || absRotation == 270 {
                    // After 90° rotation, (dx, dy) → (dy, -dx) or similar
                    if rotation > 0 {  // Counter-clockwise
                        newCenterX = frameCenterX + dy
                        newCenterY = frameCenterY + dx
                    } else {  // Clockwise
                        newCenterX = frameCenterX - dy
                        newCenterY = frameCenterY - dx
                    }
                } else {
                    // 180° rotation
                    newCenterX = frameCenterX - dx
                    newCenterY = frameCenterY - dy
                }

                // Translate so the rotated crop center is at the render center
                let renderCenterX = finalRenderSize.width / 2
                let renderCenterY = finalRenderSize.height / 2

                let translateX = renderCenterX - newCenterX
                let translateY = renderCenterY - newCenterY

                let cropTranslate = CGAffineTransform(translationX: translateX, y: translateY)
                transform = transform.concatenating(cropTranslate)
                Log("makeVideoComposition: applying crop translation after rotation: x=\(translateX), y=\(translateY)")
            } else {
                // No rotation: simple crop translation
                let translateY = -(fullSize.height - cropRect.origin.y - cropRect.height)
                let cropTranslate = CGAffineTransform(translationX: -cropRect.origin.x, y: translateY)
                transform = transform.concatenating(cropTranslate)
                Log("makeVideoComposition: applying crop translation: x=\(-cropRect.origin.x), y=\(translateY)")
            }
        }

        // Apply flip transformations after rotation and crop
        if horizontalFlip || verticalFlip {
            let scaleX: CGFloat = horizontalFlip ? -1 : 1
            let scaleY: CGFloat = verticalFlip ? -1 : 1

            // Flip around the center of the render
            let centerX = finalRenderSize.width / 2
            let centerY = finalRenderSize.height / 2

            let fromCenter = CGAffineTransform(translationX: -centerX, y: -centerY)
            let flip = CGAffineTransform(scaleX: scaleX, y: scaleY)
            let toCenter = CGAffineTransform(translationX: centerX, y: centerY)

            transform = transform.concatenating(fromCenter).concatenating(flip).concatenating(toCenter)
            Log("makeVideoComposition: applying flip h=\(horizontalFlip), v=\(verticalFlip)")
        }

        let videoComposition = AVMutableVideoComposition()

        if let targetSize = targetSize {
            // Compute the scale to fit source into target, keeping aspect ratio.
            let srcAspect = finalRenderSize.width / finalRenderSize.height
            let dstAspect = targetSize.width / targetSize.height

            let scale: CGFloat
            if srcAspect > dstAspect {
                // Source is wider — fit by width.
                scale = targetSize.width / finalRenderSize.width
            } else {
                // Source is taller — fit by height.
                scale = targetSize.height / finalRenderSize.height
            }

            let scaledWidth = finalRenderSize.width * scale
            let scaledHeight = finalRenderSize.height * scale
            let offsetX = (targetSize.width - scaledWidth) / 2
            let offsetY = (targetSize.height - scaledHeight) / 2

            // Compose: translate crop → scale → translate to center.
            let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
            let centerTransform = CGAffineTransform(translationX: offsetX, y: offsetY)
            transform = transform.concatenating(scaleTransform).concatenating(centerTransform)

            videoComposition.renderSize = targetSize
            Log("makeVideoComposition: targetSize=\(targetSize), scale=\(scale), renderSize=\(targetSize)")
        } else {
            videoComposition.renderSize = finalRenderSize
            Log("makeVideoComposition: no targetSize, renderSize=\(finalRenderSize)")
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
        videoBitRate: VideoBitRate,
        sourceBitRate: Int,
        metadata: VideoMetadata?,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Remove existing file at destination.
        try? FileManager.default.removeItem(at: outputURL)

        // Can use passthrough only if: format == passthrough AND no crop AND bitrate is original
        let canPassthrough = format == .passthrough && videoComposition == nil && videoBitRate == .original

        if canPassthrough {
            // Direct passthrough - no re-encoding needed
            runPassthroughExport(
                composition: composition,
                metadata: metadata,
                outputURL: outputURL,
                progress: progress,
                completion: completion
            )
            return
        }

        // Determine target bitrate
        let targetBitRate: Int
        if let bitRate = videoBitRate.value {
            targetBitRate = bitRate
        } else {
            // Original - use source bitrate
            targetBitRate = sourceBitRate
        }

        // Use AVAssetWriter for re-encoding with bitrate control
        runExportWithWriter(
            composition: composition,
            videoComposition: videoComposition,
            format: format,
            targetBitRate: targetBitRate,
            metadata: metadata,
            outputURL: outputURL,
            progress: progress,
            completion: completion
        )
    }

    /// Direct passthrough export - no re-encoding
    private static func runPassthroughExport(
        composition: AVMutableComposition,
        metadata: VideoMetadata?,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            completion(.failure(BuildError.exportFailed(L("internalError.cannotCreateExportSession"))))
            return
        }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        // Apply metadata if available
        if let meta = metadata {
            session.metadata = meta.toMetadataItems()
        }

        // Store session for cancellation
        MainViewController.exportSession = session
        PowerManagement.shared.preventSleep()

        // Poll progress on a timer on the main thread.
        var timer: Timer?
        DispatchQueue.main.async {
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let p = Double(session.progress)
                progress(p)
            }
            if let t = timer {
                RunLoop.main.add(t, forMode: .common)
            }
        }

        session.exportAsynchronously {
            DispatchQueue.main.async {
                timer?.invalidate()
                timer = nil
                MainViewController.exportSession = nil
                PowerManagement.shared.allowSleep()
            }
            DispatchQueue.main.async {
                switch session.status {
                case .completed:
                    progress(1.0)
                    completion(.success(()))
                case .cancelled:
                    completion(.failure(BuildError.exportCancelled))
                case .failed:
                    completion(.failure(BuildError.exportFailed(
                        session.error?.localizedDescription ?? L("internalError.unknownError")
                    )))
                default:
                    completion(.failure(BuildError.exportFailed(L("internalError.cannotCreateExportSession"))))
                }
            }
        }
    }

    /// Export using AVAssetWriter for precise bitrate control.
    private static func runExportWithWriter(
        composition: AVMutableComposition,
        videoComposition: AVMutableVideoComposition?,
        format: ExportFormat,
        targetBitRate: Int,
        metadata: VideoMetadata?,
        outputURL: URL,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Wrapper to hold writer/reader references for Sendable closure
        final class ExportContext: @unchecked Sendable {
            var writer: AVAssetWriter?
            var reader: AVAssetReader?
            var videoInput: AVAssetWriterInput?
            var audioInput: AVAssetWriterInput?
            var videoOutput: AVAssetReaderOutput?
            var audioOutput: AVAssetReaderAudioMixOutput?
        }

        let ctx = ExportContext()
        PowerManagement.shared.preventSleep()

        // Use asset reader/writer for precise control
        Task.detached {
            do {
                // Get video track
                guard let videoTrack = composition.tracks(withMediaType: .video).first else {
                    await MainActor.run {
                        PowerManagement.shared.allowSleep()
                        completion(.failure(BuildError.trackLoadFailed))
                    }
                    return
                }

                // Determine output size
                let outputSize: CGSize
                if let videoComposition = videoComposition {
                    outputSize = videoComposition.renderSize
                } else {
                    outputSize = videoTrack.naturalSize
                }

                // Create asset writer
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: format.fileType)
                ctx.writer = writer

                // Apply metadata if available
                if let meta = metadata {
                    writer.metadata = meta.toMetadataItems()
                }

                // Video settings with target bitrate
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(outputSize.width),
                    AVVideoHeightKey: Int(outputSize.height),
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: targetBitRate,
                        AVVideoExpectedSourceFrameRateKey: 30,
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                    ]
                ]

                let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                videoInput.expectsMediaDataInRealTime = false
                ctx.videoInput = videoInput

                guard writer.canAdd(videoInput) else {
                    await MainActor.run {
                        PowerManagement.shared.allowSleep()
                        completion(.failure(BuildError.exportFailed("Cannot add video input to writer")))
                    }
                    return
                }
                writer.add(videoInput)

                // Audio input (passthrough)
                let audioTracks = composition.tracks(withMediaType: .audio)
                if !audioTracks.isEmpty {
                    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
                    if writer.canAdd(audioInput) {
                        writer.add(audioInput)
                        ctx.audioInput = audioInput
                    }
                }

                // Create asset reader
                let reader = try AVAssetReader(asset: composition)
                ctx.reader = reader

                // Video output - use video composition output for cropping support
                let videoOutput: AVAssetReaderOutput
                if let videoComposition = videoComposition {
                    // AVAssetReaderVideoCompositionOutput applies the video composition
                    let compositionOutput = AVAssetReaderVideoCompositionOutput(
                        videoTracks: [videoTrack],
                        videoSettings: [
                            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
                        ]
                    )
                    compositionOutput.videoComposition = videoComposition
                    videoOutput = compositionOutput
                } else {
                    // Passthrough without composition
                    let trackOutput = AVAssetReaderTrackOutput(
                        track: videoTrack,
                        outputSettings: [
                            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
                        ]
                    )
                    trackOutput.alwaysCopiesSampleData = false
                    videoOutput = trackOutput
                }
                reader.add(videoOutput)
                ctx.videoOutput = videoOutput

                // Audio output
                if let audioTrack = composition.tracks(withMediaType: .audio).first {
                    let output = AVAssetReaderAudioMixOutput(audioTracks: [audioTrack], audioSettings: nil)
                    reader.add(output)
                    ctx.audioOutput = output
                }

                guard reader.startReading() else {
                    let error = reader.error?.localizedDescription ?? "Failed to start reading"
                    await MainActor.run {
                        PowerManagement.shared.allowSleep()
                        completion(.failure(BuildError.exportFailed(error)))
                    }
                    return
                }

                guard writer.startWriting() else {
                    let error = writer.error?.localizedDescription ?? "Failed to start writing"
                    await MainActor.run {
                        PowerManagement.shared.allowSleep()
                        completion(.failure(BuildError.exportFailed(error)))
                    }
                    return
                }

                writer.startSession(atSourceTime: CMTime(value: 0, timescale: 1000))

                let totalDuration = CMTimeGetSeconds(composition.duration)
                let videoQueue = DispatchQueue(label: "video.encode")
                let audioQueue = DispatchQueue(label: "audio.encode")

                // Use @unchecked Sendable wrapper for state
                final class ExportState: @unchecked Sendable {
                    var videoFinished = false
                    var audioFinished = false
                    var lastProgressUpdate: Double = 0
                }
                let state = ExportState()

                // Write video
                guard ctx.videoInput != nil, ctx.videoOutput != nil else {
                    await MainActor.run {
                        PowerManagement.shared.allowSleep()
                        completion(.failure(BuildError.exportFailed("No video input/output")))
                    }
                    return
                }

                ctx.videoInput?.requestMediaDataWhenReady(on: videoQueue) {
                    guard let vi = ctx.videoInput, let vo = ctx.videoOutput else { return }
                    while vi.isReadyForMoreMediaData {
                        if let sampleBuffer = vo.copyNextSampleBuffer() {
                            // Update progress
                            let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                            let currentSeconds = CMTimeGetSeconds(currentTime)
                            let currentProgress = currentSeconds / totalDuration

                            if currentProgress - state.lastProgressUpdate > 0.01 {
                                state.lastProgressUpdate = currentProgress
                                DispatchQueue.main.async {
                                    progress(currentProgress)
                                }
                            }

                            if !vi.append(sampleBuffer) {
                                break
                            }
                        } else {
                            vi.markAsFinished()
                            state.videoFinished = true
                            break
                        }
                    }

                    // Check if done
                    if state.videoFinished && state.audioFinished {
                        ctx.writer?.finishWriting {
                            DispatchQueue.main.async {
                                PowerManagement.shared.allowSleep()
                                if ctx.writer?.status == .completed {
                                    progress(1.0)
                                    completion(.success(()))
                                } else {
                                    completion(.failure(BuildError.exportFailed(
                                        ctx.writer?.error?.localizedDescription ?? "Unknown error"
                                    )))
                                }
                            }
                        }
                    }
                }

                // Write audio
                if ctx.audioInput != nil && ctx.audioOutput != nil {
                    ctx.audioInput?.requestMediaDataWhenReady(on: audioQueue) { [ctx] in
                        guard let ai = ctx.audioInput, let ao = ctx.audioOutput else { return }
                        while ai.isReadyForMoreMediaData {
                            if let sampleBuffer = ao.copyNextSampleBuffer() {
                                if !ai.append(sampleBuffer) {
                                    break
                                }
                            } else {
                                ai.markAsFinished()
                                state.audioFinished = true
                                break
                            }
                        }

                        // Check if done
                        if state.videoFinished && state.audioFinished {
                            ctx.writer?.finishWriting {
                                DispatchQueue.main.async {
                                    PowerManagement.shared.allowSleep()
                                    if ctx.writer?.status == .completed {
                                        progress(1.0)
                                        completion(.success(()))
                                    } else {
                                        completion(.failure(BuildError.exportFailed(
                                            ctx.writer?.error?.localizedDescription ?? "Unknown error"
                                        )))
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // No audio, mark as finished immediately
                    state.audioFinished = true
                }

            } catch {
                await MainActor.run {
                    PowerManagement.shared.allowSleep()
                    completion(.failure(error))
                }
            }
        }
    }
}

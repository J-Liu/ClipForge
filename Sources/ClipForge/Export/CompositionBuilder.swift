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

                runExport(
                    composition: composition,
                    videoComposition: videoComposition,
                    format: format,
                    videoBitRate: videoBitRate,
                    sourceBitRate: sourceBitRate,
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
        videoBitRate: VideoBitRate,
        sourceBitRate: Int,
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
            outputURL: outputURL,
            progress: progress,
            completion: completion
        )
    }

    /// Direct passthrough export - no re-encoding
    private static func runPassthroughExport(
        composition: AVMutableComposition,
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

        // Store session for cancellation
        MainViewController.exportSession = session

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

        // Use asset reader/writer for precise control
        Task.detached {
            do {
                // Get video track
                guard let videoTrack = composition.tracks(withMediaType: .video).first else {
                    await MainActor.run { completion(.failure(BuildError.trackLoadFailed)) }
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
                    await MainActor.run { completion(.failure(BuildError.exportFailed("Cannot add video input to writer"))) }
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
                    await MainActor.run { completion(.failure(BuildError.exportFailed(error))) }
                    return
                }

                guard writer.startWriting() else {
                    let error = writer.error?.localizedDescription ?? "Failed to start writing"
                    await MainActor.run { completion(.failure(BuildError.exportFailed(error))) }
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
                    await MainActor.run { completion(.failure(BuildError.exportFailed("No video input/output"))) }
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
                    completion(.failure(error))
                }
            }
        }
    }
}

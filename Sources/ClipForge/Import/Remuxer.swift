// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026 Jia Liu

import Foundation

/// Remuxes video files from unsupported containers (MKV, etc.) to MP4.
/// Uses FFmpeg for container conversion without re-encoding.
final class Remuxer {

    enum RemuxerError: LocalizedError {
        case ffmpegNotAvailable
        case unsupportedCodec(String)
        case remuxFailed(String)
        case probeFailed(String)

        var errorDescription: String? {
            switch self {
            case .ffmpegNotAvailable:
                return L("error.ffmpegNotAvailable")
            case .unsupportedCodec(let codec):
                return L("error.unsupportedCodec", codec)
            case .remuxFailed(let message):
                return L("error.remuxFailed", message)
            case .probeFailed(let message):
                return L("error.probeFailed", message)
            }
        }
    }

    /// Stream information from FFmpeg probe
    struct ProbeResult {
        let duration: Double
        let videoCodec: String?
        let audioCodec: String?
        let hasVideo: Bool
        let hasAudio: Bool
    }

    /// Result of remux operation
    struct RemuxResult {
        let outputURL: URL
        let duration: Double
    }

    /// Check if AVFoundation can open the file directly
    static func canAVFoundationOpen(url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            return !tracks.isEmpty
        } catch {
            return false
        }
    }

    /// Probe file to get stream information
    static func probe(url: URL) async throws -> ProbeResult {
        // TODO: Implement with FFmpeg ffprobe
        // For now, return placeholder
        throw RemuxerError.ffmpegNotAvailable
    }

    /// Check if codecs are compatible with AVFoundation
    static func isCodecCompatible(_ codec: String) -> Bool {
        let compatibleVideoCodecs = ["h264", "hevc", "h265", "avc", "mpeg4"]
        let compatibleAudioCodecs = ["aac", "mp3", "pcm", "alac"]

        let lower = codec.lowercased()
        return compatibleVideoCodecs.contains(lower) || compatibleAudioCodecs.contains(lower)
    }

    /// Remux file to MP4 container
    /// - Parameters:
    ///   - inputURL: Source file URL
    ///   - progress: Progress callback (0.0 - 1.0)
    /// - Returns: URL of remuxed temporary file
    static func remuxToMP4(inputURL: URL, progress: @escaping (Double) -> Void) async throws -> RemuxResult {
        // TODO: Implement with FFmpeg -c copy
        throw RemuxerError.ffmpegNotAvailable
    }
}

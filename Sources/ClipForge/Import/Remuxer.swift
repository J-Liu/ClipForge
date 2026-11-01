// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026 Jia Liu

import AVFoundation
import Foundation
import ffmpegkit

/// Remuxes video files from unsupported containers (MKV, etc.) to MP4.
/// Uses FFmpeg for container conversion without re-encoding.
final class Remuxer {

    enum RemuxerError: LocalizedError {
        case ffmpegNotAvailable
        case unsupportedCodec(String)
        case remuxFailed(String)
        case probeFailed(String)
        case inputFileNotFound

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
            case .inputFileNotFound:
                return L("error.fileNotFound")
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

    /// Supported container extensions for remux
    static let supportedContainers: Set<String> = ["mkv", "avi", "wmv", "flv", "mov", "ts", "m2ts", "webm"]

    /// Check if a file needs remuxing (AVFoundation cannot open it directly)
    static func needsRemux(url: URL) async -> Bool {
        let ext = url.pathExtension.lowercased()
        guard supportedContainers.contains(ext) else { return false }

        // Even if container is in supported list, check if AVFoundation can open it
        return !(await canAVFoundationOpen(url: url))
    }

    /// Check if AVFoundation can open the file directly
    static func canAVFoundationOpen(url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            return !tracks.isEmpty
        } catch {
            // Try audio tracks if no video
            do {
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                return !audioTracks.isEmpty
            } catch {
                return false
            }
        }
    }

    /// Probe file to get stream information using FFprobe
    static func probe(url: URL) async throws -> ProbeResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RemuxerError.inputFileNotFound
        }

        let path = url.path
        var videoCodec: String?
        var audioCodec: String?
        var duration: Double = 0
        var hasVideo = false
        var hasAudio = false

        let session = FFprobeKit.execute("-v quiet -show_streams -show_entries format=duration:stream=codec_name,codec_type \"\(path)\"")

        if let returnCode = session?.getReturnCode(), ReturnCode.isSuccess(returnCode) {
            let output = session?.getOutput() ?? ""

            // Parse the output
            let lines = output.components(separatedBy: .newlines)
            var currentCodecType: String?
            var currentCodecName: String?

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("codec_type=") {
                    currentCodecType = trimmed.replacingOccurrences(of: "codec_type=", with: "")
                } else if trimmed.hasPrefix("codec_name=") {
                    currentCodecName = trimmed.replacingOccurrences(of: "codec_name=", with: "")
                } else if trimmed.hasPrefix("duration=") {
                    let durStr = trimmed.replacingOccurrences(of: "duration=", with: "")
                    duration = Double(durStr) ?? 0
                } else if trimmed.isEmpty || trimmed == "[/STREAM]" || trimmed == "[STREAM]" {
                    // End of stream entry, save the codec info
                    if let codecType = currentCodecType, let codecName = currentCodecName {
                        if codecType == "video" {
                            videoCodec = codecName
                            hasVideo = true
                        } else if codecType == "audio" {
                            audioCodec = codecName
                            hasAudio = true
                        }
                    }
                    currentCodecType = nil
                    currentCodecName = nil
                }
            }

            // Handle last stream if no trailing newline
            if let codecType = currentCodecType, let codecName = currentCodecName {
                if codecType == "video" {
                    videoCodec = codecName
                    hasVideo = true
                } else if codecType == "audio" {
                    audioCodec = codecName
                    hasAudio = true
                }
            }
        } else {
            let output = session?.getOutput() ?? "Unknown error"
            throw RemuxerError.probeFailed(output)
        }

        return ProbeResult(
            duration: duration,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            hasVideo: hasVideo,
            hasAudio: hasAudio
        )
    }

    /// Check if codecs are compatible with AVFoundation/MP4 container
    static func isCodecCompatible(_ codec: String) -> Bool {
        let compatibleVideoCodecs = ["h264", "hevc", "h265", "avc", "mpeg4", "prores"]
        let compatibleAudioCodecs = ["aac", "mp3", "pcm", "alac", "ac3"]

        let lower = codec.lowercased()
        return compatibleVideoCodecs.contains(lower) || compatibleAudioCodecs.contains(lower)
    }

    /// Remux file to MP4 container
    /// - Parameters:
    ///   - inputURL: Source file URL
    ///   - progress: Progress callback (0.0 - 1.0)
    /// - Returns: URL of remuxed temporary file
    static func remuxToMP4(inputURL: URL, progress: @escaping (Double) -> Void) async throws -> RemuxResult {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw RemuxerError.inputFileNotFound
        }

        // Probe the file first
        let probeResult = try await probe(url: inputURL)

        // Check if codecs are compatible
        if let videoCodec = probeResult.videoCodec, !isCodecCompatible(videoCodec) {
            throw RemuxerError.unsupportedCodec(videoCodec)
        }
        if let audioCodec = probeResult.audioCodec, !isCodecCompatible(audioCodec) {
            throw RemuxerError.unsupportedCodec(audioCodec)
        }

        // Create output URL in temp directory
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        let outputURL = tempDir.appendingPathComponent("\(fileName)_\(UUID().uuidString).mp4")

        // Remove existing file if any
        try? FileManager.default.removeItem(at: outputURL)

        let inputPath = inputURL.path
        let outputPath = outputURL.path

        // Execute FFmpeg with -c copy for remuxing (no re-encoding)
        let arguments = "-i \"\(inputPath)\" -c copy -map 0 -y \"\(outputPath)\""

        let session = FFmpegKit.execute(arguments)

        guard let returnCode = session?.getReturnCode() else {
            throw RemuxerError.remuxFailed("FFmpeg session failed to start")
        }

        if ReturnCode.isSuccess(returnCode) {
            // Verify the output file exists
            guard FileManager.default.fileExists(atPath: outputPath) else {
                throw RemuxerError.remuxFailed("Output file was not created")
            }
            return RemuxResult(outputURL: outputURL, duration: probeResult.duration)
        } else {
            let output = session?.getOutput() ?? "Unknown error"
            throw RemuxerError.remuxFailed(output)
        }
    }
}

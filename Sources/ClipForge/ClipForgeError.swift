// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation
import ScreenCaptureKit

enum ClipForgeError: LocalizedError {
    case noVideoLoaded
    case noKeptSegments
    case trackLoadFailed(String)
    case exportFailed(String)
    case exportCancelled
    case recordingFailed(String)
    case screenRecordingPermissionDenied
    case microphonePermissionDenied
    case outputDirectoryNotWritable(String)

    var errorDescription: String? {
        switch self {
        case .noVideoLoaded:
            return "No video loaded"
        case .noKeptSegments:
            return "Nothing to export"
        case .trackLoadFailed(let detail):
            return "Failed to load video track: \(detail)"
        case .exportFailed(let detail):
            return "Export failed: \(detail)"
        case .exportCancelled:
            return "Export cancelled"
        case .recordingFailed(let detail):
            return "Recording failed: \(detail)"
        case .screenRecordingPermissionDenied:
            return "Screen recording permission denied"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        case .outputDirectoryNotWritable(let path):
            return "Cannot write to output folder: \(path)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noVideoLoaded:
            return "Open a video before exporting."
        case .noKeptSegments:
            return "Keep at least one segment before exporting."
        case .trackLoadFailed:
            return "The file may be corrupted or use an unsupported codec."
        case .exportFailed:
            return "Try a different output location, or choose a lower resolution."
        case .exportCancelled:
            return nil
        case .recordingFailed:
            return "Make sure you have enough disk space and the target is still available."
        case .screenRecordingPermissionDenied:
            return "Go to System Settings → Privacy & Security → Screen Recording and enable ClipForge, then restart the app."
        case .microphonePermissionDenied:
            return "Go to System Settings → Privacy & Security → Microphone and enable ClipForge, then restart the app."
        case .outputDirectoryNotWritable:
            return "Choose a different output folder in Settings → Recording."
        }
    }

    /// Convert an arbitrary error into a ClipForgeError, preserving intent where possible.
    static func from(_ error: Error) -> ClipForgeError {
        if let cf = error as? ClipForgeError {
            return cf
        }
        if let sc = error as? SCStreamError, sc.code == .userDeclined {
            return .screenRecordingPermissionDenied
        }
        let ns = error as NSError
        if ns.domain == AVFoundationErrorDomain {
            return .recordingFailed(ns.localizedDescription)
        }
        return .recordingFailed(ns.localizedDescription)
    }
}

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation
import AVFoundation
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
            return L("error.noVideoLoaded")
        case .noKeptSegments:
            return L("error.noKeptSegments")
        case .trackLoadFailed(let detail):
            return L("error.trackLoadFailed", detail)
        case .exportFailed(let detail):
            return L("error.exportFailed", detail)
        case .exportCancelled:
            return L("error.exportCancelled")
        case .recordingFailed(let detail):
            return L("error.recordingFailed", detail)
        case .screenRecordingPermissionDenied:
            return L("error.screenRecordingPermissionDenied")
        case .microphonePermissionDenied:
            return L("error.microphonePermissionDenied")
        case .outputDirectoryNotWritable(let path):
            return L("error.outputDirectoryNotWritable", path)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noVideoLoaded:
            return L("error.recovery.noVideoLoaded")
        case .noKeptSegments:
            return L("error.recovery.noKeptSegments")
        case .trackLoadFailed:
            return L("error.recovery.trackLoadFailed")
        case .exportFailed:
            return L("error.recovery.exportFailed")
        case .exportCancelled:
            return nil
        case .recordingFailed:
            return L("error.recovery.recordingFailed")
        case .screenRecordingPermissionDenied:
            return L("error.recovery.screenRecordingPermissionDenied")
        case .microphonePermissionDenied:
            return L("error.recovery.microphonePermissionDenied")
        case .outputDirectoryNotWritable:
            return L("error.recovery.outputDirectoryNotWritable")
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

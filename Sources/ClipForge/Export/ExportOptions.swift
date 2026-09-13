// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AVFoundation
import CoreGraphics

enum ExportResolution: String, CaseIterable {
    case original
    case p1080
    case p720
    case p480

    var localizedName: String {
        switch self {
        case .original: return L("export.original")
        case .p1080: return L("export.1080p")
        case .p720: return L("export.720p")
        case .p480: return L("export.480p")
        }
    }

    var size: CGSize? {
        switch self {
        case .original: return nil
        case .p1080: return CGSize(width: 1920, height: 1080)
        case .p720: return CGSize(width: 1280, height: 720)
        case .p480: return CGSize(width: 854, height: 480)
        }
    }
}

enum ExportFrameRate: String, CaseIterable {
    case original
    case fps30
    case fps60

    var localizedName: String {
        switch self {
        case .original: return L("export.original")
        case .fps30: return L("export.30fps")
        case .fps60: return L("export.60fps")
        }
    }

    var value: Int? {
        switch self {
        case .original: return nil
        case .fps30: return 30
        case .fps60: return 60
        }
    }
}

enum ExportFormat: String, CaseIterable {
    case mp4h264
    case mp4h265
    case mov

    var localizedName: String {
        switch self {
        case .mp4h264: return L("export.mp4h264")
        case .mp4h265: return L("export.mp4h265")
        case .mov: return L("export.mov")
        }
    }

    var fileType: AVFileType {
        switch self {
        case .mp4h264, .mp4h265: return .mp4
        case .mov: return .mov
        }
    }

    var fileExtension: String {
        switch self {
        case .mp4h264, .mp4h265: return "mp4"
        case .mov: return "mov"
        }
    }

    var exportPreset: String {
        switch self {
        case .mp4h265: return AVAssetExportPresetHEVCHighestQuality
        default: return AVAssetExportPresetHighestQuality
        }
    }
}

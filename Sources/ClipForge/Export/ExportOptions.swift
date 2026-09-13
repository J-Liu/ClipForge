import AVFoundation
import CoreGraphics

enum ExportResolution: String, CaseIterable {
    case original
    case p1080
    case p720
    case p480

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .p1080: return "1080p"
        case .p720: return "720p"
        case .p480: return "480p"
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

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .fps30: return "30 fps"
        case .fps60: return "60 fps"
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

    var displayName: String {
        switch self {
        case .mp4h264: return "MP4 (H.264)"
        case .mp4h265: return "MP4 (H.265)"
        case .mov: return "MOV"
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


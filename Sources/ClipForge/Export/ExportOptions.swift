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
    case passthrough
    case mp4h264
    case mp4h265
    case mov

    var localizedName: String {
        switch self {
        case .passthrough: return L("export.passthrough")
        case .mp4h264: return L("export.mp4h264")
        case .mp4h265: return L("export.mp4h265")
        case .mov: return L("export.mov")
        }
    }

    var fileType: AVFileType {
        switch self {
        case .passthrough, .mp4h264, .mp4h265: return .mp4
        case .mov: return .mov
        }
    }

    var fileExtension: String {
        switch self {
        case .passthrough, .mp4h264, .mp4h265: return "mp4"
        case .mov: return "mov"
        }
    }

    var exportPreset: String {
        switch self {
        case .passthrough: return AVAssetExportPresetPassthrough
        case .mp4h265: return AVAssetExportPresetHEVCHighestQuality
        default: return AVAssetExportPresetHighestQuality
        }
    }
}

// MARK: - Audio Export Options

enum AudioExportFormat: String, CaseIterable {
    case mp3
    case aac
    case wav

    var localizedName: String {
        switch self {
        case .mp3: return "MP3"
        case .aac: return "AAC (M4A)"
        case .wav: return "WAV"
        }
    }

    var fileType: AVFileType {
        switch self {
        case .mp3: return .mp3
        case .aac: return .m4a
        case .wav: return .wav
        }
    }

    var fileExtension: String {
        switch self {
        case .mp3: return "mp3"
        case .aac: return "m4a"
        case .wav: return "wav"
        }
    }

    var exportPreset: String {
        switch self {
        case .mp3: return AVAssetExportPresetPassthrough  // Will convert manually
        case .aac: return AVAssetExportPresetAppleM4A
        case .wav: return AVAssetExportPresetPassthrough
        }
    }
}

enum AudioBitRate: String, CaseIterable {
    case k128
    case k192
    case k256
    case k320

    var localizedName: String {
        switch self {
        case .k128: return "128 kbps"
        case .k192: return "192 kbps"
        case .k256: return "256 kbps"
        case .k320: return "320 kbps"
        }
    }

    var value: Int {
        switch self {
        case .k128: return 128_000
        case .k192: return 192_000
        case .k256: return 256_000
        case .k320: return 320_000
        }
    }
}

enum AudioSampleRate: String, CaseIterable {
    case hz44100
    case hz48000
    case hz96000

    var localizedName: String {
        switch self {
        case .hz44100: return "44.1 kHz"
        case .hz48000: return "48 kHz"
        case .hz96000: return "96 kHz"
        }
    }

    var value: Double {
        switch self {
        case .hz44100: return 44100
        case .hz48000: return 48000
        case .hz96000: return 96000
        }
    }
}

// MARK: - Video Bit Rate

enum VideoBitRate: String, CaseIterable {
    case original
    case mbps5
    case mbps10
    case mbps15
    case mbps20
    case mbps30

    var localizedName: String {
        switch self {
        case .original: return L("export.original")
        case .mbps5: return "5 Mbps"
        case .mbps10: return "10 Mbps"
        case .mbps15: return "15 Mbps"
        case .mbps20: return "20 Mbps"
        case .mbps30: return "30 Mbps"
        }
    }

    var value: Int? {
        switch self {
        case .original: return nil
        case .mbps5: return 5_000_000
        case .mbps10: return 10_000_000
        case .mbps15: return 15_000_000
        case .mbps20: return 20_000_000
        case .mbps30: return 30_000_000
        }
    }
}

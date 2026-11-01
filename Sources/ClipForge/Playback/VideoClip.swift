// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import AVFoundation
import CoreMedia
import CoreLocation

/// Metadata from a video file that should be preserved during export.
struct VideoMetadata {
    /// Creation date of the original video.
    let creationDate: Date?
    /// Location where the video was recorded (GPS coordinates).
    let location: CLLocation?
    /// Device/model that created the video.
    let deviceModel: String?
    /// Software used to create the video.
    let software: String?
    /// Description/comment.
    let description: String?

    /// Extract metadata from an AVAsset.
    static func from(asset: AVAsset) async -> VideoMetadata {
        // Load creation date - iterate through metadata to find it
        var creationDate: Date?
        let metadata = try? await asset.load(.commonMetadata)
        for item in metadata ?? [] {
            guard let key = item.commonKey else { continue }
            if key == .commonKeyCreationDate {
                if let date = try? await item.load(.dateValue) {
                    creationDate = date
                }
            }
        }

        // Load location from metadata
        var location: CLLocation?
        for item in metadata ?? [] {
            guard let key = item.commonKey else { continue }
            if key == .commonKeyLocation {
                // Parse location string "lat,lon" or ISO 6709 format
                if let locString = try? await item.load(.stringValue),
                   let loc = parseLocation(locString) {
                    location = loc
                }
            }
        }

        // Load other metadata items from common metadata space
        var deviceModel: String?
        var software: String?
        var description: String?

        for item in metadata ?? [] {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyModel:
                deviceModel = try? await item.load(.stringValue)
            case .commonKeySoftware:
                software = try? await item.load(.stringValue)
            case .commonKeyDescription:
                description = try? await item.load(.stringValue)
            default:
                break
            }
        }

        return VideoMetadata(
            creationDate: creationDate,
            location: location,
            deviceModel: deviceModel,
            software: software,
            description: description
        )
    }

    /// Parse location string (various formats)
    private static func parseLocation(_ string: String) -> CLLocation? {
        // Try simple "lat,lon" format
        let parts = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2,
           let lat = Double(parts[0]),
           let lon = Double(parts[1]) {
            return CLLocation(latitude: lat, longitude: lon)
        }
        return nil
    }

    /// Create AVMetadataItems from this metadata for export.
    /// Only includes metadata that should be preserved.
    func toMetadataItems() -> [AVMetadataItem] {
        var items: [AVMetadataItem] = []

        if let date = creationDate {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierCreationDate
            item.value = date as NSDate
            items.append(item)
        }

        if let loc = location {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierLocation
            // Format as "lat,lon" string
            let locString = "\(loc.coordinate.latitude),\(loc.coordinate.longitude)"
            item.value = locString as NSString
            items.append(item)
        }

        if let model = deviceModel {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierModel
            item.value = model as NSString
            items.append(item)
        }

        if let sw = software {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierSoftware
            item.value = sw as NSString
            items.append(item)
        }

        if let desc = description {
            let item = AVMutableMetadataItem()
            item.identifier = .commonIdentifierDescription
            item.value = desc as NSString
            items.append(item)
        }

        return items
    }
}

/// One video file loaded into the editor, with its position on the global timeline.
struct VideoClip {
    let url: URL
    let duration: CMTime
    /// Offset of this clip's start on the global timeline.
    let startOnTimeline: CMTime
    /// Metadata from the original video file.
    var metadata: VideoMetadata?

    /// End of this clip on the global timeline.
    var endOnTimeline: CMTime {
        CMTimeAdd(startOnTimeline, duration)
    }

    /// Does this clip contain the given global time?
    func contains(_ globalTime: CMTime) -> Bool {
        let t = CMTimeGetSeconds(globalTime)
        let s = CMTimeGetSeconds(startOnTimeline)
        let e = CMTimeGetSeconds(endOnTimeline)
        return t >= s && t < e
    }

    /// Convert a global time to this clip's local time.
    /// Returns nil if the time is outside the clip.
    func localTime(for globalTime: CMTime) -> CMTime? {
        guard contains(globalTime) else { return nil }
        return CMTimeSubtract(globalTime, startOnTimeline)
    }
}

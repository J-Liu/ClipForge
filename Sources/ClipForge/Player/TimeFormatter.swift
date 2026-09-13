// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation
import CoreMedia

enum TimeFormatter {
    /// Format a CMTime as "MM:SS.mmm" for display.
    static func displayString(from time: CMTime) -> String {
        guard time.isValid, !time.isIndefinite else { return "00:00.000" }
        let totalSeconds = CMTimeGetSeconds(time)
        guard totalSeconds.isFinite, totalSeconds >= 0 else { return "00:00.000" }

        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        let millis = Int((totalSeconds - floor(totalSeconds)) * 1000)

        return String(format: "%02d:%02d.%03d", minutes, seconds, millis)
    }
}

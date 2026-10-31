// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation
import IOKit.pwr_mgt

/// Prevents system sleep during long operations like recording and export.
final class PowerManagement {
    static let shared = PowerManagement()

    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false

    private init() {}

    /// Prevent system sleep and display sleep.
    func preventSleep() {
        guard !hasAssertion else { return }

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "com.jialiu.clipforge.prevent-sleep" as CFString,
            &assertionID
        )

        if result == kIOReturnSuccess {
            hasAssertion = true
        }
    }

    /// Allow system sleep again.
    func allowSleep() {
        guard hasAssertion else { return }

        let result = IOPMAssertionRelease(assertionID)
        if result == kIOReturnSuccess {
            hasAssertion = false
        }
    }
}

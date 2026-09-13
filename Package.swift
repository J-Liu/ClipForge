// swift-tools-version:5.7

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import PackageDescription

let package = Package(
    name: "ClipForge",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ClipForge",
            path: "Sources/ClipForge"
        )
    ]
)

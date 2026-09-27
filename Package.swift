// swift-tools-version:5.7

// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import PackageDescription

let package = Package(
    name: "ClipForge",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "ClipForge",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/ClipForge"
        )
    ]
)

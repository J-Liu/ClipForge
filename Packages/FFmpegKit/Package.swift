// swift-tools-version: 5.9
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026 Jia Liu

import PackageDescription

let package = Package(
    name: "FFmpegKit",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "FFmpegKit",
            targets: ["FFmpegKit"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "ffmpegkit",
            path: "ffmpegkit.xcframework"
        ),
        .binaryTarget(
            name: "libavformat",
            path: "libavformat.xcframework"
        ),
        .binaryTarget(
            name: "libavcodec",
            path: "libavcodec.xcframework"
        ),
        .binaryTarget(
            name: "libavutil",
            path: "libavutil.xcframework"
        ),
        .binaryTarget(
            name: "libavfilter",
            path: "libavfilter.xcframework"
        ),
        .binaryTarget(
            name: "libswscale",
            path: "libswscale.xcframework"
        ),
        .binaryTarget(
            name: "libswresample",
            path: "libswresample.xcframework"
        ),
        .target(
            name: "FFmpegKit",
            dependencies: [
                "ffmpegkit",
                "libavformat",
                "libavcodec",
                "libavutil",
                "libavfilter",
                "libswscale",
                "libswresample"
            ],
            path: "Sources/FFmpegKit"
        )
    ]
)

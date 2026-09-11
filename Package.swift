// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "ClipForge",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "ClipForge",
            path: "Sources/ClipForge"
        )
    ]
)


// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "lgka-extractor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "LGKAExtractor", path: "Sources/LGKAExtractor")
    ]
)

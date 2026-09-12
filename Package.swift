// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "LGKACore",
    platforms: [.macOS(.v14), .iOS(.v26)],
    products: [
        .library(name: "LGKACore", targets: ["LGKACore"]),
    ],
    targets: [
        .target(name: "LGKACore"),
        .testTarget(
            name: "LGKACoreTests",
            dependencies: ["LGKACore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

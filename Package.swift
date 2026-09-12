// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "lgka-extractor",
    platforms: [.macOS(.v14), .iOS(.v26)],
    products: [
        .library(name: "LGKACore", targets: ["LGKACore"]),
        .executable(name: "lgka-extractor", targets: ["lgka-extractor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.13.9"),
    ],
    targets: [
        .target(name: "LGKACore", dependencies: ["SwiftSoup"]),
        .executableTarget(name: "lgka-extractor", dependencies: ["LGKACore"]),
        .testTarget(name: "LGKACoreTests", dependencies: ["LGKACore"]),
    ],
    swiftLanguageModes: [.v6]
)

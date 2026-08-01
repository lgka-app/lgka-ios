// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "lgka-extractor",
    platforms: [.macOS(.v13), .iOS("26.0")],
    products: [
        .library(name: "LGKACore", targets: ["LGKACore"]),
        .executable(name: "lgka-extractor", targets: ["lgka-extractor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0")
    ],
    targets: [
        .target(name: "LGKACore", dependencies: ["SwiftSoup"]),
        .executableTarget(name: "lgka-extractor", dependencies: ["LGKACore"]),
    ]
)

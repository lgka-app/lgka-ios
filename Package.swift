// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "LGKACore",
    platforms: [.macOS(.v15), .iOS(.v26)],
    products: [
        .library(name: "LGKACore", targets: ["LGKACore"]),
        // custom J11/J12 timetable: PDF text, on-device text recognition, PDF rendering
        .library(name: "LGKAPlanKit", targets: ["LGKAPlanKit"]),
        .executable(name: "lgka-plan", targets: ["lgka-plan"]),
    ],
    targets: [
        .target(name: "LGKACore"),
        .target(name: "LGKAPlanKit", dependencies: ["LGKACore"]),
        .executableTarget(name: "lgka-plan", dependencies: ["LGKACore", "LGKAPlanKit"]),
        .testTarget(
            name: "LGKACoreTests",
            dependencies: ["LGKACore", "LGKAPlanKit"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

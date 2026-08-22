// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jugnu",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "JugnuCore", targets: ["JugnuCore"]),
        .library(name: "JugnuUI", targets: ["JugnuUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(name: "JugnuCore", dependencies: ["Yams"]),
        .target(name: "JugnuUI", dependencies: ["JugnuCore"]),
        .testTarget(
            name: "JugnuCoreTests",
            dependencies: ["JugnuCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

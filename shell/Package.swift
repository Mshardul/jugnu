// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jugnu",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "JugnuCore", targets: ["JugnuCore"]),
        .library(name: "JugnuUI", targets: ["JugnuUI"]),
        .executable(name: "Jugnu", targets: ["Jugnu"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0"),
    ],
    targets: [
        .target(name: "JugnuCore", dependencies: ["Yams"]),
        .target(name: "JugnuUI", dependencies: ["JugnuCore"]),
        .executableTarget(
            name: "Jugnu",
            dependencies: [
                "JugnuCore",
                "JugnuUI",
                .product(name: "HotKey", package: "HotKey"),
            ],
            path: "App",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "JugnuCoreTests",
            dependencies: ["JugnuCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

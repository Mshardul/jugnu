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
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .target(
            name: "JugnuCore",
            dependencies: [
                "Yams",
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]
        ),
        .target(name: "JugnuUI", dependencies: ["JugnuCore"]),
        .executableTarget(
            name: "Jugnu",
            dependencies: [
                "JugnuCore",
                "JugnuUI",
                .product(name: "HotKey", package: "HotKey"),
            ],
            path: "App",
            exclude: ["Info.plist", "Assets.xcassets"]
        ),
        .testTarget(
            name: "JugnuCoreTests",
            dependencies: [
                "JugnuCore",
                .product(name: "Yams", package: "Yams"),
            ],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "JugnuUITests",
            dependencies: ["JugnuUI"]
        ),
        .testTarget(
            name: "JugnuAppTests",
            dependencies: ["Jugnu", "JugnuCore"]
        ),
    ]
)

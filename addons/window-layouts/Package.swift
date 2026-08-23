// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "window-layouts",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "window-layouts", targets: ["window-layouts"]),
        .library(name: "WindowLayoutCore", targets: ["WindowLayoutCore"]),
    ],
    targets: [
        .target(name: "WindowLayoutCore"),
        .executableTarget(
            name: "window-layouts",
            dependencies: ["WindowLayoutCore"]
        ),
        .testTarget(
            name: "WindowLayoutCoreTests",
            dependencies: ["WindowLayoutCore"]
        ),
    ]
)

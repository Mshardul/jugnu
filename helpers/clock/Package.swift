// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clock",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ClockCore", targets: ["ClockCore"]),
        .executable(name: "clock", targets: ["ClockCLI"]),
    ],
    targets: [
        .target(name: "ClockCore"),
        .executableTarget(name: "ClockCLI", dependencies: ["ClockCore"]),
        .testTarget(name: "ClockCoreTests", dependencies: ["ClockCore"]),
    ]
)

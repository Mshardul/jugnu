// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pdf-tools",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "pdf-tools", targets: ["pdf-tools"]),
        .library(name: "PDFToolsCore", targets: ["PDFToolsCore"]),
    ],
    targets: [
        .target(name: "PDFToolsCore"),
        .executableTarget(
            name: "pdf-tools",
            dependencies: ["PDFToolsCore"]
        ),
        .testTarget(
            name: "PDFToolsCoreTests",
            dependencies: ["PDFToolsCore"]
        ),
    ]
)

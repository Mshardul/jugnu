// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JugnuTestsExtended",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .testTarget(
            name: "JugnuCoreLiveTests",
            dependencies: [
                // Path package identity is the directory name (`shell/`), not Package.name.
                .product(name: "JugnuCore", package: "shell")
            ]
        )
    ]
)

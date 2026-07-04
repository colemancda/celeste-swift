// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Celeste",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CelesteCore", targets: ["CelesteCore"])
    ],
    targets: [
        .target(name: "CelesteCore"),
        .testTarget(name: "CelesteCoreTests", dependencies: ["CelesteCore"]),
    ]
)

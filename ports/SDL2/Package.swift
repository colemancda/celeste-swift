// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CelesteSDL2Port",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/PureSwift/SDL", .upToNextMajor(from: "3.1.0")),
    ],
    targets: [
        .executableTarget(
            name: "CelesteSDL2",
            dependencies: [
                .product(name: "CelesteCore", package: "celeste-swift"),
                .product(name: "SDL2Swift", package: "SDL"),
                .product(name: "SDL2Mixer", package: "SDL"),
            ],
            resources: [
                .copy("Resources/data")
            ]
        ),
    ]
)

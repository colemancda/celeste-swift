// swift-tools-version: 6.0
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "CelesteMobile",
    platforms: [.iOS("17.0")],
    products: [
        .iOSApplication(
            name: "CelesteMobile",
            targets: ["CelesteMobile"],
            bundleIdentifier: "com.example.celeste",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [.phone, .pad],
            supportedInterfaceOrientations: [.landscapeLeft, .landscapeRight]
        )
    ],
    targets: [
        .target(name: "CelesteCore"),
        .executableTarget(
            name: "CelesteMobile",
            dependencies: ["CelesteCore"],
            resources: [.copy("Audio")]
        )
    ]
)

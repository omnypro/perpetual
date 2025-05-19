// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Perpetual",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Perpetual", targets: ["Perpetual"])
    ],
    dependencies: [
        .package(url: "https://github.com/AudioKit/AudioKit.git", .upToNextMajor(from: "5.6.5")),
        .package(url: "https://github.com/AudioKit/AudioKitEX.git", .upToNextMajor(from: "5.6.2")),
    ],
    targets: [
        .executableTarget(
            name: "Perpetual",
            dependencies: [
                .product(name: "AudioKit", package: "AudioKit"),
                .product(name: "AudioKitEX", package: "AudioKitEX")
            ],
            path: "Sources/Perpetual",
            resources: []
        ),
        .testTarget(
            name: "PerpetualTests",
            dependencies: ["Perpetual"],
            path: "Tests"
        ),
    ]
)

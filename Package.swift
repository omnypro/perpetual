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
    ],
    targets: [
        .executableTarget(
            name: "Perpetual",
            dependencies: [
                .product(name: "AudioKit", package: "AudioKit"),
            ],
            path: "Sources/Perpetual",
            resources: [
                .process("Resources"),
                .process("Info.plist")
            ]
        ),
        .testTarget(
            name: "PerpetualTests",
            dependencies: ["Perpetual"],
            path: "Tests"
        ),
    ]
)

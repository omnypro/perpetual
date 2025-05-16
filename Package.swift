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
  dependencies: [],
  targets: [
    .executableTarget(
      name: "Perpetual",
      dependencies: [],
      path: "Sources/Perpetual",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "PerpetualTests",
      dependencies: ["Perpetual"],
      path: "Tests"
    )
  ]
)

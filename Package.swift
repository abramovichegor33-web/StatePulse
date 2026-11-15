// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StatePulse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StatePulse", targets: ["StatePulse"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "StatePulse",
            dependencies: [],
            path: "Sources/StatePulse"
        )
    ]
)

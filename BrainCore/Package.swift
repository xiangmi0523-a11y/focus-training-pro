// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BrainCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "BrainCore", targets: ["BrainCore"])
    ],
    targets: [
        .target(name: "BrainCore"),
        .testTarget(name: "BrainCoreTests", dependencies: ["BrainCore"])
    ]
)

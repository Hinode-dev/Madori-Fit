// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MadoriCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MadoriCore", targets: ["MadoriCore"])
    ],
    targets: [
        .target(name: "MadoriCore"),
        .testTarget(name: "MadoriCoreTests", dependencies: ["MadoriCore"])
    ]
)

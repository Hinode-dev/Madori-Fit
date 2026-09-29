// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MadoriCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MadoriCore", targets: ["MadoriCore"]),
        .library(name: "MadoriUI", targets: ["MadoriUI"]),
        .library(name: "MadoriApp", targets: ["MadoriApp"])
    ],
    targets: [
        .target(name: "MadoriCore"),
        .target(name: "MadoriUI", dependencies: ["MadoriCore"]),
        .target(name: "MadoriApp", dependencies: ["MadoriCore", "MadoriUI"]),
        .testTarget(name: "MadoriCoreTests", dependencies: ["MadoriCore"]),
        .testTarget(name: "MadoriUITests", dependencies: ["MadoriUI", "MadoriCore"]),
        .testTarget(name: "MadoriAppTests", dependencies: ["MadoriApp", "MadoriCore"])
    ]
)

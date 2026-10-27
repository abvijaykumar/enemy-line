// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LastLineCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "LastLineCore", targets: ["LastLineCore"])],
    targets: [
        .target(name: "LastLineCore"),
        .testTarget(name: "LastLineCoreTests", dependencies: ["LastLineCore"])
    ]
)

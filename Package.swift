// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Relaytools",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Relaytools", targets: ["Relaytools"])],
    targets: [
        .executableTarget(name: "Relaytools", path: "Sources/Relaytools"),
        .testTarget(name: "RelaytoolsTests", dependencies: ["Relaytools"])
    ]
)

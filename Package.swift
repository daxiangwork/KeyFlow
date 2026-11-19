// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyFlow",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "KeyFlow", targets: ["KeyFlowApp"]),
        .executable(name: "keyflow-probe", targets: ["KeyFlowProbe"])
    ],
    targets: [
        .executableTarget(name: "KeyFlowApp"),
        .executableTarget(name: "KeyFlowProbe")
    ]
)

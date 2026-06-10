// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DNSPilotMac",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "DNSPilotMac", targets: ["DNSPilotMac"]),
        .library(name: "DNSPilotMacCore", targets: ["DNSPilotMacCore"]),
    ],
    targets: [
        .target(name: "DNSPilotMacCore"),
        .executableTarget(
            name: "DNSPilotMac",
            dependencies: ["DNSPilotMacCore"]
        ),
        .testTarget(
            name: "DNSPilotMacCoreTests",
            dependencies: ["DNSPilotMacCore"]
        ),
    ]
)

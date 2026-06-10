public protocol DNSPilotCoreBridge {
    func loadCapabilities() throws -> [CapabilityRow]
}

public struct CapabilityMatrixViewModel {
    public let rows: [CapabilityRow]
    public let loadErrorMessage: String?

    public init(bridge: DNSPilotCoreBridge = PreviewDNSPilotCoreBridge()) {
        do {
            rows = try bridge.loadCapabilities()
            loadErrorMessage = nil
        } catch {
            rows = []
            loadErrorMessage = error.localizedDescription
        }
    }
}

public struct PreviewDNSPilotCoreBridge: DNSPilotCoreBridge {
    public init() {}

    public func loadCapabilities() -> [CapabilityRow] {
        [
            CapabilityRow(
                platformID: "macos-store",
                platformName: "macOS Store",
                canBenchmark: true,
                applyDisposition: .allow,
                flush: .guidedUserAction,
                storeSafe: true,
                notes: ["NetworkExtension DNS Settings require explicit user enablement."]
            ),
            CapabilityRow(
                platformID: "ios",
                platformName: "iOS / iPadOS",
                canBenchmark: true,
                applyDisposition: .allow,
                flush: .unsupported,
                storeSafe: true,
                notes: ["System DNS cache flush is unavailable to normal apps."]
            ),
            CapabilityRow(
                platformID: "android-play",
                platformName: "Android Play",
                canBenchmark: true,
                applyDisposition: .guideOnly,
                flush: .guidedUserAction,
                storeSafe: true,
                notes: ["Private DNS changes stay guided unless VPN policy is approved."]
            ),
            CapabilityRow(
                platformID: "windows-store",
                platformName: "Windows Store",
                canBenchmark: true,
                applyDisposition: .guideOnly,
                flush: .guidedUserAction,
                storeSafe: true,
                notes: ["Store builds must not depend on elevation."]
            ),
            CapabilityRow(
                platformID: "linux-native-power",
                platformName: "Linux Native Power",
                canBenchmark: true,
                applyDisposition: .allow,
                flush: .linuxSystemResolverPolkit,
                storeSafe: false,
                notes: ["Native packages can use NetworkManager/systemd-resolved through polkit."]
            ),
        ]
    }
}

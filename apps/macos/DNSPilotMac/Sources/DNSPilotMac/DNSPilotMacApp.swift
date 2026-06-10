import SwiftUI
import DNSPilotMacCore

@main
struct DNSPilotMacApp: App {
    var body: some Scene {
        WindowGroup {
            CapabilityMatrixView()
                .frame(minWidth: 900, minHeight: 620)
        }
    }
}

private struct CapabilityMatrixView: View {
    private let viewModel = CapabilityMatrixViewModel()

    var body: some View {
        NavigationSplitView {
            List(viewModel.rows) { row in
                Label(row.platformName, systemImage: row.storeSafe ? "checkmark.seal" : "bolt.badge.clock")
            }
            .navigationTitle("DNS Pilot")
        } detail: {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                Text("Capability Matrix")
                    .font(.title2.weight(.semibold))

                if let loadErrorMessage = viewModel.loadErrorMessage {
                    Label(loadErrorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: DNSPilotDesign.Spacing.row) {
                        GridRow {
                            Text("Platform").font(.headline)
                            Text("Benchmark").font(.headline)
                            Text("Apply").font(.headline)
                            Text("Flush").font(.headline)
                        }

                        ForEach(viewModel.rows) { row in
                            GridRow {
                                Text(row.platformName)
                                Image(systemName: row.canBenchmark ? "speedometer" : "minus.circle")
                                    .help(row.canBenchmark ? "Can benchmark" : "Cannot benchmark")
                                Text(label(for: row.applyDisposition))
                                Text(label(for: row.flush))
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .background(DNSPilotDesign.Palette.background)
        }
    }

    private func label(for disposition: DNSPilotApplyDisposition) -> String {
        switch disposition {
        case .allow: "Allowed"
        case .guideOnly: "Guide"
        case .protectCurrentDNS: "Protect"
        case .unsupported: "Unsupported"
        }
    }

    private func label(for flush: DNSPilotFlushCapability) -> String {
        switch flush {
        case .guidedUserAction: "Guided"
        case .desktopAdminService: "Admin"
        case .linuxSystemResolverPolkit: "Polkit"
        case .unsupported: "Unsupported"
        }
    }
}

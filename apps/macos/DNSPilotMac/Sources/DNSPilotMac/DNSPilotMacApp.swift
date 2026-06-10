import SwiftUI
import DNSPilotMacCore

@main
struct DNSPilotMacApp: App {
    var body: some Scene {
        WindowGroup {
            DNSPilotShellView()
                .frame(minWidth: 900, minHeight: 620)
        }
    }
}

private enum SidebarSelection: Hashable {
    case capabilities
    case catalog
}

private struct DNSPilotShellView: View {
    @State private var selection: SidebarSelection? = .capabilities

    private let capabilityViewModel = CapabilityMatrixViewModel()
    private let catalogViewModel = CatalogViewModel()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Overview") {
                    Label("Capabilities", systemImage: "checkmark.seal")
                        .tag(SidebarSelection.capabilities)
                    Label("Catalog", systemImage: "server.rack")
                        .tag(SidebarSelection.catalog)
                }

                Section("Platforms") {
                    ForEach(capabilityViewModel.rows) { row in
                        Label(row.platformName, systemImage: row.storeSafe ? "checkmark.seal" : "bolt.badge.clock")
                    }
                }
            }
            .navigationTitle("DNS Pilot")
        } detail: {
            switch selection ?? .capabilities {
            case .capabilities:
                CapabilityMatrixDetailView(viewModel: capabilityViewModel)
            case .catalog:
                CatalogOverviewDetailView(viewModel: catalogViewModel)
            }
        }
    }
}

private struct CapabilityMatrixDetailView: View {
    let viewModel: CapabilityMatrixViewModel

    var body: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DNSPilotDesign.Palette.background)
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

private struct CatalogOverviewDetailView: View {
    let viewModel: CatalogViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                Text("Catalog")
                    .font(.title2.weight(.semibold))

                if let loadErrorMessage = viewModel.loadErrorMessage {
                    Label(loadErrorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                        CatalogMetricView(
                            title: "Providers",
                            value: "\(viewModel.profileCount)",
                            systemImage: "server.rack"
                        )
                        CatalogMetricView(
                            title: "Suites",
                            value: "\(viewModel.testSuiteCount)",
                            systemImage: "list.bullet.rectangle"
                        )
                        CatalogMetricView(
                            title: "Filtered",
                            value: "\(viewModel.filteredProfileCount)",
                            systemImage: "shield"
                        )
                    }

                    CatalogListSection(title: "Providers") {
                        ForEach(viewModel.profileSummaries) { summary in
                            CatalogProfileRow(summary: summary)
                        }
                    }

                    CatalogListSection(title: "Test Suites") {
                        ForEach(viewModel.testSuiteSummaries) { summary in
                            CatalogSuiteRow(summary: summary)
                        }
                    }
                }
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
    }
}

private struct CatalogMetricView: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
            Image(systemName: systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DNSPilotDesign.Spacing.row)
        .frame(minWidth: 130, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.card)
                .stroke(.separator.opacity(0.5))
        }
    }
}

private struct CatalogListSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
            Text(title)
                .font(.headline)
            content
        }
    }
}

private struct CatalogProfileRow: View {
    let summary: CatalogProfileSummary

    var body: some View {
        HStack(alignment: .top, spacing: DNSPilotDesign.Spacing.controlGap) {
            Image(systemName: "network")
                .frame(width: 22)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.name)
                    .font(.body.weight(.semibold))
                Text(summary.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: DNSPilotDesign.Spacing.panel)
            VStack(alignment: .trailing, spacing: 4) {
                Text(summary.filteringLabel)
                    .font(.caption.weight(.semibold))
                Text(summary.serverSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DNSPilotDesign.Spacing.row)
        .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.card)
                .stroke(.separator.opacity(0.5))
        }
    }
}

private struct CatalogSuiteRow: View {
    let summary: CatalogTestSuiteSummary

    var body: some View {
        HStack(alignment: .top, spacing: DNSPilotDesign.Spacing.controlGap) {
            Image(systemName: "list.bullet.rectangle")
                .frame(width: 22)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.name)
                    .font(.body.weight(.semibold))
                Text(summary.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: DNSPilotDesign.Spacing.panel)
            Text(summary.domainCountLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DNSPilotDesign.Spacing.row)
        .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.card)
                .stroke(.separator.opacity(0.5))
        }
    }
}

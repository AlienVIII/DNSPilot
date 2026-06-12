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
    case benchmark
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
                    Label("Benchmark", systemImage: "speedometer")
                        .tag(SidebarSelection.benchmark)
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
            case .benchmark:
                BenchmarkDetailHostView(catalogViewModel: catalogViewModel)
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

private struct BenchmarkDetailHostView: View {
    let catalogViewModel: CatalogViewModel

    var body: some View {
        if let loadErrorMessage = catalogViewModel.loadErrorMessage {
            BenchmarkUnavailableView(message: loadErrorMessage)
        } else if let catalog = catalogViewModel.catalog {
            BenchmarkDetailView(
                catalog: catalog,
                executableAvailability: BenchmarkExecutableResolver().resolve()
            )
        } else {
            BenchmarkUnavailableView(message: "Catalog unavailable.")
        }
    }
}

private struct BenchmarkUnavailableView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
            Text("Benchmark")
                .font(.title2.weight(.semibold))
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(DNSPilotDesign.Spacing.panel)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DNSPilotDesign.Palette.background)
    }
}

private struct BenchmarkDetailView: View {
    let catalog: CatalogSnapshot
    let executableAvailability: BenchmarkExecutableAvailability

    @State private var selectedProfileIDs: [String]
    @State private var selectedSuiteID: String?
    @State private var customDomainsText: String
    @State private var attempts: Int
    @State private var mode: BenchmarkPlanMode
    @State private var runStateMachine = BenchmarkRunStateMachine()
    @State private var outcome: BenchmarkExecutionOutcome?

    private var setupViewModel: BenchmarkSetupViewModel {
        BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: executableAvailability,
            selectedProfileIDs: selectedProfileIDs,
            selectedSuiteID: selectedSuiteID,
            customDomainsText: customDomainsText,
            attempts: attempts,
            mode: mode
        )
    }

    private var runControls: BenchmarkRunControlsViewModel {
        BenchmarkRunControlsViewModel(
            state: runStateMachine.state,
            setupCanRun: setupViewModel.canRun
        )
    }

    init(catalog: CatalogSnapshot, executableAvailability: BenchmarkExecutableAvailability) {
        self.catalog = catalog
        self.executableAvailability = executableAvailability
        let defaults = BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: executableAvailability
        )
        _selectedProfileIDs = State(initialValue: defaults.selectedProfileIDs)
        _selectedSuiteID = State(initialValue: defaults.selectedSuiteID)
        _customDomainsText = State(initialValue: defaults.customDomainsText)
        _attempts = State(initialValue: defaults.attempts)
        _mode = State(initialValue: defaults.mode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                HStack {
                    Text("Benchmark")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    if runControls.showsCancel {
                        Button(action: cancelBenchmark) {
                            Label("Cancel", systemImage: "xmark")
                        }
                        .disabled(!runControls.isCancelEnabled)
                    }
                    Button(action: runBenchmark) {
                        if case .running = runStateMachine.state {
                            ProgressView()
                                .controlSize(.small)
                        } else if case .cancelling = runStateMachine.state {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(runControls.primaryLabel, systemImage: "play.fill")
                        }
                    }
                    .disabled(!runControls.isPrimaryEnabled)
                    .help(setupViewModel.canRun ? "Run benchmark" : "Resolve readiness issues")
                }

                if !setupViewModel.readinessIssues.isEmpty {
                    BenchmarkIssueList(issues: setupViewModel.readinessIssues)
                }

                BenchmarkSection(title: "Mode") {
                    Picker("Mode", selection: $mode) {
                        Text("DNS only").tag(BenchmarkPlanMode.dnsOnlyCompare)
                        Text("DNS + TCP").tag(BenchmarkPlanMode.connectionPathCompare)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 280, alignment: .leading)
                }

                BenchmarkSection(title: "Profiles") {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                        ForEach(setupViewModel.profileOptions) { option in
                            Toggle(isOn: profileBinding(for: option)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.name)
                                            .font(.body.weight(.semibold))
                                        Text(option.detailLabel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .disabled(!option.isRunnable)
                        }
                    }
                }

                BenchmarkSection(title: "Targets") {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                        Picker("Suite", selection: $selectedSuiteID) {
                            Text("Custom only").tag(Optional<String>.none)
                            ForEach(setupViewModel.suiteOptions) { option in
                                Text("\(option.name) (\(option.domainCountLabel))")
                                    .tag(Optional(option.id))
                            }
                        }
                        .frame(maxWidth: 360, alignment: .leading)

                        TextEditor(text: $customDomainsText)
                            .font(.body.monospaced())
                            .frame(minHeight: 72)
                            .scrollContentBackground(.hidden)
                            .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control))
                            .overlay {
                                RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control)
                                    .stroke(.separator.opacity(0.5))
                            }
                    }
                }

                BenchmarkSection(title: "Attempts") {
                    Stepper(value: $attempts, in: 1...5) {
                        Text("\(attempts)")
                            .font(.body.monospacedDigit())
                    }
                    .frame(maxWidth: 160, alignment: .leading)
                }

                if let outcome {
                    switch outcome {
                    case .completed(let resultViewModel):
                        BenchmarkResultPanel(viewModel: resultViewModel)
                    case .failed(let message):
                        BenchmarkIssueList(issues: [message])
                    }
                }
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
    }

    private func profileBinding(for option: BenchmarkProfileOption) -> Binding<Bool> {
        Binding(
            get: { selectedProfileIDs.contains(option.id) },
            set: { isSelected in
                if isSelected {
                    if !selectedProfileIDs.contains(option.id) {
                        selectedProfileIDs.append(option.id)
                    }
                } else {
                    selectedProfileIDs.removeAll { $0 == option.id }
                }
            }
        )
    }

    private func runBenchmark() {
        let setup = setupViewModel
        guard setup.canRun else {
            outcome = .failed(setup.readinessIssues.joined(separator: "\n"))
            return
        }
        guard case .ready(let executableURL) = executableAvailability else {
            outcome = .failed("DNS Pilot CLI executable is unavailable.")
            return
        }

        let runID = runStateMachine.start()
        outcome = nil
        let plan = setup.plan
        let catalog = catalog

        DispatchQueue.global(qos: .userInitiated).async {
            let coordinator = BenchmarkExecutionCoordinator(
                runner: BenchmarkRunner(executableURL: executableURL),
                catalog: catalog
            )
            let nextOutcome = coordinator.execute(plan: plan)

            DispatchQueue.main.async {
                if case .cancelling = runStateMachine.state {
                    runStateMachine.finishCancelled(runID: runID)
                    outcome = .failed("Benchmark cancelled.")
                    return
                }

                switch nextOutcome {
                case .completed:
                    runStateMachine.finishCompleted(runID: runID)
                case .failed(let message):
                    runStateMachine.finishFailed(runID: runID, message: message)
                }

                switch runStateMachine.state {
                case .completed, .failed:
                    outcome = nextOutcome
                default:
                    break
                }
            }
        }
    }

    private func cancelBenchmark() {
        if case .running(let runID) = runStateMachine.state {
            runStateMachine.requestCancel(runID: runID)
        }
    }
}

private struct BenchmarkSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(DNSPilotDesign.Spacing.row)
        .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.card)
                .stroke(.separator.opacity(0.5))
        }
    }
}

private struct BenchmarkIssueList: View {
    let issues: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            ForEach(issues, id: \.self) { issue in
                Label(issue, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(DNSPilotDesign.Palette.warning)
            }
        }
        .padding(DNSPilotDesign.Spacing.row)
        .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.card)
                .stroke(DNSPilotDesign.Palette.warning.opacity(0.35))
        }
    }
}

private struct BenchmarkResultPanel: View {
    let viewModel: BenchmarkResultViewModel

    var body: some View {
        BenchmarkSection(title: "Result") {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                HStack(spacing: DNSPilotDesign.Spacing.panel) {
                    Label(viewModel.healthLabel, systemImage: "waveform.path.ecg")
                    Label(viewModel.scopeLabel, systemImage: "point.3.connected.trianglepath.dotted")
                    Label(viewModel.confidenceLabel, systemImage: "gauge.with.dots.needle.67percent")
                }
                .foregroundStyle(.secondary)

                Text(viewModel.recommendationLabel)
                    .font(.title3.weight(.semibold))

                Grid(alignment: .leading, horizontalSpacing: DNSPilotDesign.Spacing.panel, verticalSpacing: DNSPilotDesign.Spacing.row) {
                    GridRow {
                        Text("Profile").font(.headline)
                        Text("Resolver").font(.headline)
                        Text("Median DNS").font(.headline)
                        Text("P95 DNS").font(.headline)
                        if viewModel.showsConnectionMetrics {
                            Text("Median TCP").font(.headline)
                        }
                        Text("Failure").font(.headline)
                    }

                    ForEach(viewModel.rows) { row in
                        GridRow {
                            Text(row.name)
                            Text(row.resolver).font(.body.monospaced())
                            Text(row.medianDNSLatencyLabel)
                            Text(row.p95DNSLatencyLabel)
                            if viewModel.showsConnectionMetrics {
                                Text(row.medianConnectLatencyLabel)
                            }
                            Text(row.failureRateLabel)
                        }
                    }
                }

                if !viewModel.notes.isEmpty {
                    ForEach(viewModel.notes, id: \.self) { note in
                        Label(note, systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                Text(viewModel.warning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

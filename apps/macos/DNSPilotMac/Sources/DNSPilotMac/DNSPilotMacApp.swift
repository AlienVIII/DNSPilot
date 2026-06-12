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
    case customDNS
    case history
    case catalog
}

private struct DNSPilotShellView: View {
    @State private var selection: SidebarSelection? = .capabilities
    @State private var catalogViewModel = CatalogViewModel()
    @State private var hasRequestedStorageCatalogRefresh = false

    private let capabilityViewModel = CapabilityMatrixViewModel()

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Overview") {
                    Label("Capabilities", systemImage: "checkmark.seal")
                        .tag(SidebarSelection.capabilities)
                    Label("Benchmark", systemImage: "speedometer")
                        .tag(SidebarSelection.benchmark)
                    Label("Custom DNS", systemImage: "plus.circle")
                        .tag(SidebarSelection.customDNS)
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .tag(SidebarSelection.history)
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
            case .customDNS:
                CustomDNSDetailHostView(
                    executableAvailability: BenchmarkExecutableResolver().resolve(),
                    onProfileSaved: refreshCatalogFromStorage
                )
            case .history:
                HistoryDetailHostView(catalogViewModel: catalogViewModel)
            case .catalog:
                CatalogOverviewDetailView(viewModel: catalogViewModel)
            }
        }
        .onAppear {
            guard !hasRequestedStorageCatalogRefresh else {
                return
            }
            hasRequestedStorageCatalogRefresh = true
            refreshCatalogFromStorage()
        }
    }

    private func refreshCatalogFromStorage() {
        guard let factory = makePreparedHistoryPersistenceFactory() else {
            catalogViewModel = CatalogViewModel()
            return
        }

        switch BenchmarkExecutableResolver().resolve() {
        case .ready(let executableURL):
            let databaseURL = factory.databaseURL
            DispatchQueue.global(qos: .userInitiated).async {
                let viewModel = CatalogViewModel(
                    bridge: StorageBackedCatalogBridge(
                        baseBridge: PreviewCatalogBridge(),
                        storageRunner: CatalogStorageRunner(executableURL: executableURL),
                        databaseURL: databaseURL
                    )
                )

                DispatchQueue.main.async {
                    catalogViewModel = viewModel
                }
            }
        case .unavailable:
            catalogViewModel = CatalogViewModel()
        }
    }
}

private struct CustomDNSDetailHostView: View {
    let executableAvailability: BenchmarkExecutableAvailability
    let onProfileSaved: () -> Void

    var body: some View {
        switch executableAvailability {
        case .ready(let executableURL):
            CustomDNSProfileDetailView(
                executableURL: executableURL,
                onProfileSaved: onProfileSaved
            )
        case .unavailable(let message):
            BenchmarkUnavailableView(title: "Custom DNS", message: message)
        }
    }
}

private struct CustomDNSProfileDetailView: View {
    let executableURL: URL
    let onProfileSaved: () -> Void

    @State private var name = ""
    @State private var ipv4ServersText = ""
    @State private var ipv6ServersText = ""
    @State private var saveState: CustomDNSProfileEditorState = .idle

    private var editorViewModel: CustomDNSProfileEditorViewModel {
        CustomDNSProfileEditorViewModel(
            name: name,
            ipv4ServersText: ipv4ServersText,
            ipv6ServersText: ipv6ServersText,
            state: saveState
        )
    }

    private var isSaving: Bool {
        if case .saving = saveState {
            return true
        }
        return false
    }

    private var shouldShowIssues: Bool {
        !name.isEmpty
            || !ipv4ServersText.isEmpty
            || !ipv6ServersText.isEmpty
            || saveState != .idle
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                HStack {
                    Text("Custom DNS")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button(action: saveProfile) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(editorViewModel.saveButtonLabel, systemImage: "tray.and.arrow.down")
                        }
                    }
                    .disabled(!editorViewModel.canSave)
                    .help(editorViewModel.canSave ? "Save profile" : "Resolve validation issues")
                }

                if shouldShowIssues, !editorViewModel.issues.isEmpty {
                    BenchmarkIssueList(issues: editorViewModel.issues)
                }

                if let statusMessage = editorViewModel.statusMessage {
                    CustomDNSSaveStatusView(state: saveState, message: statusMessage)
                }

                BenchmarkSection(title: "Profile") {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 360, alignment: .leading)
                            .disabled(isSaving)
                        Label(editorViewModel.profileIDLabel, systemImage: "tag")
                            .foregroundStyle(.secondary)
                    }
                }

                BenchmarkSection(title: "Servers") {
                    HStack(alignment: .top, spacing: DNSPilotDesign.Spacing.panel) {
                        CustomDNSServerEditor(
                            title: "IPv4",
                            text: $ipv4ServersText,
                            isDisabled: isSaving
                        )
                        CustomDNSServerEditor(
                            title: "IPv6",
                            text: $ipv6ServersText,
                            isDisabled: isSaving
                        )
                    }
                }
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
        .onChange(of: name) { _, _ in resetTransientSaveState() }
        .onChange(of: ipv4ServersText) { _, _ in resetTransientSaveState() }
        .onChange(of: ipv6ServersText) { _, _ in resetTransientSaveState() }
    }

    private func saveProfile() {
        let editor = editorViewModel
        guard editor.canSave else {
            saveState = .failed(editor.issues.joined(separator: "\n"))
            return
        }
        guard let factory = makePreparedHistoryPersistenceFactory() else {
            saveState = .failed("Profile storage is unavailable.")
            return
        }

        saveState = .saving
        let form = editor.form
        let databaseURL = factory.databaseURL
        let executableURL = executableURL

        DispatchQueue.global(qos: .userInitiated).async {
            let coordinator = CustomDNSProfileSaveCoordinator(
                runner: CustomDNSProfileSaveRunner(executableURL: executableURL)
            )
            let outcome = coordinator.save(form: form, databaseURL: databaseURL)

            DispatchQueue.main.async {
                switch outcome {
                case .saved(let profileID, let name):
                    saveState = .saved(profileID: profileID, name: name)
                    onProfileSaved()
                case .failed(let message):
                    saveState = .failed(message)
                }
            }
        }
    }

    private func resetTransientSaveState() {
        switch saveState {
        case .saved, .failed:
            saveState = .idle
        case .idle, .saving:
            break
        }
    }
}

private struct CustomDNSServerEditor: View {
    let title: String
    @Binding var text: String
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
            Text(title)
                .font(.headline)
            TextEditor(text: $text)
                .font(.body.monospaced())
                .frame(minWidth: 260, minHeight: 110)
                .scrollContentBackground(.hidden)
                .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control)
                        .stroke(.separator.opacity(0.5))
                }
                .disabled(isDisabled)
        }
        .frame(maxWidth: 340, alignment: .leading)
    }
}

private struct CustomDNSSaveStatusView: View {
    let state: CustomDNSProfileEditorState
    let message: String

    var body: some View {
        Label(message, systemImage: systemImage)
            .foregroundStyle(foregroundStyle)
    }

    private var systemImage: String {
        switch state {
        case .saved:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        case .saving:
            "clock"
        case .idle:
            "info.circle"
        }
    }

    private var foregroundStyle: Color {
        switch state {
        case .failed:
            DNSPilotDesign.Palette.warning
        case .idle, .saving, .saved:
            .secondary
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
    let title: String
    let message: String

    init(title: String = "Benchmark", message: String) {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
            Text(title)
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

private struct HistoryDetailHostView: View {
    let catalogViewModel: CatalogViewModel

    var body: some View {
        if let loadErrorMessage = catalogViewModel.loadErrorMessage {
            HistoryUnavailableView(message: loadErrorMessage)
        } else if let catalog = catalogViewModel.catalog {
            switch BenchmarkExecutableResolver().resolve() {
            case .ready(let executableURL):
                HistoryDetailView(catalog: catalog, executableURL: executableURL)
            case .unavailable(let message):
                HistoryUnavailableView(message: message)
            }
        } else {
            HistoryUnavailableView(message: "Catalog unavailable.")
        }
    }
}

private struct HistoryUnavailableView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
            Text("History")
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

private struct HistoryDetailView: View {
    let catalog: CatalogSnapshot
    let executableURL: URL

    @State private var isLoading = false
    @State private var outcome: BenchmarkHistoryLoadOutcome?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                HStack {
                    Text("History")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button(action: loadHistory) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                switch outcome {
                case .loaded(let viewModel):
                    HistoryResultPanel(viewModel: viewModel)
                case .failed(let message):
                    BenchmarkIssueList(issues: [message])
                case nil:
                    Text("History has not been loaded.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
        .onAppear {
            if outcome == nil {
                loadHistory()
            }
        }
    }

    private func loadHistory() {
        guard !isLoading else {
            return
        }
        guard let factory = makePreparedHistoryPersistenceFactory() else {
            outcome = .failed("Benchmark history storage is unavailable.")
            return
        }

        isLoading = true
        let databaseURL = factory.databaseURL
        let catalog = catalog
        let executableURL = executableURL

        DispatchQueue.global(qos: .userInitiated).async {
            let coordinator = BenchmarkHistoryLoadCoordinator(
                runner: BenchmarkHistoryRunner(executableURL: executableURL),
                catalog: catalog
            )
            let nextOutcome = coordinator.load(databaseURL: databaseURL)

            DispatchQueue.main.async {
                outcome = nextOutcome
                isLoading = false
            }
        }
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
    @State private var currentCancellation: BenchmarkRunCancellation?
    @State private var currentBenchmarkStartedAt: Date?
    @State private var lastBenchmarkElapsedMS: Int?
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

    private var progressViewModel: BenchmarkProgressViewModel {
        BenchmarkProgressViewModel(
            mode: mode,
            state: runStateMachine.state,
            outcome: outcome,
            historySaved: completedResultSavedHistory
        )
    }

    private var completedResultSavedHistory: Bool {
        guard case .completed(let resultViewModel) = outcome else {
            return false
        }
        return resultViewModel.savedHistoryLabel != nil
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

                if progressViewModel.shouldDisplay {
                    BenchmarkProgressPanel(viewModel: progressViewModel)
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

                        DNSPilotMultilineTextInput(text: $customDomainsText)
                            .frame(minHeight: 88, alignment: .topLeading)
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
                    case .failed(let failure):
                        BenchmarkFailurePanel(
                            failure: failure,
                            mode: mode,
                            elapsedMS: lastBenchmarkElapsedMS
                        )
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
            let message = setup.readinessIssues.joined(separator: "\n")
            outcome = .failed(
                BenchmarkExecutionFailure(
                    message: message,
                    failedStep: .preparingBenchmark,
                    debugLog: message
                )
            )
            lastBenchmarkElapsedMS = 0
            return
        }
        guard case .ready(let executableURL) = executableAvailability else {
            let message = "DNS Pilot CLI executable is unavailable."
            outcome = .failed(
                BenchmarkExecutionFailure(
                    message: message,
                    failedStep: .preparingBenchmark,
                    debugLog: message
                )
            )
            lastBenchmarkElapsedMS = 0
            return
        }

        let runID = runStateMachine.start()
        let cancellation = BenchmarkRunCancellation()
        currentCancellation = cancellation
        outcome = nil
        lastBenchmarkElapsedMS = nil
        let startedAt = Date()
        currentBenchmarkStartedAt = startedAt
        let plan = setup.plan
        let persistence = makeHistoryPersistence(for: plan)
        let catalog = catalog

        DispatchQueue.global(qos: .userInitiated).async {
            let coordinator = BenchmarkExecutionCoordinator(
                runner: BenchmarkRunner(executableURL: executableURL),
                catalog: catalog
            )
            let nextOutcome = coordinator.execute(
                plan: plan,
                persistence: persistence,
                cancellation: cancellation
            )

            DispatchQueue.main.async {
                if case .cancelling = runStateMachine.state {
                    runStateMachine.finishCancelled(runID: runID)
                    if currentCancellation === cancellation {
                        currentCancellation = nil
                    }
                    currentBenchmarkStartedAt = nil
                    lastBenchmarkElapsedMS = Self.elapsedMilliseconds(since: startedAt)
                    outcome = .failed(
                        BenchmarkExecutionFailure(
                            message: "Benchmark cancelled.",
                            failedStep: .preparingBenchmark,
                            suggestion: "Run the benchmark again when ready.",
                            debugLog: "User cancelled benchmark."
                        )
                    )
                    return
                }

                currentBenchmarkStartedAt = nil
                lastBenchmarkElapsedMS = Self.elapsedMilliseconds(since: startedAt)
                switch nextOutcome {
                case .completed:
                    runStateMachine.finishCompleted(runID: runID)
                case .failed(let failure):
                    runStateMachine.finishFailed(runID: runID, message: failure.message)
                }

                switch runStateMachine.state {
                case .completed, .failed:
                    if currentCancellation === cancellation {
                        currentCancellation = nil
                    }
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
            currentCancellation?.cancel()
        }
    }

    private func makeHistoryPersistence(for plan: BenchmarkPlanViewModel) -> BenchmarkHistoryPersistence? {
        guard let factory = makePreparedHistoryPersistenceFactory() else {
            return nil
        }
        return factory.makePersistence(mode: plan.mode)
    }

    private static func elapsedMilliseconds(since startDate: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startDate) * 1000))
    }
}

private func makePreparedHistoryPersistenceFactory() -> BenchmarkHistoryPersistenceFactory? {
    guard let applicationSupportDirectory = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first else {
        return nil
    }

    let factory = BenchmarkHistoryPersistenceFactory(
        applicationSupportDirectory: applicationSupportDirectory
    )
    do {
        try FileManager.default.createDirectory(
            at: factory.directoryURL,
            withIntermediateDirectories: true
        )
    } catch {
        return nil
    }
    return factory
}

private extension BenchmarkProgressViewModel {
    var shouldDisplay: Bool {
        steps.contains { $0.status != .idle }
    }
}

private extension BenchmarkProgressStatus {
    var displayLabel: String {
        rawValue.capitalized
    }

    var systemImageName: String {
        switch self {
        case .idle:
            "circle"
        case .running:
            "arrow.triangle.2.circlepath"
        case .success:
            "checkmark.circle.fill"
        case .failed:
            "xmark.octagon.fill"
        }
    }

    var foregroundStyle: Color {
        switch self {
        case .idle:
            .secondary
        case .running:
            DNSPilotDesign.Palette.accent
        case .success:
            .green
        case .failed:
            .red
        }
    }
}

private extension BenchmarkPlanMode {
    var displayLabel: String {
        switch self {
        case .dnsOnlyCompare:
            "DNS only"
        case .connectionPathCompare:
            "DNS + TCP"
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

private struct BenchmarkProgressPanel: View {
    let viewModel: BenchmarkProgressViewModel

    var body: some View {
        BenchmarkSection(title: "Process") {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                ForEach(viewModel.steps) { step in
                    HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                        BenchmarkProgressStatusIcon(status: step.status)
                        Text(step.title)
                            .font(.body.weight(step.status == .running ? .semibold : .regular))
                        Spacer()
                        Text(step.status.displayLabel)
                            .font(.caption.monospaced())
                            .foregroundStyle(step.status.foregroundStyle)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct BenchmarkProgressStatusIcon: View {
    let status: BenchmarkProgressStatus

    var body: some View {
        Group {
            if status == .running {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: status.systemImageName)
                    .foregroundStyle(status.foregroundStyle)
            }
        }
        .frame(width: 18, height: 18)
    }
}

private struct BenchmarkFailurePanel: View {
    let failure: BenchmarkExecutionFailure
    let mode: BenchmarkPlanMode
    let elapsedMS: Int?

    var body: some View {
        BenchmarkSection(title: "Benchmark failed") {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                BenchmarkFailureRow(label: "Mode", value: mode.displayLabel)
                BenchmarkFailureRow(label: "Failed at", value: failure.failedStep.label)
                BenchmarkFailureRow(label: "Reason", value: failure.message)
                BenchmarkFailureRow(label: "Suggestion", value: failure.suggestion)
                if let elapsedMS {
                    BenchmarkFailureRow(label: "Elapsed", value: "\(elapsedMS) ms")
                }

                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                    Text("Debug log")
                        .font(.headline)
                    Text(failure.debugLog)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DNSPilotDesign.Spacing.row)
                        .background(DNSPilotDesign.Palette.panel, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control))
                }
            }
        }
    }
}

private struct BenchmarkFailureRow: View {
    let label: String
    let value: String

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: DNSPilotDesign.Spacing.row, verticalSpacing: DNSPilotDesign.Spacing.controlGap) {
            GridRow {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 88, alignment: .leading)
                Text(value)
                    .textSelection(.enabled)
            }
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

                if let savedHistoryLabel = viewModel.savedHistoryLabel {
                    Label(savedHistoryLabel, systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                }

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

private struct HistoryResultPanel: View {
    let viewModel: BenchmarkHistoryViewModel

    var body: some View {
        BenchmarkSection(title: "Saved Runs") {
            if viewModel.rows.isEmpty {
                Label("No saved runs yet.", systemImage: "tray")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                    ForEach(viewModel.rows) { row in
                        HistoryRowView(row: row)
                    }
                }
            }
        }
    }
}

private struct HistoryRowView: View {
    let row: BenchmarkHistoryRow

    var body: some View {
        HStack(alignment: .top, spacing: DNSPilotDesign.Spacing.controlGap) {
            Image(systemName: "clock.arrow.circlepath")
                .frame(width: 22)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.body.weight(.semibold))
                Text(row.domainSummary)
                    .foregroundStyle(.secondary)
                Text(row.recommendationLabel)
                    .font(.callout.weight(.semibold))
            }
            Spacer(minLength: DNSPilotDesign.Spacing.panel)
            VStack(alignment: .trailing, spacing: 4) {
                Text(row.healthLabel)
                    .font(.caption.weight(.semibold))
                Text(row.resolverSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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

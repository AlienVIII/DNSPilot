import AppKit
import SwiftUI
import OSLog
import DNSPilotMacCore

@main
struct DNSPilotMacApp: App {
    @NSApplicationDelegateAdaptor(DNSPilotApplicationDelegate.self) private var applicationDelegate
    @StateObject private var navigation = DNSPilotNavigationModel()

    var body: some Scene {
        WindowGroup("DNS Pilot", id: DNSPilotWindowID.main) {
            DNSPilotShellView(navigation: navigation)
                .frame(minWidth: 900, minHeight: 620)
        }

        MenuBarExtra("DNS Pilot", systemImage: "network") {
            DNSPilotMenuBarView(navigation: navigation)
        }
    }
}

private enum DNSPilotWindowID {
    static let main = "main"
}

private enum SidebarSelection: Hashable {
    case capabilities
    case benchmark
    case customDNS
    case history
    case catalog
}

@MainActor
private final class DNSPilotNavigationModel: ObservableObject {
    @Published var selection: SidebarSelection? = .capabilities
    @Published var quickBenchmarkRequestID = 0

    func requestQuickBenchmark() {
        selection = .benchmark
        quickBenchmarkRequestID += 1
    }
}

private struct DNSPilotMenuBarView: View {
    @ObservedObject var navigation: DNSPilotNavigationModel
    @Environment(\.openWindow) private var openWindow

    private let viewModel = MenuBarQuickActionsViewModel()

    var body: some View {
        ForEach(viewModel.actions) { action in
            switch action.kind {
            case .destination(let destination):
                Button {
                    open(destination)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            case .quit:
                Divider()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        }
    }

    private func open(_ destination: MenuBarQuickDestination) {
        switch destination {
        case .openApp:
            navigation.selection = .capabilities
        case .benchmark:
            navigation.selection = .benchmark
        case .quickBenchmark:
            navigation.requestQuickBenchmark()
        case .history:
            navigation.selection = .history
        case .networkSettings:
            openNetworkSettings()
            return
        }

        openWindow(id: DNSPilotWindowID.main)
        DNSPilotWindowActivation.activateSoon()
    }
}

@MainActor
private enum DNSPilotWindowActivation {
    static func activateSoon() {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            activateExistingWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(120)) {
            activateExistingWindow()
        }
    }

    private static func activateExistingWindow() {
        NSApp.windows
            .filter { $0.canBecomeKey && !$0.isMiniaturized }
            .forEach { $0.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
private final class DNSPilotApplicationDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.dnspilot.mac", category: "windowing")
    private var fallbackMainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.logger.info("Application did finish launching")
        applyActivationPlan(.launch)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.logger.info("Application reopen requested visible_windows=\(flag, privacy: .public)")
        if !flag {
            openMainWindowIfNeeded()
        }
        return true
    }

    private func applyActivationPlan(_ plan: DNSPilotApplicationActivationPlan) {
        for action in plan.actions {
            switch action {
            case .setRegularActivationPolicy:
                NSApp.setActivationPolicy(.regular)
            case .activateIgnoringOtherApps:
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }
            case .ensureMainWindowVisible(let delayMilliseconds):
                Self.logger.info("Scheduling main window visibility check delay_ms=\(delayMilliseconds, privacy: .public)")
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMilliseconds)) { [weak self] in
                    self?.openMainWindowIfNeeded()
                }
            }
        }
    }

    private func openMainWindowIfNeeded() {
        let usableMainWindowCount = NSApp.windows.filter(Self.isUsableMainWindow).count
        Self.logger.info("Checking main window visibility usable_windows=\(usableMainWindowCount, privacy: .public)")
        if NSApp.windows.contains(where: Self.isUsableMainWindow) {
            return
        }

        if let fallbackMainWindow {
            fallbackMainWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DNSPilotMac"
        window.contentView = NSHostingView(
            rootView: DNSPilotShellView(navigation: DNSPilotNavigationModel())
                .frame(minWidth: 900, minHeight: 620)
        )
        window.center()
        fallbackMainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Self.logger.info("Created fallback main window")
    }

    private static func isUsableMainWindow(_ window: NSWindow) -> Bool {
        window.isVisible
            && window.canBecomeKey
            && !window.isMiniaturized
            && window.frame.width >= 600
            && window.frame.height >= 400
    }
}

private struct DNSPilotShellView: View {
    @ObservedObject var navigation: DNSPilotNavigationModel
    @State private var catalogViewModel = CatalogViewModel()
    @State private var hasRequestedStorageCatalogRefresh = false

    private let capabilityViewModel = CapabilityMatrixViewModel()

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.selection) {
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
            .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            switch navigation.selection ?? .capabilities {
            case .capabilities:
                CapabilityMatrixDetailView(viewModel: capabilityViewModel)
            case .benchmark:
                BenchmarkDetailHostView(
                    catalogViewModel: catalogViewModel,
                    quickBenchmarkRequestID: navigation.quickBenchmarkRequestID,
                    onCatalogChanged: refreshCatalogFromStorage
                )
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
    @State private var editingProfileID: String?
    @State private var customProfiles: [CatalogProfile] = []
    @State private var isLoadingProfiles = false
    @State private var isDeletingProfile = false
    @State private var profileListError: String?
    @State private var profilePendingDelete: CustomDNSProfileManagementRow?
    @State private var isDeleteConfirmationPresented = false
    @State private var saveState: CustomDNSProfileEditorState = .idle

    private var editorViewModel: CustomDNSProfileEditorViewModel {
        CustomDNSProfileEditorViewModel(
            name: name,
            ipv4ServersText: ipv4ServersText,
            ipv6ServersText: ipv6ServersText,
            profileID: editingProfileID,
            state: saveState
        )
    }

    private var managementViewModel: CustomDNSProfileManagementViewModel {
        CustomDNSProfileManagementViewModel(profiles: customProfiles)
    }

    private var isSaving: Bool {
        if case .saving = saveState {
            return true
        }
        return false
    }

    private var isMutatingProfile: Bool {
        isSaving || isDeletingProfile
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
                            Label(saveButtonLabel, systemImage: "tray.and.arrow.down")
                        }
                    }
                    .disabled(!editorViewModel.canSave || isMutatingProfile)
                    .help(editorViewModel.canSave ? "Save profile" : "Resolve validation issues")
                }

                if shouldShowIssues, !editorViewModel.issues.isEmpty {
                    BenchmarkIssueList(issues: editorViewModel.issues)
                }

                if let statusMessage = editorViewModel.statusMessage {
                    CustomDNSSaveStatusView(state: saveState, message: statusMessage)
                }

                if let profileListError {
                    BenchmarkIssueList(issues: [profileListError])
                }

                BenchmarkSection(title: "Saved Profiles") {
                    if isLoadingProfiles {
                        ProgressView()
                            .controlSize(.small)
                    } else if managementViewModel.rows.isEmpty {
                        Label("No custom plain DNS profiles.", systemImage: "tray")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                            ForEach(managementViewModel.rows) { row in
                                CustomDNSProfileManagementRowView(
                                    row: row,
                                    isSelected: row.id == editingProfileID,
                                    isDisabled: isMutatingProfile,
                                    onEdit: { editProfile(row) },
                                    onDelete: { requestDeleteProfile(row) }
                                )
                            }
                        }
                    }
                }

                BenchmarkSection(title: "Profile") {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 360, alignment: .leading)
                            .disabled(isMutatingProfile)
                        Label(editorViewModel.profileIDLabel, systemImage: "tag")
                            .foregroundStyle(.secondary)
                        if editingProfileID != nil {
                            Button(action: clearEditor) {
                                Label("New Profile", systemImage: "plus")
                            }
                            .disabled(isMutatingProfile)
                        }
                    }
                }

                BenchmarkSection(title: "Servers") {
                    HStack(alignment: .top, spacing: DNSPilotDesign.Spacing.panel) {
                        CustomDNSServerEditor(
                            title: "IPv4",
                            text: $ipv4ServersText,
                            isDisabled: isMutatingProfile
                        )
                        CustomDNSServerEditor(
                            title: "IPv6",
                            text: $ipv6ServersText,
                            isDisabled: isMutatingProfile
                        )
                    }
                }
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
        .onAppear(perform: loadCustomProfiles)
        .onChange(of: name) { _, _ in resetTransientSaveState() }
        .onChange(of: ipv4ServersText) { _, _ in resetTransientSaveState() }
        .onChange(of: ipv6ServersText) { _, _ in resetTransientSaveState() }
        .alert(
            "Delete Custom DNS Profile?",
            isPresented: $isDeleteConfirmationPresented,
            presenting: profilePendingDelete
        ) { row in
            Button("Delete", role: .destructive) {
                deleteProfile(row)
            }
            Button("Cancel", role: .cancel) {
                profilePendingDelete = nil
            }
        } message: { row in
            Text("Delete \(row.name)? This removes it from saved profiles and Benchmark options.")
        }
    }

    private var saveButtonLabel: String {
        if isSaving {
            return editorViewModel.saveButtonLabel
        }
        return editingProfileID == nil ? "Save Profile" : "Update Profile"
    }

    private func saveProfile() {
        guard !isMutatingProfile else {
            return
        }
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
        let mode: CustomDNSProfileWriteMode = editingProfileID == nil ? .add : .update

        DispatchQueue.global(qos: .userInitiated).async {
            let coordinator = CustomDNSProfileSaveCoordinator(
                runner: CustomDNSProfileSaveRunner(executableURL: executableURL)
            )
            let outcome = coordinator.save(form: form, databaseURL: databaseURL, mode: mode)

            DispatchQueue.main.async {
                switch outcome {
                case .saved(let profileID, let name):
                    editingProfileID = profileID
                    saveState = .saved(profileID: profileID, name: name)
                    onProfileSaved()
                    loadCustomProfiles()
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

    private func loadCustomProfiles() {
        guard !isLoadingProfiles else {
            return
        }
        guard let factory = makePreparedHistoryPersistenceFactory() else {
            profileListError = "Profile storage is unavailable."
            return
        }
        isLoadingProfiles = true
        profileListError = nil
        let databaseURL = factory.databaseURL
        let executableURL = executableURL

        DispatchQueue.global(qos: .userInitiated).async {
            let runner = CatalogStorageRunner(executableURL: executableURL)
            let result = Result {
                try runner.loadProfiles(databaseURL: databaseURL)
            }

            DispatchQueue.main.async {
                switch result {
                case .success(let profiles):
                    customProfiles = profiles
                case .failure(let error):
                    profileListError = error.localizedDescription
                }
                isLoadingProfiles = false
            }
        }
    }

    private func editProfile(_ row: CustomDNSProfileManagementRow) {
        guard !isMutatingProfile else {
            return
        }
        editingProfileID = row.opensAsNewProfile ? nil : row.id
        name = row.name
        ipv4ServersText = row.ipv4ServersText
        ipv6ServersText = row.ipv6ServersText
        saveState = .idle
    }

    private func requestDeleteProfile(_ row: CustomDNSProfileManagementRow) {
        guard !isMutatingProfile else {
            return
        }
        profilePendingDelete = row
        isDeleteConfirmationPresented = true
    }

    private func deleteProfile(_ row: CustomDNSProfileManagementRow) {
        guard !isMutatingProfile else {
            return
        }
        guard let factory = makePreparedHistoryPersistenceFactory() else {
            saveState = .failed("Profile storage is unavailable.")
            return
        }
        isDeletingProfile = true
        saveState = .idle
        let databaseURL = factory.databaseURL
        let executableURL = executableURL

        DispatchQueue.global(qos: .userInitiated).async {
            let runner = CustomDNSProfileDeleteRunner(executableURL: executableURL)
            let result = Result {
                try runner.delete(profileID: row.id, databaseURL: databaseURL)
            }

            DispatchQueue.main.async {
                isDeletingProfile = false
                profilePendingDelete = nil
                switch result {
                case .success:
                    if editingProfileID == row.id {
                        clearEditor()
                    }
                    onProfileSaved()
                    loadCustomProfiles()
                case .failure(let error):
                    saveState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func clearEditor() {
        editingProfileID = nil
        name = ""
        ipv4ServersText = ""
        ipv6ServersText = ""
        saveState = .idle
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
            DNSPilotMultilineTextInput(text: $text, isEditable: !isDisabled)
                .frame(minWidth: 260, minHeight: 110)
                .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control)
                        .stroke(.separator.opacity(0.5))
                }
        }
        .frame(maxWidth: 340, alignment: .leading)
    }
}

private struct CustomDNSProfileManagementRowView: View {
    let row: CustomDNSProfileManagementRow
    let isSelected: Bool
    let isDisabled: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DNSPilotDesign.Spacing.row) {
            Image(systemName: isSelected ? "pencil.circle.fill" : "server.rack")
                .foregroundStyle(isSelected ? DNSPilotDesign.Palette.accent : .secondary)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.body.weight(.semibold))
                Text(row.detailLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(row.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if let warningLabel = row.warningLabel {
                    Label(warningLabel, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(DNSPilotDesign.Palette.warning)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .labelStyle(.iconOnly)
            .help(row.editHelpLabel)
            .disabled(isDisabled)

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .help("Delete profile")
            .disabled(isDisabled)
        }
        .padding(DNSPilotDesign.Spacing.row)
        .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control)
                .stroke(isSelected ? DNSPilotDesign.Palette.accent.opacity(0.8) : Color(nsColor: .separatorColor).opacity(0.45))
        }
    }
}

private struct CustomDomainSuiteManagementRowView: View {
    let row: CustomDomainSuiteManagementRow
    let isSelected: Bool
    let isDisabled: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DNSPilotDesign.Spacing.row) {
            Image(systemName: isSelected ? "pencil.circle.fill" : "list.bullet.rectangle")
                .foregroundStyle(isSelected ? DNSPilotDesign.Palette.accent : .secondary)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.name)
                    .font(.body.weight(.semibold))
                Text(row.domainCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(row.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if let warningLabel = row.warningLabel {
                    Label(warningLabel, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(DNSPilotDesign.Palette.warning)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .labelStyle(.iconOnly)
            .help(row.editHelpLabel)
            .disabled(isDisabled)

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .help("Delete suite")
            .disabled(isDisabled)
        }
        .padding(DNSPilotDesign.Spacing.row)
        .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control)
                .stroke(isSelected ? DNSPilotDesign.Palette.accent.opacity(0.8) : Color(nsColor: .separatorColor).opacity(0.45))
        }
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
                            Text(row.applyLabel)
                            Text(row.flushLabel)
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
    let quickBenchmarkRequestID: Int
    let onCatalogChanged: () -> Void

    var body: some View {
        if let loadErrorMessage = catalogViewModel.loadErrorMessage {
            BenchmarkUnavailableView(message: loadErrorMessage)
        } else if let catalog = catalogViewModel.catalog {
            BenchmarkDetailView(
                catalog: catalog,
                executableAvailability: BenchmarkExecutableResolver().resolve(),
                quickBenchmarkRequestID: quickBenchmarkRequestID,
                onCatalogChanged: onCatalogChanged
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
    @State private var isDeleting = false
    @State private var outcome: BenchmarkHistoryLoadOutcome?
    @State private var historyPendingDelete: BenchmarkHistoryRow?
    @State private var isDeleteHistoryConfirmationPresented = false
    @State private var isClearHistoryConfirmationPresented = false

    private var isMutatingHistory: Bool {
        isLoading || isDeleting
    }

    private var hasLoadedHistoryRows: Bool {
        guard case .loaded(let viewModel) = outcome else {
            return false
        }
        return !viewModel.rows.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                HStack {
                    Text("History")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button(action: loadHistory) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isMutatingHistory)
                    Button(role: .destructive, action: requestClearHistory) {
                        Label("Clear All", systemImage: "trash")
                    }
                    .disabled(isMutatingHistory || !hasLoadedHistoryRows)
                    .help("Delete all saved benchmark runs")
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }

                switch outcome {
                case .loaded(let viewModel):
                    HistoryResultPanel(
                        viewModel: viewModel,
                        isDisabled: isMutatingHistory,
                        onDelete: requestDeleteHistory
                    )
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
        .alert(
            "Delete Saved Run?",
            isPresented: $isDeleteHistoryConfirmationPresented,
            presenting: historyPendingDelete
        ) { row in
            Button("Delete", role: .destructive) {
                deleteHistory(row)
            }
            Button("Cancel", role: .cancel) {
                historyPendingDelete = nil
            }
        } message: { row in
            Text("Delete \(row.id)? This removes it from local benchmark history.")
        }
        .alert("Clear History?", isPresented: $isClearHistoryConfirmationPresented) {
            Button("Clear All", role: .destructive) {
                clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete all saved benchmark runs? This cannot be undone.")
        }
    }

    private func loadHistory() {
        guard !isMutatingHistory else {
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

    private func requestDeleteHistory(_ row: BenchmarkHistoryRow) {
        guard !isMutatingHistory else {
            return
        }
        historyPendingDelete = row
        isDeleteHistoryConfirmationPresented = true
    }

    private func deleteHistory(_ row: BenchmarkHistoryRow) {
        guard !isMutatingHistory else {
            return
        }
        guard let factory = makePreparedHistoryPersistenceFactory() else {
            outcome = .failed("Benchmark history storage is unavailable.")
            return
        }

        isDeleting = true
        let databaseURL = factory.databaseURL
        let executableURL = executableURL
        let historyID = row.id

        DispatchQueue.global(qos: .userInitiated).async {
            let runner = BenchmarkHistoryRunner(executableURL: executableURL)
            let result = Result {
                try runner.delete(historyID: historyID, databaseURL: databaseURL)
            }

            DispatchQueue.main.async {
                historyPendingDelete = nil
                switch result {
                case .success:
                    isDeleting = false
                    loadHistory()
                case .failure(let error):
                    outcome = .failed(error.localizedDescription)
                    isDeleting = false
                }
            }
        }
    }

    private func requestClearHistory() {
        guard !isMutatingHistory, hasLoadedHistoryRows else {
            return
        }
        isClearHistoryConfirmationPresented = true
    }

    private func clearHistory() {
        guard !isMutatingHistory else {
            return
        }
        guard let factory = makePreparedHistoryPersistenceFactory() else {
            outcome = .failed("Benchmark history storage is unavailable.")
            return
        }

        isDeleting = true
        let databaseURL = factory.databaseURL
        let executableURL = executableURL

        DispatchQueue.global(qos: .userInitiated).async {
            let runner = BenchmarkHistoryRunner(executableURL: executableURL)
            let result = Result {
                try runner.clear(databaseURL: databaseURL)
            }

            DispatchQueue.main.async {
                switch result {
                case .success:
                    isDeleting = false
                    loadHistory()
                case .failure(let error):
                    outcome = .failed(error.localizedDescription)
                    isDeleting = false
                }
            }
        }
    }
}

private struct BenchmarkDetailView: View {
    let catalog: CatalogSnapshot
    let executableAvailability: BenchmarkExecutableAvailability
    let quickBenchmarkRequestID: Int
    let onCatalogChanged: () -> Void

    @State private var selectedProfileIDs: [String]
    @State private var selectedSuiteID: String?
    @State private var customDomainsText: String
    @State private var suiteNameText: String
    @State private var suiteSaveState: CustomSuiteSaveState
    @State private var editingSuiteID: String?
    @State private var suitePendingDelete: CustomDomainSuiteManagementRow?
    @State private var isDeleteSuiteConfirmationPresented = false
    @State private var isDeletingSuite = false
    @State private var attempts: Int
    @State private var dnsTimeoutMS: Int
    @State private var connectTimeoutMS: Int
    @State private var maxConnectTargetsPerDomain: Int
    @State private var recordFamily: BenchmarkRecordFamily
    @State private var resolverTransport: BenchmarkResolverTransport
    @State private var mode: BenchmarkPlanMode
    @State private var runStateMachine = BenchmarkRunStateMachine()
    @State private var currentCancellation: BenchmarkRunCancellation?
    @State private var currentBenchmarkPlan: BenchmarkPlanViewModel?
    @State private var currentBenchmarkStartedAt: Date?
    @State private var currentProgressEvents: [BenchmarkProgressEvent] = []
    @State private var lastBenchmarkElapsedMS: Int?
    @State private var handledQuickBenchmarkRequestID = 0
    @State private var outcome: BenchmarkExecutionOutcome?

    private var setupViewModel: BenchmarkSetupViewModel {
        BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: executableAvailability,
            selectedProfileIDs: selectedProfileIDs,
            selectedSuiteID: selectedSuiteID,
            customDomainsText: customDomainsText,
            attempts: attempts,
            dnsTimeoutMS: dnsTimeoutMS,
            connectTimeoutMS: connectTimeoutMS,
            maxConnectTargetsPerDomain: maxConnectTargetsPerDomain,
            recordFamily: recordFamily,
            resolverTransport: resolverTransport,
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
            historySaved: completedResultSavedHistory,
            planSummary: BenchmarkProgressPlanSummary(plan: currentBenchmarkPlan ?? setupViewModel.plan),
            progressEvents: currentProgressEvents
        )
    }

    private var suiteForm: CustomDomainSuiteFormViewModel {
        CustomDomainSuiteFormViewModel(
            name: suiteNameText,
            domainsText: customDomainsText,
            suiteID: editingSuiteID
        )
    }

    private var suiteManagementViewModel: CustomDomainSuiteManagementViewModel {
        CustomDomainSuiteManagementViewModel(testSuites: catalog.testSuites)
    }

    private var completedResultSavedHistory: Bool {
        guard case .completed(let resultViewModel) = outcome else {
            return false
        }
        return resultViewModel.savedHistoryLabel != nil
    }

    init(
        catalog: CatalogSnapshot,
        executableAvailability: BenchmarkExecutableAvailability,
        quickBenchmarkRequestID: Int,
        onCatalogChanged: @escaping () -> Void
    ) {
        self.catalog = catalog
        self.executableAvailability = executableAvailability
        self.quickBenchmarkRequestID = quickBenchmarkRequestID
        self.onCatalogChanged = onCatalogChanged
        let defaults = BenchmarkSetupViewModel(
            catalog: catalog,
            executableAvailability: executableAvailability
        )
        _selectedProfileIDs = State(initialValue: defaults.selectedProfileIDs)
        _selectedSuiteID = State(initialValue: defaults.selectedSuiteID)
        _customDomainsText = State(initialValue: defaults.customDomainsText)
        _suiteNameText = State(initialValue: "")
        _suiteSaveState = State(initialValue: .idle)
        _attempts = State(initialValue: defaults.attempts)
        _dnsTimeoutMS = State(initialValue: defaults.dnsTimeoutMS)
        _connectTimeoutMS = State(initialValue: defaults.connectTimeoutMS)
        _maxConnectTargetsPerDomain = State(initialValue: defaults.maxConnectTargetsPerDomain)
        _recordFamily = State(initialValue: defaults.recordFamily)
        _resolverTransport = State(initialValue: defaults.resolverTransport)
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
                        .accessibilityLabel("Cancel benchmark")
                        .accessibilityIdentifier("benchmark-cancel-button")
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
                    .accessibilityLabel(runControls.primaryLabel == "Run" ? "Run benchmark" : runControls.primaryLabel)
                    .accessibilityIdentifier("benchmark-run-button")
                    .disabled(!runControls.isPrimaryEnabled)
                    .help(setupViewModel.canRun ? "Run benchmark" : "Resolve readiness issues")
                }

                Label(setupViewModel.runPlanSummary, systemImage: "list.bullet.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(setupViewModel.flushPolicySummary, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let estimatedDurationWarning = setupViewModel.estimatedDurationWarning {
                    Label(estimatedDurationWarning, systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(DNSPilotDesign.Palette.warning)
                }

                if !setupViewModel.readinessIssues.isEmpty {
                    BenchmarkIssueList(issues: setupViewModel.readinessIssues)
                }

                if shouldShowBenchmarkRunArtifacts, progressViewModel.shouldDisplay {
                    BenchmarkProgressPanel(
                        viewModel: progressViewModel,
                        startedAt: currentBenchmarkStartedAt,
                        completedElapsedMS: lastBenchmarkElapsedMS
                    )
                }

                if shouldShowBenchmarkOutcome, let outcome {
                    switch outcome {
                    case .completed(let resultViewModel):
                        BenchmarkResultPanel(
                            viewModel: resultViewModel,
                            elapsedMS: lastBenchmarkElapsedMS
                        )
                    case .failed(let failure):
                        BenchmarkFailurePanel(
                            failure: failure,
                            mode: mode,
                            elapsedMS: lastBenchmarkElapsedMS
                        )
                    }
                }

                BenchmarkSection(title: "Mode") {
                    Picker("Mode", selection: $mode) {
                        Text(BenchmarkPlanMode.dnsOnlyCompare.displayLabel)
                            .help(BenchmarkPlanMode.dnsOnlyCompare.helpText)
                            .tag(BenchmarkPlanMode.dnsOnlyCompare)
                        Text(BenchmarkPlanMode.connectionPathCompare.displayLabel)
                            .help(BenchmarkPlanMode.connectionPathCompare.helpText)
                            .tag(BenchmarkPlanMode.connectionPathCompare)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 280, alignment: .leading)
                    .help(mode.helpText)

                    Picker("Resolver", selection: $resolverTransport) {
                        ForEach(BenchmarkResolverTransport.allCases, id: \.self) { transport in
                            Text(transport.displayLabel)
                                .help(transport.helpText)
                                .tag(transport)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 280, alignment: .leading)
                    .help(resolverTransport.helpText)

                    Picker("DNS records", selection: $recordFamily) {
                        ForEach(BenchmarkRecordFamily.allCases, id: \.self) { family in
                            Text(family.displayLabel)
                                .help(family.helpText)
                                .tag(family)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 340, alignment: .leading)
                    .help(recordFamily.helpText)
                }

                BenchmarkSection(title: "Profiles") {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                        Toggle(isOn: selectAllProfilesBinding) {
                            Text("Select all runnable")
                                .font(.body.weight(.semibold))
                        }
                        .disabled(setupViewModel.runnableProfileIDs.isEmpty || isBenchmarkActive)
                        .help(
                            """
                            EN: Select every plain DNS profile that can run with the current Resolver option.
                            VI: Chọn tất cả profile DNS thường có thể chạy với option Resolver hiện tại.
                            """
                        )

                        Text(setupViewModel.profileSelectionSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let profileSelectionCaveat = setupViewModel.profileSelectionCaveat {
                            Label(profileSelectionCaveat, systemImage: "line.3.horizontal.decrease.circle")
                                .font(.caption)
                                .foregroundStyle(DNSPilotDesign.Palette.warning)
                        }

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
                            .disabled(!option.isRunnable || isBenchmarkActive)
                            .help(option.helpText)
                        }
                    }
                }

                BenchmarkSection(title: "Targets") {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                        Picker("Suite", selection: $selectedSuiteID) {
                            Text("Custom only")
                                .help(
                                    """
                                    EN: Use only the custom domains typed below.
                                    VI: Chỉ dùng các domain tự nhập bên dưới.
                                    """
                                )
                                .tag(Optional<String>.none)
                            ForEach(setupViewModel.suiteOptions) { option in
                                Text("\(option.name) (\(option.domainCountLabel))")
                                    .help(option.helpText)
                                    .tag(Optional(option.id))
                            }
                        }
                        .frame(maxWidth: 360, alignment: .leading)
                        .help(
                            """
                            EN: Choose a saved domain suite, or choose Custom only and type domains below.
                            VI: Chọn bộ domain đã lưu, hoặc chọn Custom only rồi nhập domain bên dưới.
                            """
                        )

                        DNSPilotMultilineTextInput(text: $customDomainsText)
                            .frame(minHeight: 88, alignment: .topLeading)
                            .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control))
                            .overlay {
                                RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control)
                                    .stroke(.separator.opacity(0.5))
                            }
                            .help(
                                """
                                EN: Enter domains separated by commas, spaces, or new lines.
                                VI: Nhập domain, phân tách bằng dấu phẩy, khoảng trắng hoặc xuống dòng.
                                """
                            )

                        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                            HStack(spacing: DNSPilotDesign.Spacing.row) {
                                TextField("Suite name", text: $suiteNameText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 260, alignment: .leading)
                                    .disabled(isBenchmarkActive || isMutatingSuite)
                                    .help(
                                        """
                                        EN: Name for saving the custom domain list as a reusable suite.
                                        VI: Tên để lưu danh sách domain thành một bộ test dùng lại.
                                        """
                                    )

                                Button(action: saveCustomSuite) {
                                    if isSavingSuite {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Label(suiteSaveButtonLabel, systemImage: "tray.and.arrow.down")
                                    }
                                }
                                .disabled(!suiteForm.canSave || isBenchmarkActive || isMutatingSuite)
                                .help(
                                    suiteForm.canSave
                                        ? """
                                          EN: Save these custom domains as a reusable suite.
                                          VI: Lưu các domain này thành bộ test dùng lại.
                                          """
                                        : suiteForm.issues.joined(separator: "\n")
                                )

                                if editingSuiteID != nil {
                                    Button(action: clearSuiteEditor) {
                                        Label("New Suite", systemImage: "plus")
                                    }
                                    .disabled(isBenchmarkActive || isMutatingSuite)
                                    .help(
                                        """
                                        EN: Create a new suite instead of updating the selected suite.
                                        VI: Tạo bộ test mới thay vì cập nhật bộ đang chọn.
                                        """
                                    )
                                }

                                Button(action: fillAzureSuiteExample) {
                                    Label("Azure Example", systemImage: "sparkles")
                                }
                                .disabled(isBenchmarkActive || isMutatingSuite)
                                .help(
                                    """
                                    EN: Fill common Azure and Microsoft domains for a quick example.
                                    VI: Điền nhanh các domain Azure/Microsoft phổ biến làm ví dụ.
                                    """
                                )
                            }

                            if shouldShowSuiteIssues, !suiteForm.issues.isEmpty {
                                ForEach(suiteForm.issues, id: \.self) { issue in
                                    Label(issue, systemImage: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundStyle(DNSPilotDesign.Palette.warning)
                                }
                            }

                            if let suiteSaveMessage {
                                Label(suiteSaveMessage, systemImage: suiteSaveSystemImage)
                                    .font(.caption)
                                    .foregroundStyle(suiteSaveForegroundStyle)
                            }

                            if !suiteManagementViewModel.rows.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                                    Text("Saved suites")
                                        .font(.headline)
                                    ForEach(suiteManagementViewModel.rows) { row in
                                        CustomDomainSuiteManagementRowView(
                                            row: row,
                                            isSelected: row.id == editingSuiteID,
                                            isDisabled: isBenchmarkActive || isMutatingSuite,
                                            onEdit: { editCustomSuite(row) },
                                            onDelete: { requestDeleteCustomSuite(row) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                BenchmarkSection(title: "Attempts") {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                        Stepper(value: $attempts, in: 1...5) {
                            Text("Attempts: \(attempts)")
                                .font(.body.monospacedDigit())
                        }
                        .frame(maxWidth: 220, alignment: .leading)
                        .help(
                            """
                            EN: More attempts reduce noise but make the benchmark take longer.
                            VI: Nhiều lượt đo hơn sẽ ổn định hơn nhưng benchmark lâu hơn.
                            """
                        )

                        Stepper(value: $dnsTimeoutMS, in: 200...5_000, step: 100) {
                            Text("DNS timeout: \(dnsTimeoutMS) ms")
                                .font(.body.monospacedDigit())
                        }
                        .frame(maxWidth: 260, alignment: .leading)
                        .help(
                            """
                            EN: Maximum wait for each DNS lookup. Increase on slow networks; lower for quick smoke tests.
                            VI: Thời gian chờ tối đa cho mỗi lần phân giải DNS. Tăng khi mạng chậm, giảm khi muốn test nhanh.
                            """
                        )

                        if mode == .connectionPathCompare {
                            Stepper(value: $connectTimeoutMS, in: 200...5_000, step: 100) {
                                Text("TCP timeout: \(connectTimeoutMS) ms")
                                    .font(.body.monospacedDigit())
                            }
                            .frame(maxWidth: 260, alignment: .leading)
                            .help(
                                """
                                EN: Maximum wait for each TCP connect attempt after DNS resolves.
                                VI: Thời gian chờ tối đa cho mỗi lần thử kết nối TCP sau khi DNS trả IP.
                                """
                            )

                            Stepper(value: $maxConnectTargetsPerDomain, in: 1...8) {
                                Text("TCP targets/domain: \(maxConnectTargetsPerDomain)")
                                    .font(.body.monospacedDigit())
                            }
                            .frame(maxWidth: 260, alignment: .leading)
                            .help(
                                """
                                EN: Limit how many resolved IPs are tested per domain. Lower it for CDN-heavy domains.
                                VI: Giới hạn số IP được thử cho mỗi domain. Giảm giá trị này với domain/CDN có nhiều IP.
                                """
                            )
                        }
                    }
                }

            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
        .onChange(of: suiteNameText) { _, _ in resetSuiteSaveState() }
        .onChange(of: customDomainsText) { _, _ in resetSuiteSaveState() }
        .onChange(of: quickBenchmarkRequestID) { _, requestID in
            handleQuickBenchmarkRequest(requestID)
        }
        .onAppear {
            handleQuickBenchmarkRequest(quickBenchmarkRequestID)
        }
        .alert(
            "Delete Custom Suite?",
            isPresented: $isDeleteSuiteConfirmationPresented,
            presenting: suitePendingDelete
        ) { row in
            Button("Delete", role: .destructive) {
                deleteCustomSuite(row)
            }
            Button("Cancel", role: .cancel) {
                suitePendingDelete = nil
            }
        } message: { row in
            Text("Delete \(row.name)? This removes it from saved benchmark targets.")
        }
    }

    private func profileBinding(for option: BenchmarkProfileOption) -> Binding<Bool> {
        Binding(
            get: { option.isRunnable && selectedProfileIDs.contains(option.id) },
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

    private var selectAllProfilesBinding: Binding<Bool> {
        Binding(
            get: {
                let runnableIDs = setupViewModel.runnableProfileIDs
                return !runnableIDs.isEmpty && runnableIDs.allSatisfy { selectedProfileIDs.contains($0) }
            },
            set: { shouldSelectAll in
                let runnableIDs = setupViewModel.runnableProfileIDs
                if shouldSelectAll {
                    selectedProfileIDs = runnableIDs
                } else {
                    selectedProfileIDs.removeAll { runnableIDs.contains($0) }
                }
            }
        )
    }

    private var isSavingSuite: Bool {
        if case .saving = suiteSaveState {
            return true
        }
        return false
    }

    private var isMutatingSuite: Bool {
        isSavingSuite || isDeletingSuite
    }

    private var suiteSaveButtonLabel: String {
        editingSuiteID == nil ? "Save Suite" : "Update Suite"
    }

    private var shouldShowSuiteIssues: Bool {
        !suiteNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var suiteSaveMessage: String? {
        switch suiteSaveState {
        case .idle:
            nil
        case .saving:
            "Saving \(suiteForm.name)..."
        case .saved(let suiteID, let name):
            "Saved \(name) as \(suiteID)."
        case .failed(let message):
            message
        }
    }

    private var suiteSaveSystemImage: String {
        switch suiteSaveState {
        case .idle:
            "info.circle"
        case .saving:
            "clock"
        case .saved:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        }
    }

    private var suiteSaveForegroundStyle: Color {
        switch suiteSaveState {
        case .failed:
            DNSPilotDesign.Palette.warning
        case .idle, .saving, .saved:
            .secondary
        }
    }

    private var isBenchmarkActive: Bool {
        switch runStateMachine.state {
        case .running, .cancelling:
            true
        case .idle, .completed, .failed, .cancelled:
            false
        }
    }

    private var shouldShowBenchmarkOutcome: Bool {
        guard outcome != nil else {
            return false
        }
        return shouldShowBenchmarkRunArtifacts
    }

    private var shouldShowBenchmarkRunArtifacts: Bool {
        guard let currentBenchmarkPlan else {
            return true
        }
        return currentBenchmarkPlan == setupViewModel.plan
    }

    private func saveCustomSuite() {
        guard !isBenchmarkActive, !isMutatingSuite else {
            return
        }
        let form = suiteForm
        guard form.canSave else {
            suiteSaveState = .failed(form.issues.joined(separator: "\n"))
            return
        }
        guard let factory = makePreparedHistoryPersistenceFactory() else {
            suiteSaveState = .failed("Suite storage is unavailable.")
            return
        }
        guard case .ready(let executableURL) = executableAvailability else {
            suiteSaveState = .failed("DNS Pilot CLI executable is unavailable.")
            return
        }

        suiteSaveState = .saving
        let databaseURL = factory.databaseURL
        let mode: CustomDomainSuiteWriteMode = editingSuiteID == nil ? .add : .update

        DispatchQueue.global(qos: .userInitiated).async {
            let coordinator = CustomDomainSuiteSaveCoordinator(
                runner: CustomDomainSuiteSaveRunner(executableURL: executableURL)
            )
            let outcome = coordinator.save(form: form, databaseURL: databaseURL, mode: mode)

            DispatchQueue.main.async {
                switch outcome {
                case .saved(let suiteID, let name):
                    editingSuiteID = suiteID
                    selectedSuiteID = suiteID
                    suiteSaveState = .saved(suiteID: suiteID, name: name)
                    onCatalogChanged()
                case .failed(let message):
                    suiteSaveState = .failed(message)
                }
            }
        }
    }

    private func editCustomSuite(_ row: CustomDomainSuiteManagementRow) {
        guard !isBenchmarkActive, !isMutatingSuite else {
            return
        }
        editingSuiteID = row.opensAsNewSuite ? nil : row.id
        selectedSuiteID = row.opensAsNewSuite ? nil : row.id
        suiteNameText = row.name
        customDomainsText = row.domainsText
        suiteSaveState = .idle
    }

    private func requestDeleteCustomSuite(_ row: CustomDomainSuiteManagementRow) {
        guard !isBenchmarkActive, !isMutatingSuite else {
            return
        }
        suitePendingDelete = row
        isDeleteSuiteConfirmationPresented = true
    }

    private func deleteCustomSuite(_ row: CustomDomainSuiteManagementRow) {
        guard !isBenchmarkActive, !isMutatingSuite else {
            return
        }
        guard let factory = makePreparedHistoryPersistenceFactory() else {
            suiteSaveState = .failed("Suite storage is unavailable.")
            return
        }
        guard case .ready(let executableURL) = executableAvailability else {
            suiteSaveState = .failed("DNS Pilot CLI executable is unavailable.")
            return
        }

        isDeletingSuite = true
        suiteSaveState = .idle
        let databaseURL = factory.databaseURL

        DispatchQueue.global(qos: .userInitiated).async {
            let runner = CustomDomainSuiteDeleteRunner(executableURL: executableURL)
            let result = Result {
                try runner.delete(suiteID: row.id, databaseURL: databaseURL)
            }

            DispatchQueue.main.async {
                isDeletingSuite = false
                suitePendingDelete = nil
                switch result {
                case .success:
                    if selectedSuiteID == row.id {
                        selectedSuiteID = nil
                    }
                    if editingSuiteID == row.id {
                        clearSuiteEditor()
                    }
                    onCatalogChanged()
                case .failure(let error):
                    suiteSaveState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func clearSuiteEditor() {
        editingSuiteID = nil
        suiteNameText = ""
        customDomainsText = ""
        selectedSuiteID = nil
        suiteSaveState = .idle
    }

    private func resetSuiteSaveState() {
        switch suiteSaveState {
        case .saved, .failed:
            suiteSaveState = .idle
        case .idle, .saving:
            break
        }
    }

    private func fillAzureSuiteExample() {
        editingSuiteID = nil
        suiteNameText = "Azure Lab"
        customDomainsText = [
            "portal.azure.com",
            "login.microsoftonline.com",
            "management.azure.com",
            "blob.core.windows.net",
        ].joined(separator: "\n")
        selectedSuiteID = nil
    }

    private func handleQuickBenchmarkRequest(_ requestID: Int) {
        guard requestID > handledQuickBenchmarkRequestID else {
            return
        }
        handledQuickBenchmarkRequestID = requestID
        guard !isBenchmarkActive, !isMutatingSuite else {
            return
        }
        applyQuickBenchmarkPreset()
        runBenchmark()
    }

    private func applyQuickBenchmarkPreset() {
        let preset = BenchmarkSetupViewModel.quickRunPreset(
            catalog: catalog,
            executableAvailability: executableAvailability
        )
        editingSuiteID = nil
        suiteNameText = ""
        suiteSaveState = .idle
        suitePendingDelete = nil
        isDeleteSuiteConfirmationPresented = false
        selectedProfileIDs = preset.selectedProfileIDs
        selectedSuiteID = preset.selectedSuiteID
        customDomainsText = preset.customDomainsText
        attempts = preset.attempts
        dnsTimeoutMS = preset.dnsTimeoutMS
        connectTimeoutMS = preset.connectTimeoutMS
        maxConnectTargetsPerDomain = preset.maxConnectTargetsPerDomain
        recordFamily = preset.recordFamily
        resolverTransport = preset.resolverTransport
        mode = preset.mode
    }

    private func runBenchmark() {
        guard !isBenchmarkActive else {
            return
        }
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
        currentProgressEvents = []
        lastBenchmarkElapsedMS = nil
        let startedAt = Date()
        currentBenchmarkStartedAt = startedAt
        let plan = setup.plan
        currentBenchmarkPlan = plan
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
            ) { event in
                DispatchQueue.main.async {
                    guard currentCancellation === cancellation else {
                        return
                    }
                    currentProgressEvents.append(event)
                }
            }

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

private enum CustomSuiteSaveState: Equatable {
    case idle
    case saving
    case saved(suiteID: String, name: String)
    case failed(String)
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
        case .degraded:
            "exclamationmark.triangle.fill"
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
        case .degraded:
            .orange
        case .failed:
            .red
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
    let startedAt: Date?
    let completedElapsedMS: Int?

    var body: some View {
        BenchmarkSection(title: "Process") {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                BenchmarkElapsedTimeView(
                    startedAt: startedAt,
                    completedElapsedMS: completedElapsedMS
                )

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
                if !viewModel.currentStepVerboseLines.isEmpty {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                        ForEach(viewModel.currentStepVerboseLines, id: \.self) { line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.top, DNSPilotDesign.Spacing.controlGap)
                }

                if !viewModel.resolverStatuses.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                        Text("DNS status")
                            .font(.headline)
                        ForEach(viewModel.resolverStatuses) { resolver in
                            HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                                BenchmarkProgressStatusIcon(status: resolver.status)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(resolver.name)
                                        .font(.body.weight(.semibold))
                                    Text(resolver.resolver)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(resolver.detail)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(resolver.status.foregroundStyle)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct BenchmarkElapsedTimeView: View {
    let startedAt: Date?
    let completedElapsedMS: Int?

    var body: some View {
        if let startedAt {
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Label(
                    "Elapsed \(Self.elapsedLabel(from: startedAt, to: context.date))",
                    systemImage: "timer"
                )
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            }
        } else if let completedElapsedMS {
            Label(
                "Completed in \(BenchmarkElapsedTimeFormatter.label(milliseconds: completedElapsedMS))",
                systemImage: "timer"
            )
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
    }

    private static func elapsedLabel(from startDate: Date, to currentDate: Date) -> String {
        let milliseconds = Int(currentDate.timeIntervalSince(startDate) * 1_000)
        return BenchmarkElapsedTimeFormatter.label(milliseconds: milliseconds)
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
                    HStack {
                        Text("Debug log")
                            .font(.headline)
                        Spacer()
                        Button(action: copyIssueLog) {
                            Label("Copy Issue Report", systemImage: "doc.on.doc")
                        }
                    }
                    Text("Copy the full failure report when creating an issue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private func copyIssueLog() {
        copyToPasteboard(
            failure.issueReport(modeLabel: mode.displayLabel, elapsedMS: elapsedMS),
        )
    }
}

private func copyToPasteboard(_ value: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
}

private func openNetworkSettings() {
    let settingsURLs = [
        "x-apple.systempreferences:com.apple.Network-Settings.extension",
        "x-apple.systempreferences:com.apple.preference.network",
    ]

    for urlString in settingsURLs {
        guard let url = URL(string: urlString) else {
            continue
        }
        if NSWorkspace.shared.open(url) {
            return
        }
    }

    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
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
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BenchmarkResultPanel: View {
    let viewModel: BenchmarkResultViewModel
    let elapsedMS: Int?

    var body: some View {
        BenchmarkSection(title: "Result") {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                HStack(spacing: DNSPilotDesign.Spacing.panel) {
                    Label(viewModel.healthLabel, systemImage: "waveform.path.ecg")
                    Label(viewModel.scopeLabel, systemImage: "point.3.connected.trianglepath.dotted")
                    Label(viewModel.confidenceLabel, systemImage: "gauge.with.dots.needle.67percent")
                    if let recordFamilyLabel = viewModel.recordFamilyLabel {
                        Label(recordFamilyLabel, systemImage: "list.bullet.rectangle")
                    }
                    if let elapsedMS {
                        Label(
                            "Completed in \(BenchmarkElapsedTimeFormatter.label(milliseconds: elapsedMS))",
                            systemImage: "timer"
                        )
                    }
                }
                .foregroundStyle(.secondary)

                Text(viewModel.recommendationLabel)
                    .font(.title3.weight(.semibold))

                BenchmarkResultNextStepPanel(
                    viewModel: BenchmarkResultNextStepViewModel(result: viewModel)
                )

                Button {
                    copyToPasteboard(viewModel.resultReportText(elapsedMS: elapsedMS))
                } label: {
                    Label("Copy Result Report", systemImage: "doc.on.doc")
                }

                if let savedHistoryLabel = viewModel.savedHistoryLabel {
                    HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                        Label(savedHistoryLabel, systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                        if let fullSavedHistoryID = viewModel.fullSavedHistoryID {
                            Button {
                                copyToPasteboard(fullSavedHistoryID)
                            } label: {
                                Label("Copy Run ID", systemImage: "doc.on.doc")
                            }
                            .labelStyle(.iconOnly)
                            .help("Copy full saved run ID")
                        }
                    }
                }

                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: DNSPilotDesign.Spacing.panel, verticalSpacing: DNSPilotDesign.Spacing.row) {
                        GridRow {
                            Text("Status").font(.headline)
                            Text("Profile").font(.headline)
                            Text("Resolver").font(.headline)
                            Text("Median DNS").font(.headline)
                            Text("P95 DNS").font(.headline)
                            if viewModel.showsConnectionMetrics {
                                Text("Median TCP").font(.headline)
                            }
                            Text("Failure").font(.headline)
                            Text("Diagnosis").font(.headline)
                        }

                        ForEach(viewModel.rows) { row in
                            GridRow {
                                HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                                    BenchmarkProgressStatusIcon(status: row.status)
                                    Text(row.status.displayLabel)
                                }
                                Text(row.name)
                                Text(row.resolver).font(.body.monospaced())
                                Text(row.medianDNSLatencyLabel)
                                Text(row.p95DNSLatencyLabel)
                                if viewModel.showsConnectionMetrics {
                                    Text(row.medianConnectLatencyLabel)
                                }
                                Text(row.failureRateLabel)
                                Text(row.diagnosisLabel)
                            }
                        }
                    }
                    .frame(minWidth: viewModel.showsConnectionMetrics ? 900 : 760, alignment: .leading)
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

private struct BenchmarkResultNextStepPanel: View {
    let viewModel: BenchmarkResultNextStepViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            Divider()

            Label(viewModel.title, systemImage: viewModel.canOpenNetworkSettings ? "gearshape" : "shield")
                .font(.headline)

            ForEach(viewModel.lines, id: \.self) { line in
                Label(line, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }

            if let dnsSettings = viewModel.dnsSettings {
                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                    Label("DNS servers to paste: \(dnsSettings.profileName)", systemImage: "server.rack")
                        .font(.subheadline.weight(.semibold))
                    ForEach(dnsSettings.displayLines, id: \.self) { line in
                        Label(line, systemImage: "number")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, DNSPilotDesign.Spacing.controlGap)
            }

            HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                if let dnsSettings = viewModel.dnsSettings, dnsSettings.hasServers {
                    Button {
                        copyToPasteboard(dnsSettings.serverListText)
                    } label: {
                        Label("Copy DNS Servers", systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier("benchmark-copy-dns-servers-button")
                    .help("Copy only the DNS server addresses for pasting into macOS Network Settings.")
                }

                if let manualApplyChecklistText = viewModel.manualApplyChecklistText {
                    Button {
                        copyToPasteboard(manualApplyChecklistText)
                    } label: {
                        Label("Copy Apply Checklist", systemImage: "checklist")
                    }
                    .accessibilityIdentifier("benchmark-copy-apply-checklist-button")
                    .help("Copy the manual apply and retest checklist.")
                }

                if viewModel.canOpenNetworkSettings {
                    Button {
                        openNetworkSettings()
                    } label: {
                        Label(viewModel.actionLabel, systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("benchmark-open-network-settings-button")
                }

                Button {
                    copyToPasteboard(viewModel.copyText)
                } label: {
                    Label("Copy Next Step", systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("benchmark-copy-next-step-button")
            }
        }
    }
}

private struct HistoryResultPanel: View {
    let viewModel: BenchmarkHistoryViewModel
    let isDisabled: Bool
    let onDelete: (BenchmarkHistoryRow) -> Void

    var body: some View {
        BenchmarkSection(title: "Saved Runs") {
            if viewModel.rows.isEmpty {
                Label("No saved runs yet.", systemImage: "tray")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                    ForEach(viewModel.rows) { row in
                        HistoryRowView(
                            row: row,
                            isDisabled: isDisabled,
                            onDelete: { onDelete(row) }
                        )
                    }
                }
            }
        }
    }
}

private struct HistoryRowView: View {
    let row: BenchmarkHistoryRow
    let isDisabled: Bool
    let onDelete: () -> Void

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
                Text(row.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: DNSPilotDesign.Spacing.panel)
            VStack(alignment: .trailing, spacing: 4) {
                Text(row.healthLabel)
                    .font(.caption.weight(.semibold))
                Text(row.resolverSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                copyToPasteboard(row.id)
            } label: {
                Label("Copy Run ID", systemImage: "doc.on.doc")
            }
            .labelStyle(.iconOnly)
            .help("Copy saved run ID")
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .help("Delete saved run")
            .disabled(isDisabled)
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

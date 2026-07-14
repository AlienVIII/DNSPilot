import AppKit
import SwiftUI
import OSLog
import SystemConfiguration
import DNSPilotMacCore

@main
struct DNSPilotMacApp: App {
    @NSApplicationDelegateAdaptor(DNSPilotApplicationDelegate.self) private var applicationDelegate
    @StateObject private var navigation = DNSPilotNavigationModel()

    var body: some Scene {
        Window("DNS Pilot", id: DNSPilotWindowID.main) {
            DNSPilotShellView(navigation: navigation)
                .frame(minWidth: 900, minHeight: 620)
        }

        MenuBarExtra("DNS Pilot", systemImage: "network") {
            DNSPilotMenuBarView(navigation: navigation)
        }

        Settings {
            DNSPilotSettingsView()
        }
        .commands {
            CommandMenu("DNS Pilot") {
                Button("Run Quick Test") {
                    navigation.requestQuickBenchmark()
                    _ = DNSPilotWindowActivation.activateExistingWindows()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button("Open Benchmark") {
                    navigation.selection = .benchmark
                    _ = DNSPilotWindowActivation.activateExistingWindows()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button("Open Profiles") {
                    navigation.selection = .customDNS
                    _ = DNSPilotWindowActivation.activateExistingWindows()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Open History") {
                    navigation.selection = .history
                    _ = DNSPilotWindowActivation.activateExistingWindows()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Show Result") {
                    navigation.selection = .benchmark
                    _ = DNSPilotWindowActivation.activateExistingWindows()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])

                Divider()

                Button("Cancel Benchmark") {
                    navigation.requestBenchmarkCancellation()
                }
                .keyboardShortcut(".", modifiers: [.command])

                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])

                Button("Show Setup") {
                    navigation.isShowingPermissionSetup = true
                    _ = DNSPilotWindowActivation.activateExistingWindows()
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }
    }
}

enum SidebarSelection: Hashable {
    case capabilities
    case permissions
    case publish
    case benchmark
    case customDNS
    case history
    case catalog
}

private struct PendingGuidedApplyConfirmation {
    let copyText: String
    let opensNetworkSettings: Bool
    let confirmation: StoreSafeDNSActionConfirmationViewModel
}

private struct PowerDNSActionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct StoreSafeGuidedApplyConfirmationModifier: ViewModifier {
    @Binding var pendingConfirmation: PendingGuidedApplyConfirmation?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                pendingConfirmation?.confirmation.title ?? "Confirm guided DNS apply",
                isPresented: Binding(
                    get: { pendingConfirmation != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingConfirmation = nil
                        }
                    }
                ),
                titleVisibility: .visible,
                presenting: pendingConfirmation
            ) { pending in
                Button(pending.confirmation.confirmLabel) {
                    copyToPasteboard(pending.copyText)
                    if pending.opensNetworkSettings {
                        openNetworkSettings()
                    }
                    pendingConfirmation = nil
                }
                Button(pending.confirmation.cancelLabel, role: .cancel) {
                    pendingConfirmation = nil
                }
            } message: { pending in
                Text(pending.confirmation.message)
            }
    }
}

private struct StoreSafeFlushConfirmationModifier: ViewModifier {
    @Binding var isPresented: Bool
    private let guidance = StoreSafeDNSFlushGuidanceViewModel()
    @AppStorage(MacOSPowerDNSActionConfiguration.userDefaultsKey) private var userEnabledPowerActions = false
    @State private var powerActionAlert: PowerDNSActionAlert?
    @State private var isRunningPowerFlush = false

    private var powerActionViewModel: MacOSPowerDNSActionViewModel {
        MacOSPowerDNSActionViewModel(
            isEnabled: MacOSPowerDNSActionConfiguration.isEnabled(userDefaultValue: userEnabledPowerActions)
        )
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                guidance.confirmation.title,
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                if let flushButtonLabel = powerActionViewModel.flushButtonLabel {
                    Button(flushButtonLabel) {
                        runPowerFlush()
                        isPresented = false
                    }
                    .disabled(isRunningPowerFlush)
                }
                Button(guidance.confirmation.confirmLabel) {
                    copyToPasteboard(guidance.checklistText)
                    isPresented = false
                }
                Button(guidance.confirmation.cancelLabel, role: .cancel) {
                    isPresented = false
                }
            } message: {
                Text(flushConfirmationMessage)
            }
            .alert(item: $powerActionAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }

    private var flushConfirmationMessage: String {
        guard powerActionViewModel.isEnabled else {
            return guidance.confirmation.message
        }
        return "\(powerActionViewModel.flushConfirmationMessage)\n\nYou can still copy the manual checklist instead."
    }

    private func runPowerFlush() {
        isRunningPowerFlush = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> (Bool, String) in
                do {
                    try MacOSPowerDNSActionRunner.fromEnvironment().flushDNS()
                    return (true, "macOS DNS cache was flushed.")
                } catch {
                    return (false, error.localizedDescription)
                }
            }.value

            isRunningPowerFlush = false
            if result.0 {
                powerActionAlert = PowerDNSActionAlert(title: "DNS flush complete", message: result.1)
            } else {
                powerActionAlert = PowerDNSActionAlert(title: "DNS flush failed", message: result.1)
            }
        }
    }
}

private struct PowerDNSApplyButton: View {
    let profileName: String?
    let dnsServers: [String]
    @AppStorage(MacOSPowerDNSActionConfiguration.userDefaultsKey) private var userEnabledPowerActions = false
    @State private var isShowingConfirmation = false
    @State private var isShowingRestoreConfirmation = false
    @State private var isRunningApply = false
    @State private var isRunningRestore = false
    @State private var powerActionAlert: PowerDNSActionAlert?
    @State private var rollbackSnapshot: PowerDNSRollbackSnapshot?
    private let rollbackStore = PowerDNSRollbackStore()

    private var powerActionViewModel: MacOSPowerDNSActionViewModel {
        MacOSPowerDNSActionViewModel(
            isEnabled: MacOSPowerDNSActionConfiguration.isEnabled(userDefaultValue: userEnabledPowerActions)
        )
    }

    private var rollbackViewModel: PowerDNSRollbackViewModel {
        PowerDNSRollbackViewModel(
            isEnabled: powerActionViewModel.isEnabled,
            snapshot: rollbackSnapshot
        )
    }

    var body: some View {
        if let applyButtonLabel = powerActionViewModel.applyButtonLabel, !dnsServers.isEmpty {
            HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                Button {
                    isShowingConfirmation = true
                } label: {
                    if isRunningApply {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(applyButtonLabel, systemImage: "lock.shield")
                    }
                }
                .disabled(isRunningApply || isRunningRestore)

                if let restoreButtonLabel = rollbackViewModel.restoreButtonLabel {
                    Button {
                        isShowingRestoreConfirmation = true
                    } label: {
                        if isRunningRestore {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(restoreButtonLabel, systemImage: "arrow.uturn.backward.circle")
                        }
                    }
                    .disabled(isRunningApply || isRunningRestore)
                    .help("Restore DNS for the same active network service after macOS administrator approval.")
                }
            }
            .confirmationDialog(
                "Confirm Power DNS apply",
                isPresented: $isShowingConfirmation,
                titleVisibility: .visible
            ) {
                Button(applyButtonLabel) {
                    runPowerApply()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(powerActionViewModel.applyConfirmationMessage(profileName: profileName, dnsServers: dnsServers))
            }
            .confirmationDialog(
                "Restore previous DNS?",
                isPresented: $isShowingRestoreConfirmation,
                titleVisibility: .visible
            ) {
                if let snapshot = rollbackViewModel.restorableSnapshot,
                   let restoreButtonLabel = rollbackViewModel.restoreButtonLabel {
                    Button(restoreButtonLabel) {
                        runPowerRestore(snapshot: snapshot)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(rollbackViewModel.confirmationMessage)
            }
            .alert(item: $powerActionAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .help("Ask macOS for administrator approval and apply these DNS servers to the active network service.")
            .onAppear {
                rollbackSnapshot = rollbackStore.load()
            }
        }
    }

    private func runPowerApply() {
        let servers = dnsServers
        isRunningApply = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> (PowerDNSRollbackSnapshot?, String) in
                do {
                    let snapshot = try MacOSPowerDNSActionRunner.fromEnvironment().applyDNS(servers: servers)
                    return (snapshot, "DNS was applied and local DNS cache was flushed.")
                } catch {
                    return (nil, error.localizedDescription)
                }
            }.value

            isRunningApply = false
            if let snapshot = result.0 {
                rollbackStore.save(snapshot)
                rollbackSnapshot = snapshot
                powerActionAlert = PowerDNSActionAlert(
                    title: "DNS apply complete",
                    message: "\(result.1) Previous DNS for \(snapshot.service) is ready to restore."
                )
            } else {
                powerActionAlert = PowerDNSActionAlert(title: "DNS apply failed", message: result.1)
            }
        }
    }

    private func runPowerRestore(snapshot: PowerDNSRollbackSnapshot) {
        isRunningRestore = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> (Bool, String) in
                do {
                    try MacOSPowerDNSActionRunner.fromEnvironment().restoreDNS(snapshot: snapshot)
                    return (true, "Previous DNS was restored and local DNS cache was flushed.")
                } catch {
                    return (false, error.localizedDescription)
                }
            }.value

            isRunningRestore = false
            if result.0 {
                rollbackStore.clear()
                rollbackSnapshot = nil
                powerActionAlert = PowerDNSActionAlert(title: "DNS restore complete", message: result.1)
            } else {
                powerActionAlert = PowerDNSActionAlert(title: "DNS restore failed", message: result.1)
            }
        }
    }
}

private extension View {
    func storeSafeGuidedApplyConfirmation(pending: Binding<PendingGuidedApplyConfirmation?>) -> some View {
        modifier(StoreSafeGuidedApplyConfirmationModifier(pendingConfirmation: pending))
    }

    func storeSafeFlushConfirmation(isPresented: Binding<Bool>) -> some View {
        modifier(StoreSafeFlushConfirmationModifier(isPresented: isPresented))
    }
}

private enum DNSPilotOnboardingPreferences {
    static let permissionSetupSeenKey = "DNSPilotPermissionSetupSeen"
}

private struct DNSPilotShellView: View {
    @ObservedObject var navigation: DNSPilotNavigationModel
    @AppStorage(DNSPilotLanguagePreferences.storageKey) private var languageCode = DNSPilotLanguage.system.rawValue
    @AppStorage(MacOSPowerDNSActionConfiguration.userDefaultsKey) private var userEnabledPowerActions = false
    @State private var catalogViewModel = CatalogViewModel()
    @State private var hasRequestedStorageCatalogRefresh = false

    private let capabilityViewModel = CapabilityMatrixViewModel()
    private var localizer: DNSPilotLocalizer {
        DNSPilotLocalizer(languageCode: languageCode)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.selection) {
                Section {
                    Label(localizer.text(.checkDNS), systemImage: "speedometer")
                        .tag(SidebarSelection.benchmark)
                    Label(localizer.text(.profiles), systemImage: "server.rack")
                        .tag(SidebarSelection.customDNS)
                    Label(localizer.text(.history), systemImage: "clock.arrow.circlepath")
                        .tag(SidebarSelection.history)
                }
            }
            .navigationTitle("DNS Pilot")
            .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            switch navigation.selection ?? .capabilities {
            case .capabilities:
                CapabilityMatrixDetailView(viewModel: capabilityViewModel, localizer: localizer)
            case .permissions:
                PermissionReadinessDetailView(localizer: localizer)
            case .publish:
                PublishReadinessDetailView(localizer: localizer)
            case .benchmark:
                BenchmarkDetailHostView(
                    catalogViewModel: catalogViewModel,
                    localizer: localizer,
                    quickBenchmarkRequestID: navigation.quickBenchmarkRequestID,
                    systemDNSValidationRequestID: navigation.systemDNSValidationRequestID,
                    benchmarkCancellationRequestID: navigation.benchmarkCancellationRequestID,
                    onCatalogChanged: refreshCatalogFromStorage,
                    onGuidedApplyPlanChanged: navigation.setLastGuidedApplyPlan
                )
            case .customDNS:
                CustomDNSDetailHostView(
                    executableAvailability: BenchmarkExecutableResolver().resolve(),
                    localizer: localizer,
                    onProfileSaved: refreshCatalogFromStorage
                )
            case .history:
                HistoryDetailHostView(catalogViewModel: catalogViewModel, localizer: localizer)
            case .catalog:
                CatalogOverviewDetailView(viewModel: catalogViewModel, localizer: localizer)
            }
        }
        .onAppear {
            guard !hasRequestedStorageCatalogRefresh else {
                return
            }
            hasRequestedStorageCatalogRefresh = true
            refreshCatalogFromStorage()
        }
        .confirmationDialog(
            guidedApplyConfirmationTitle,
            isPresented: Binding(
                get: { navigation.pendingGuidedApplyPlanConfirmation != nil },
                set: { isPresented in
                    if !isPresented {
                        navigation.clearGuidedApplyConfirmation()
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: navigation.pendingGuidedApplyPlanConfirmation
        ) { snapshot in
            let confirmation = guidedApplyConfirmation(for: snapshot)
            Button(confirmation.confirmLabel) {
                copyToPasteboard(snapshot.dnsServerText)
                openNetworkSettings()
                navigation.clearGuidedApplyConfirmation()
            }
            Button(confirmation.cancelLabel, role: .cancel) {
                navigation.clearGuidedApplyConfirmation()
            }
        } message: { snapshot in
            Text(guidedApplyConfirmation(for: snapshot).message)
        }
        .storeSafeFlushConfirmation(isPresented: $navigation.isShowingFlushDNSConfirmation)
        .sheet(isPresented: $navigation.isShowingPermissionSetup) {
            PermissionSetupSheet(
                localizer: localizer,
                userEnabledPowerActions: $userEnabledPowerActions,
                isPresented: $navigation.isShowingPermissionSetup
            )
        }
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    ForEach(DNSPilotLanguage.allCases) { language in
                        Button {
                            languageCode = language.rawValue
                        } label: {
                            if languageCode == language.rawValue {
                                Label(language.displayName, systemImage: "checkmark")
                            } else {
                                Text(language.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text(localizer.languageMenuLabel)
                    }
                    .fixedSize()
                }
                .help(localizer.text(.chooseLanguage))
                .accessibilityLabel(localizer.text(.chooseLanguage))
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    navigation.selection = .permissions
                    navigation.isShowingPermissionSetup = true
                } label: {
                    Label(localizer.text(.showSetup), systemImage: "questionmark.circle")
                }
                .help(localizer.text(.showSetup))
                .accessibilityLabel(localizer.text(.showSetup))
            }
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

    private var guidedApplyConfirmationTitle: String {
        if let snapshot = navigation.pendingGuidedApplyPlanConfirmation {
            return guidedApplyConfirmation(for: snapshot).title
        }
        return "Confirm guided DNS apply"
    }

    private func guidedApplyConfirmation(for snapshot: GuidedApplyPlanSnapshot) -> StoreSafeDNSActionConfirmationViewModel {
        StoreSafeDNSActionConfirmationViewModel.guidedApply(
            profileName: snapshot.profileName ?? snapshot.profileID,
            dnsServers: snapshot.dnsServers,
            hasRestoreDNS: !snapshot.restoreDNSServers.isEmpty
        )
    }
}

private struct CustomDNSDetailHostView: View {
    let executableAvailability: BenchmarkExecutableAvailability
    let localizer: DNSPilotLocalizer
    let onProfileSaved: () -> Void

    var body: some View {
        switch executableAvailability {
        case .ready(let executableURL):
            CustomDNSProfileDetailView(
                executableURL: executableURL,
                localizer: localizer,
                onProfileSaved: onProfileSaved
            )
        case .unavailable(let message):
            BenchmarkUnavailableView(title: localizer.text(.customDNS), message: message)
        }
    }
}

private struct CustomDNSProfileDetailView: View {
    let executableURL: URL
    let localizer: DNSPilotLocalizer
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
                    Text(localizer.text(.customDNS))
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
                    .help(editorViewModel.canSave ? localizer.text(.saveProfile) : "Resolve validation issues")
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

                BenchmarkSection(title: localizer.text(.savedProfiles)) {
                    if isLoadingProfiles {
                        ProgressView()
                            .controlSize(.small)
                    } else if managementViewModel.rows.isEmpty {
                        Label(localizer.text(.noCustomPlainDNSProfiles), systemImage: "tray")
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

                BenchmarkSection(title: localizer.text(.profile)) {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                        TextField(localizer.text(.name), text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 360, alignment: .leading)
                            .disabled(isMutatingProfile)
                        Label(editorViewModel.profileIDLabel, systemImage: "tag")
                            .foregroundStyle(.secondary)
                        if editingProfileID != nil {
                            Button(action: clearEditor) {
                                Label(localizer.text(.newProfile), systemImage: "plus")
                            }
                            .disabled(isMutatingProfile)
                        }
                    }
                }

                BenchmarkSection(title: localizer.text(.servers)) {
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
            localizer.text(.deleteCustomDNSProfile),
            isPresented: $isDeleteConfirmationPresented,
            presenting: profilePendingDelete
        ) { row in
            Button(localizer.text(.delete), role: .destructive) {
                deleteProfile(row)
            }
            Button(localizer.text(.cancel), role: .cancel) {
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
        return editingProfileID == nil ? localizer.text(.saveProfile) : localizer.text(.updateProfile)
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
    let localizer: DNSPilotLocalizer

    private var productGoalReadiness: ProductGoalReadinessViewModel {
        ProductGoalReadinessViewModel(localizer: localizer)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                Text(localizer.text(.capabilityMatrix))
                    .font(.title2.weight(.semibold))

                ProductGoalReadinessSection(viewModel: productGoalReadiness, localizer: localizer)

                if let loadErrorMessage = viewModel.loadErrorMessage {
                    Label(loadErrorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: DNSPilotDesign.Spacing.row) {
                        GridRow {
                            Text(localizer.text(.platform)).font(.headline)
                            Text(localizer.text(.benchmark)).font(.headline)
                            Text(localizer.text(.apply)).font(.headline)
                            Text(localizer.text(.flush)).font(.headline)
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
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
    }
}

private struct ProductGoalReadinessSection: View {
    let viewModel: ProductGoalReadinessViewModel
    let localizer: DNSPilotLocalizer

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
            Text(localizer.text(.productGoals))
                .font(.headline)

            ForEach(viewModel.rows) { row in
                ProductGoalReadinessRowView(row: row, localizer: localizer)
            }
        }
    }
}

private struct ProductGoalReadinessRowView: View {
    let row: ProductGoalReadinessRow
    let localizer: DNSPilotLocalizer

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: DNSPilotDesign.Spacing.row, verticalSpacing: 2) {
            GridRow {
                Label(row.status.localizedLabel(localizer: localizer), systemImage: row.systemImage)
                    .foregroundStyle(statusColor)
                    .frame(width: 150, alignment: .leading)
                    .help(row.caveat)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.subheadline.weight(.semibold))
                    Text(row.summary)
                        .foregroundStyle(.secondary)
                    Text(row.caveat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(localizer.text(.entryPoint)): \(row.entryPoint)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(localizer.text(.validationEvidence)): \(row.validationEvidence)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.subheadline)
    }

    private var statusColor: Color {
        switch row.status {
        case .supported:
            DNSPilotDesign.Palette.success
        case .storeSafeGuided, .estimated:
            DNSPilotDesign.Palette.warning
        }
    }
}

private struct PermissionReadinessDetailView: View {
    let localizer: DNSPilotLocalizer
    @AppStorage(MacOSPowerDNSActionConfiguration.userDefaultsKey) private var userEnabledPowerActions = false
    @State private var isShowingSetup = false

    private var viewModel: MacOSPermissionReadinessViewModel {
        MacOSPermissionReadinessViewModel(
            isPowerActionsEnabled: MacOSPowerDNSActionConfiguration.isEnabled(userDefaultValue: userEnabledPowerActions),
            isDirectAdminAvailable: MacOSPowerDNSActionConfiguration.isBuildCapable()
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                    Text(localizer.text(.permissions))
                        .font(.title2.weight(.semibold))
                    Text(localizer.text(.permissionsSubtitle))
                        .foregroundStyle(.secondary)
                }

                DirectAdminActionsPanel(userEnabledPowerActions: $userEnabledPowerActions, compact: false)

                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                    ForEach(viewModel.rows) { row in
                        MacOSReadinessRowView(row: row)
                    }
                }

                HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                    Button {
                        isShowingSetup = true
                    } label: {
                        Label("Open Setup", systemImage: "lock.shield")
                    }

                    Button {
                        copyToPasteboard(viewModel.copyText)
                    } label: {
                        Label(localizer.text(.copyChecklist), systemImage: "doc.on.doc")
                    }
                }
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
        .sheet(isPresented: $isShowingSetup) {
            PermissionSetupSheet(
                localizer: localizer,
                userEnabledPowerActions: $userEnabledPowerActions,
                isPresented: $isShowingSetup
            )
        }
    }
}

private struct PublishReadinessDetailView: View {
    let localizer: DNSPilotLocalizer
    private let viewModel = MacOSPublishReadinessViewModel()

    var body: some View {
        MacOSReadinessDetailView(
            title: localizer.text(.publish),
            subtitle: localizer.text(.publishSubtitle),
            rows: viewModel.rows,
            copyText: viewModel.copyText,
            primaryActionLabel: nil,
            primaryActionSystemImage: nil,
            primaryAction: nil,
            copyLabel: localizer.text(.copyChecklist)
        )
    }
}

private struct MacOSReadinessDetailView: View {
    let title: String
    let subtitle: String
    let rows: [MacOSReadinessRow]
    let copyText: String
    let primaryActionLabel: String?
    let primaryActionSystemImage: String?
    let primaryAction: (() -> Void)?
    let copyLabel: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                    ForEach(rows) { row in
                        MacOSReadinessRowView(row: row)
                    }
                }

                HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                    if let primaryActionLabel,
                       let primaryActionSystemImage,
                       let primaryAction {
                        Button(action: primaryAction) {
                            Label(primaryActionLabel, systemImage: primaryActionSystemImage)
                        }
                    }

                    Button {
                        copyToPasteboard(copyText)
                    } label: {
                        Label(copyLabel, systemImage: "doc.on.doc")
                    }
                }
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
    }
}

private struct MacOSReadinessRowView: View {
    let row: MacOSReadinessRow

    var body: some View {
        HStack(alignment: .top, spacing: DNSPilotDesign.Spacing.row) {
            Label(row.statusLabel, systemImage: row.systemImage)
                .foregroundStyle(statusColor)
                .frame(width: 120, alignment: .leading)
                .help(row.statusLabel)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                Text(row.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.subheadline)
    }

    private var statusColor: Color {
        switch row.status {
        case .ready:
            DNSPilotDesign.Palette.success
        case .manual:
            DNSPilotDesign.Palette.warning
        case .blocked:
            Color.red
        }
    }
}

private struct CatalogOverviewDetailView: View {
    let viewModel: CatalogViewModel
    let localizer: DNSPilotLocalizer
    @State private var pendingGuidedApplyConfirmation: PendingGuidedApplyConfirmation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                Text(localizer.text(.catalog))
                    .font(.title2.weight(.semibold))

                if let loadErrorMessage = viewModel.loadErrorMessage {
                    Label(loadErrorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                        CatalogMetricView(
                            title: localizer.text(.providers),
                            value: "\(viewModel.profileCount)",
                            systemImage: "server.rack"
                        )
                        CatalogMetricView(
                            title: localizer.text(.suites),
                            value: "\(viewModel.testSuiteCount)",
                            systemImage: "list.bullet.rectangle"
                        )
                        CatalogMetricView(
                            title: localizer.text(.filtered),
                            value: "\(viewModel.filteredProfileCount)",
                            systemImage: "shield"
                        )
                    }

                    CatalogListSection(title: localizer.text(.providers)) {
                        ForEach(viewModel.profileSummaries) { summary in
                            CatalogProfileRow(
                                summary: summary,
                                onApply: { requestGuidedApply(summary) }
                            )
                        }
                    }

                    CatalogListSection(title: localizer.text(.testSuites)) {
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
        .storeSafeGuidedApplyConfirmation(pending: $pendingGuidedApplyConfirmation)
    }

    private func requestGuidedApply(_ summary: CatalogProfileSummary) {
        guard summary.canGuideApply else {
            return
        }
        pendingGuidedApplyConfirmation = PendingGuidedApplyConfirmation(
            copyText: summary.dnsServerText,
            opensNetworkSettings: true,
            confirmation: StoreSafeDNSActionConfirmationViewModel.guidedApply(
                profileName: summary.name,
                dnsServers: summary.dnsServers,
                hasRestoreDNS: false
            )
        )
    }
}

private struct BenchmarkDetailHostView: View {
    let catalogViewModel: CatalogViewModel
    let localizer: DNSPilotLocalizer
    let quickBenchmarkRequestID: Int
    let systemDNSValidationRequestID: Int
    let benchmarkCancellationRequestID: Int
    let onCatalogChanged: () -> Void
    let onGuidedApplyPlanChanged: (GuidedApplyPlanSnapshot?) -> Void

    var body: some View {
        if let loadErrorMessage = catalogViewModel.loadErrorMessage {
            BenchmarkUnavailableView(title: localizer.text(.benchmark), message: loadErrorMessage)
        } else if let catalog = catalogViewModel.catalog {
            BenchmarkDetailView(
                catalog: catalog,
                executableAvailability: BenchmarkExecutableResolver().resolve(),
                localizer: localizer,
                quickBenchmarkRequestID: quickBenchmarkRequestID,
                systemDNSValidationRequestID: systemDNSValidationRequestID,
                benchmarkCancellationRequestID: benchmarkCancellationRequestID,
                onCatalogChanged: onCatalogChanged,
                onGuidedApplyPlanChanged: onGuidedApplyPlanChanged
            )
        } else {
            BenchmarkUnavailableView(title: localizer.text(.benchmark), message: "Catalog unavailable.")
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
    let localizer: DNSPilotLocalizer

    var body: some View {
        if let loadErrorMessage = catalogViewModel.loadErrorMessage {
            HistoryUnavailableView(title: localizer.text(.history), message: loadErrorMessage)
        } else if let catalog = catalogViewModel.catalog {
            switch BenchmarkExecutableResolver().resolve() {
            case .ready(let executableURL):
                HistoryDetailView(catalog: catalog, executableURL: executableURL, localizer: localizer)
            case .unavailable(let message):
                HistoryUnavailableView(title: localizer.text(.history), message: message)
            }
        } else {
            HistoryUnavailableView(title: localizer.text(.history), message: "Catalog unavailable.")
        }
    }
}

private struct HistoryUnavailableView: View {
    let title: String
    let message: String

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

private struct HistoryDetailView: View {
    let catalog: CatalogSnapshot
    let executableURL: URL
    let localizer: DNSPilotLocalizer

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
                    Text(localizer.text(.history))
                        .font(.title2.weight(.semibold))
                    Spacer()
                    if isDeleting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button(action: loadHistory) {
                        Label(localizer.text(.refresh), systemImage: "arrow.clockwise")
                    }
                    .disabled(isMutatingHistory)
                    Button(role: .destructive, action: requestClearHistory) {
                        Label(localizer.text(.clearAll), systemImage: "trash")
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
                        localizer: localizer,
                        onDelete: requestDeleteHistory
                    )
                case .failed(let message):
                    BenchmarkIssueList(issues: [message])
                case nil:
                    Text(localizer.text(.historyNotLoaded))
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
            localizer.text(.deleteSavedRun),
            isPresented: $isDeleteHistoryConfirmationPresented,
            presenting: historyPendingDelete
        ) { row in
            Button(localizer.text(.delete), role: .destructive) {
                deleteHistory(row)
            }
            Button(localizer.text(.cancel), role: .cancel) {
                historyPendingDelete = nil
            }
        } message: { row in
            Text("Delete \(row.id)? This removes it from local benchmark history.")
        }
        .alert(localizer.text(.clearHistory), isPresented: $isClearHistoryConfirmationPresented) {
            Button(localizer.text(.clearAll), role: .destructive) {
                clearHistory()
            }
            Button(localizer.text(.cancel), role: .cancel) {}
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
    let localizer: DNSPilotLocalizer
    let quickBenchmarkRequestID: Int
    let systemDNSValidationRequestID: Int
    let benchmarkCancellationRequestID: Int
    let onCatalogChanged: () -> Void
    let onGuidedApplyPlanChanged: (GuidedApplyPlanSnapshot?) -> Void

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
    @State private var systemDNSResolverSnapshot = SystemDNSResolverSnapshot.unavailable
    @State private var vpnActive = false
    @State private var mdmProfileActive = false
    @State private var corporateDNSDetected = false
    @State private var captivePortalDetected = false
    @State private var isOptionsExpanded = false
    @State private var runStateMachine = BenchmarkRunStateMachine()
    @State private var currentCancellation: BenchmarkRunCancellation?
    @State private var currentBenchmarkPlan: BenchmarkPlanViewModel?
    @State private var currentBenchmarkStartedAt: Date?
    @State private var currentProgressEvents: [BenchmarkProgressEvent] = []
    @State private var lastBenchmarkElapsedMS: Int?
    @State private var applyPlanOutcome: BenchmarkApplyPlanLoadOutcome?
    @State private var isLoadingApplyPlan = false
    @State private var currentApplyPlanRunID: BenchmarkRunID?
    @State private var currentDNSBeforeApplySnapshot = SystemDNSResolverSnapshot.unavailable
    @State private var isShowingFlushDNSConfirmation = false
    @State private var handledQuickBenchmarkRequestID = 0
    @State private var handledSystemDNSValidationRequestID = 0
    @State private var handledBenchmarkCancellationRequestID = 0
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
        localizer: DNSPilotLocalizer,
        quickBenchmarkRequestID: Int,
        systemDNSValidationRequestID: Int,
        benchmarkCancellationRequestID: Int,
        onCatalogChanged: @escaping () -> Void,
        onGuidedApplyPlanChanged: @escaping (GuidedApplyPlanSnapshot?) -> Void
    ) {
        self.catalog = catalog
        self.executableAvailability = executableAvailability
        self.localizer = localizer
        self.quickBenchmarkRequestID = quickBenchmarkRequestID
        self.systemDNSValidationRequestID = systemDNSValidationRequestID
        self.benchmarkCancellationRequestID = benchmarkCancellationRequestID
        self.onCatalogChanged = onCatalogChanged
        self.onGuidedApplyPlanChanged = onGuidedApplyPlanChanged
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
        benchmarkContent
            .onChange(of: suiteNameText) { _, _ in resetSuiteSaveState() }
            .onChange(of: customDomainsText) { _, _ in resetSuiteSaveState() }
            .onChange(of: vpnActive) { _, _ in reloadApplyPlanForCurrentResult() }
            .onChange(of: mdmProfileActive) { _, _ in reloadApplyPlanForCurrentResult() }
            .onChange(of: corporateDNSDetected) { _, _ in reloadApplyPlanForCurrentResult() }
            .onChange(of: captivePortalDetected) { _, _ in reloadApplyPlanForCurrentResult() }
            .onChange(of: mode) { _, nextMode in
                if nextMode == .systemDNSValidation {
                    refreshSystemDNSResolverSnapshot()
                }
            }
            .onChange(of: selectedSuiteID) { _, selectedSuiteID in
                guard let selectedSuiteID,
                      catalog.testSuites.contains(where: { $0.id == selectedSuiteID && $0.tags.contains("gaming") }) else {
                    return
                }
                mode = .connectionPathCompare
            }
            .onChange(of: quickBenchmarkRequestID) { _, requestID in
                handleQuickBenchmarkRequest(requestID)
            }
            .onChange(of: systemDNSValidationRequestID) { _, requestID in
                handleSystemDNSValidationRequest(requestID)
            }
            .onChange(of: benchmarkCancellationRequestID) { _, requestID in
                handleBenchmarkCancellationRequest(requestID)
            }
            .onAppear {
                if mode == .systemDNSValidation {
                    refreshSystemDNSResolverSnapshot()
                }
                handleQuickBenchmarkRequest(quickBenchmarkRequestID)
                handleSystemDNSValidationRequest(systemDNSValidationRequestID)
                handleBenchmarkCancellationRequest(benchmarkCancellationRequestID)
            }
            .storeSafeFlushConfirmation(isPresented: $isShowingFlushDNSConfirmation)
            .alert(
                localizer.text(.deleteCustomSuite),
                isPresented: $isDeleteSuiteConfirmationPresented,
                presenting: suitePendingDelete
            ) { row in
                Button(localizer.text(.delete), role: .destructive) {
                    deleteCustomSuite(row)
                }
                Button(localizer.text(.cancel), role: .cancel) {
                    suitePendingDelete = nil
                }
            } message: { row in
                Text("Delete \(row.name)? This removes it from saved benchmark targets.")
            }
    }

    private var benchmarkContent: AnyView {
        AnyView(
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                AnyView(benchmarkHeader)
                AnyView(benchmarkSummary)
                AnyView(benchmarkTargetPicker)
                AnyView(benchmarkRunArtifacts)
                BenchmarkOptionsDisclosure(
                    title: localizer.text(.options),
                    isExpanded: $isOptionsExpanded,
                    showHint: localizer.text(.showOptions),
                    hideHint: localizer.text(.hideOptions)
                ) {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                        AnyView(modeSection)
                        AnyView(networkSafeguardsSection)
                        AnyView(profilesSection)
                        AnyView(targetsSection)
                        AnyView(attemptsSection)
                    }
                    .padding(.top, DNSPilotDesign.Spacing.row)
                }
                .accessibilityIdentifier("benchmark-options-disclosure")
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
        )
    }

    private var benchmarkHeader: some View {
        HStack {
            Text(localizer.text(.benchmark))
                .font(.title2.weight(.semibold))
            Spacer()
            if runControls.showsCancel {
                Button(action: cancelBenchmark) {
                    Label(localizer.text(.cancel), systemImage: "xmark")
                }
                .accessibilityLabel(localizer.text(.cancelBenchmark))
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
                    Label(benchmarkRunLabel, systemImage: "play.fill")
                }
            }
            .accessibilityLabel(benchmarkRunLabel)
            .accessibilityIdentifier("benchmark-run-button")
            .disabled(!runControls.isPrimaryEnabled)
            .help(localizer.text(setupViewModel.canRun ? .runBenchmark : .resolveReadinessIssues))
        }
    }

    @ViewBuilder
    private var benchmarkSummary: some View {
        Label(setupViewModel.runPlanSummary, systemImage: "list.bullet.clipboard")
            .font(.caption)
            .foregroundStyle(.secondary)
        if setupViewModel.systemDNSFlushChecklistText != nil {
            Button {
                isShowingFlushDNSConfirmation = true
            } label: {
                Label(StoreSafeDNSFlushGuidanceViewModel().buttonLabel, systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isBenchmarkActive)
            .accessibilityIdentifier("benchmark-copy-flush-checklist-button")
            .help("Confirm and copy manual cache flush and validation steps for System DNS mode.")
        }
        if let estimatedDurationWarning = setupViewModel.estimatedDurationWarning {
            Label(estimatedDurationWarning, systemImage: "hourglass")
                .font(.caption)
                .foregroundStyle(DNSPilotDesign.Palette.warning)
        }
    }

    private var benchmarkTargetPicker: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            Picker(localizer.text(.targets), selection: $selectedSuiteID) {
                Text(localizer.text(.customOnly))
                    .tag(Optional<String>.none)
                ForEach(setupViewModel.suiteOptions) { option in
                    Text(option.name)
                        .tag(Optional(option.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 340, alignment: .leading)
            .disabled(isBenchmarkActive)
            .accessibilityIdentifier("benchmark-target-picker")
            .help(localizer.text(.benchmarkTargetHelp))

            if setupViewModel.isGamingSuiteSelected {
                Label(localizer.text(.gameCheckDisclaimer), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(setupViewModel.gameCheckDisclaimer ?? "")
            }
        }
    }

    @ViewBuilder
    private var benchmarkRunArtifacts: some View {
        if !setupViewModel.readinessIssues.isEmpty {
            BenchmarkIssueList(issues: setupViewModel.readinessIssues)
        }

        if shouldShowBenchmarkRunArtifacts, progressViewModel.shouldDisplay {
            BenchmarkProgressPanel(
                viewModel: progressViewModel,
                localizer: localizer,
                startedAt: currentBenchmarkStartedAt,
                completedElapsedMS: lastBenchmarkElapsedMS
            )
        }

        if shouldShowBenchmarkOutcome, let outcome {
            switch outcome {
            case .completed(let resultViewModel):
                BenchmarkResultPanel(
                    viewModel: resultViewModel,
                    elapsedMS: lastBenchmarkElapsedMS,
                    applyPlanOutcome: applyPlanOutcome,
                    isLoadingApplyPlan: isLoadingApplyPlan,
                    currentDNSBeforeApplySnapshot: currentDNSBeforeApplySnapshot,
                    localizer: localizer,
                    onStartSystemDNSValidation: startSystemDNSValidationBenchmark
                )
            case .failed(let failure):
                BenchmarkFailurePanel(
                    failure: failure,
                    mode: mode,
                    localizer: localizer,
                    elapsedMS: lastBenchmarkElapsedMS
                )
            }
        }
    }

    private var modeSection: some View {
        BenchmarkSection(title: localizer.text(.mode)) {
            Picker(localizer.text(.mode), selection: $mode) {
                Text(modeLabel(.dnsOnlyCompare))
                    .help(modeHelp(.dnsOnlyCompare))
                    .tag(BenchmarkPlanMode.dnsOnlyCompare)
                Text(modeLabel(.connectionPathCompare))
                    .help(modeHelp(.connectionPathCompare))
                    .tag(BenchmarkPlanMode.connectionPathCompare)
                Text(modeLabel(.systemDNSValidation))
                    .help(modeHelp(.systemDNSValidation))
                    .tag(BenchmarkPlanMode.systemDNSValidation)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 420, alignment: .leading)
            .help(modeHelp(mode))

            if mode == .systemDNSValidation {
                SystemDNSResolverStatusView(
                    viewModel: SystemDNSResolverViewModel(snapshot: systemDNSResolverSnapshot),
                    localizer: localizer,
                    isRefreshDisabled: isBenchmarkActive,
                    onRefresh: refreshSystemDNSResolverSnapshot
                )
            } else {
                Picker(localizer.text(.resolver), selection: $resolverTransport) {
                    ForEach(BenchmarkResolverTransport.allCases, id: \.self) { transport in
                        Text(resolverTransportLabel(transport))
                            .help(resolverTransportHelp(transport))
                            .tag(transport)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 280, alignment: .leading)
                .help(resolverTransportHelp(resolverTransport))
            }

            Picker(localizer.text(.dnsRecords), selection: $recordFamily) {
                ForEach(BenchmarkRecordFamily.allCases, id: \.self) { family in
                    Text(recordFamilyLabel(family))
                        .help(recordFamilyHelp(family))
                        .tag(family)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 340, alignment: .leading)
            .help(recordFamilyHelp(recordFamily))
        }
    }

    private var networkSafeguardsSection: some View {
        BenchmarkSection(title: localizer.text(.networkSafeguards)) {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                Toggle(localizer.text(.vpnActive), isOn: $vpnActive)
                    .disabled(isBenchmarkActive)
                .help(localizer.text(.vpnActiveHelp))
                Toggle(localizer.text(.mdmManaged), isOn: $mdmProfileActive)
                    .disabled(isBenchmarkActive)
                .help(localizer.text(.mdmManagedHelp))
                Toggle(localizer.text(.corporateDNSRequired), isOn: $corporateDNSDetected)
                    .disabled(isBenchmarkActive)
                .help(localizer.text(.corporateDNSRequiredHelp))
                Toggle(localizer.text(.captivePortal), isOn: $captivePortalDetected)
                    .disabled(isBenchmarkActive)
                .help(localizer.text(.captivePortalHelp))

                Label(
                    localizer.text(.safeguardExplanation),
                    systemImage: "shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var profilesSection: some View {
        BenchmarkSection(title: localizer.text(.profiles)) {
            if mode == .systemDNSValidation {
                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                    Label(localizer.text(.systemDNSProfilesIgnored), systemImage: "desktopcomputer")
                        .font(.body.weight(.semibold))
                    Label(localizer.text(.systemDNSValidationHelp), systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                profileSelectionControls
            }
        }
    }

    private var profileSelectionControls: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
            Toggle(isOn: selectAllProfilesBinding) {
                Text(localizer.text(.selectAllRunnable))
                    .font(.body.weight(.semibold))
            }
            .disabled(setupViewModel.runnableProfileIDs.isEmpty || isBenchmarkActive)
            .help(localizer.text(.selectAllRunnableHelp))

            Text(profileSelectionSummary)
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
                            Text(option.detailLabel(localizer: localizer))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .disabled(!option.isRunnable || isBenchmarkActive)
                .help(option.helpText(localizer: localizer))
            }
        }
    }

    private var targetsSection: some View {
        BenchmarkSection(title: localizer.text(.targets)) {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                targetDomainInput
                targetSuiteEditor
            }
        }
    }

    private var targetDomainInput: some View {
        DNSPilotMultilineTextInput(text: $customDomainsText)
            .frame(minHeight: 88, alignment: .topLeading)
            .background(.background, in: RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: DNSPilotDesign.Radius.control)
                    .stroke(.separator.opacity(0.5))
            }
            .help(localizer.text(.customDomainsHelp))
    }

    private var targetSuiteEditor: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            suiteEditorControls
            suiteEditorMessages
            savedSuitesList
        }
    }

    private var suiteEditorControls: some View {
        HStack(spacing: DNSPilotDesign.Spacing.row) {
            TextField(localizer.text(.suiteName), text: $suiteNameText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260, alignment: .leading)
                .disabled(isBenchmarkActive || isMutatingSuite)
                .help(localizer.text(.suiteNameHelp))

            Button(action: saveCustomSuite) {
                if isSavingSuite {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label(suiteSaveButtonLabel, systemImage: "tray.and.arrow.down")
                }
            }
            .disabled(!suiteForm.canSave || isBenchmarkActive || isMutatingSuite)
            .help(suiteForm.canSave ? localizer.text(.saveSuiteHelp) : suiteForm.issues.joined(separator: "\n"))

            if editingSuiteID != nil {
                Button(action: clearSuiteEditor) {
                    Label(localizer.text(.newSuite), systemImage: "plus")
                }
                .disabled(isBenchmarkActive || isMutatingSuite)
                .help(localizer.text(.newSuiteHelp))
            }

            Button(action: fillAzureSuiteExample) {
                Label(localizer.text(.azureExample), systemImage: "sparkles")
            }
            .disabled(isBenchmarkActive || isMutatingSuite)
            .help(localizer.text(.azureExampleHelp))
        }
    }

    @ViewBuilder
    private var suiteEditorMessages: some View {
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
    }

    @ViewBuilder
    private var savedSuitesList: some View {
        if !suiteManagementViewModel.rows.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                Text(localizer.text(.savedSuites))
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

    private var attemptsSection: some View {
        BenchmarkSection(title: localizer.text(.attempts)) {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                Stepper(value: $attempts, in: 1...5) {
                    Text("\(localizer.text(.attempts)): \(attempts)")
                        .font(.body.monospacedDigit())
                }
                .frame(maxWidth: 220, alignment: .leading)
                .help(localizer.text(.attemptsHelp))

                Stepper(value: $dnsTimeoutMS, in: 200...5_000, step: 100) {
                    Text("DNS timeout: \(dnsTimeoutMS) ms")
                        .font(.body.monospacedDigit())
                }
                .frame(maxWidth: 260, alignment: .leading)
                .help(localizer.text(.dnsTimeoutHelp))

                if mode == .connectionPathCompare {
                    Stepper(value: $connectTimeoutMS, in: 200...5_000, step: 100) {
                        Text("TCP timeout: \(connectTimeoutMS) ms")
                            .font(.body.monospacedDigit())
                    }
                    .frame(maxWidth: 260, alignment: .leading)
                    .help(localizer.text(.tcpTimeoutHelp))

                    Stepper(value: $maxConnectTargetsPerDomain, in: 1...8) {
                        Text("TCP targets/domain: \(maxConnectTargetsPerDomain)")
                            .font(.body.monospacedDigit())
                    }
                    .frame(maxWidth: 260, alignment: .leading)
                    .help(localizer.text(.tcpTargetsHelp))
                }
            }
        }
    }

    private var benchmarkRunLabel: String {
        switch runStateMachine.state {
        case .running, .cancelling:
            localizer.text(.running)
        case .idle, .completed, .cancelled, .failed:
            localizer.text(.run)
        }
    }

    private var profileSelectionSummary: String {
        switch setupViewModel.profileSelectionState {
        case .systemDNS:
            localizer.text(.systemDNSProfilesIgnored)
        case .noRunnableProfiles:
            localizer.text(.noRunnableProfiles)
        case .selectedRunnableProfiles(let selected, let runnable):
            String(
                format: localizer.text(.runnableProfilesSelected),
                selected,
                runnable
            )
        }
    }

    private func modeLabel(_ value: BenchmarkPlanMode) -> String {
        switch value {
        case .dnsOnlyCompare:
            localizer.text(.modeDNSOnly)
        case .connectionPathCompare:
            localizer.text(.modeDNSTCP)
        case .systemDNSValidation:
            localizer.text(.modeSystemDNS)
        }
    }

    private func modeHelp(_ value: BenchmarkPlanMode) -> String {
        switch value {
        case .dnsOnlyCompare:
            localizer.text(.modeDNSOnlyHelp)
        case .connectionPathCompare:
            localizer.text(.modeDNSTCPHelp)
        case .systemDNSValidation:
            localizer.text(.modeSystemDNSHelp)
        }
    }

    private func resolverTransportLabel(_ value: BenchmarkResolverTransport) -> String {
        switch value {
        case .automatic:
            localizer.text(.recordAuto)
        case .ipv4Only:
            localizer.text(.recordIPv4)
        case .ipv6Only:
            localizer.text(.recordIPv6)
        }
    }

    private func resolverTransportHelp(_ value: BenchmarkResolverTransport) -> String {
        switch value {
        case .automatic:
            localizer.text(.resolverAutoHelp)
        case .ipv4Only:
            localizer.text(.resolverIPv4Help)
        case .ipv6Only:
            localizer.text(.resolverIPv6Help)
        }
    }

    private func recordFamilyLabel(_ value: BenchmarkRecordFamily) -> String {
        switch value {
        case .both:
            localizer.text(.recordAAndAAAA)
        case .ipv4Only:
            localizer.text(.recordAOnly)
        case .ipv6Only:
            localizer.text(.recordAAAAOnly)
        }
    }

    private func recordFamilyHelp(_ value: BenchmarkRecordFamily) -> String {
        switch value {
        case .both:
            localizer.text(.recordAAndAAAAHelp)
        case .ipv4Only:
            localizer.text(.recordAOnlyHelp)
        case .ipv6Only:
            localizer.text(.recordAAAAOnlyHelp)
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
        editingSuiteID == nil ? localizer.text(.saveSuite) : localizer.text(.updateSuite)
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

    private func handleSystemDNSValidationRequest(_ requestID: Int) {
        guard requestID > handledSystemDNSValidationRequestID else {
            return
        }
        handledSystemDNSValidationRequestID = requestID
        guard !isBenchmarkActive, !isMutatingSuite else {
            return
        }
        applySystemDNSValidationPreset()
        runBenchmark()
    }

    private func handleBenchmarkCancellationRequest(_ requestID: Int) {
        guard requestID > handledBenchmarkCancellationRequestID else {
            return
        }
        handledBenchmarkCancellationRequestID = requestID
        cancelBenchmark()
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

    private func applySystemDNSValidationPreset() {
        editingSuiteID = nil
        suiteNameText = ""
        suiteSaveState = .idle
        suitePendingDelete = nil
        isDeleteSuiteConfirmationPresented = false
        selectedProfileIDs = []
        selectedSuiteID = nil
        customDomainsText = [
            "github.com",
            "login.microsoftonline.com",
            "vnexpress.net",
        ].joined(separator: "\n")
        attempts = 1
        dnsTimeoutMS = 800
        recordFamily = .both
        resolverTransport = .automatic
        mode = .systemDNSValidation
        refreshSystemDNSResolverSnapshot()
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
        onGuidedApplyPlanChanged(nil)
        outcome = nil
        applyPlanOutcome = nil
        isLoadingApplyPlan = false
        currentApplyPlanRunID = nil
        currentDNSBeforeApplySnapshot = .unavailable
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
                    if case .completed(let resultViewModel) = nextOutcome,
                       plan.mode != .systemDNSValidation {
                        loadApplyPlan(for: resultViewModel, executableURL: executableURL, runID: runID)
                    } else {
                        applyPlanOutcome = nil
                        isLoadingApplyPlan = false
                        currentApplyPlanRunID = nil
                    }
                default:
                    break
                }
            }
        }
    }

    private func loadApplyPlan(
        for resultViewModel: BenchmarkResultViewModel,
        executableURL: URL,
        runID: BenchmarkRunID
    ) {
        let databaseURL = makePreparedHistoryPersistenceFactory()?.databaseURL
        let vpnActive = vpnActive
        let mdmProfileActive = mdmProfileActive
        let corporateDNSDetected = corporateDNSDetected
        let captivePortalDetected = captivePortalDetected
        applyPlanOutcome = nil
        isLoadingApplyPlan = true
        currentApplyPlanRunID = runID
        let currentDNSBeforeApply = loadCurrentSystemDNSResolverSnapshot()
        currentDNSBeforeApplySnapshot = currentDNSBeforeApply

        DispatchQueue.global(qos: .userInitiated).async {
            let coordinator = BenchmarkApplyPlanLoadCoordinator(
                runner: ApplyPlanRunner(executableURL: executableURL)
            )
            let loadedOutcome = coordinator.load(
                for: resultViewModel,
                profileDatabaseURL: databaseURL,
                vpnActive: vpnActive,
                mdmProfileActive: mdmProfileActive,
                corporateDNSDetected: corporateDNSDetected,
                captivePortalDetected: captivePortalDetected
            )

            DispatchQueue.main.async {
                guard currentApplyPlanRunID == runID else {
                    return
                }
                isLoadingApplyPlan = false
                applyPlanOutcome = loadedOutcome
                switch loadedOutcome {
                case .loaded(let viewModel):
                    onGuidedApplyPlanChanged(
                        GuidedApplyPlanSnapshot.make(
                            from: viewModel,
                            currentDNSBeforeApply: currentDNSBeforeApply
                        )
                    )
                case .failed:
                    onGuidedApplyPlanChanged(nil)
                }
            }
        }
    }

    private func reloadApplyPlanForCurrentResult() {
        guard !isBenchmarkActive,
              let runID = currentApplyPlanRunID,
              case .completed(let resultViewModel) = outcome,
              case .ready(let executableURL) = executableAvailability else {
            return
        }
        loadApplyPlan(for: resultViewModel, executableURL: executableURL, runID: runID)
    }

    private func cancelBenchmark() {
        if case .running(let runID) = runStateMachine.state {
            runStateMachine.requestCancel(runID: runID)
            currentCancellation?.cancel()
        }
    }

    private func startSystemDNSValidationBenchmark() {
        guard !isBenchmarkActive else {
            return
        }
        mode = .systemDNSValidation
        refreshSystemDNSResolverSnapshot()
        DispatchQueue.main.async {
            runBenchmark()
        }
    }

    private func refreshSystemDNSResolverSnapshot() {
        systemDNSResolverSnapshot = loadCurrentSystemDNSResolverSnapshot()
    }

    private func makeHistoryPersistence(for plan: BenchmarkPlanViewModel) -> BenchmarkHistoryPersistence? {
        guard plan.supportsHistoryPersistence else {
            return nil
        }
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

private struct BenchmarkOptionsDisclosure<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let showHint: String
    let hideHint: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? hideHint : showHint)

            if isExpanded {
                content
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

private struct SystemDNSResolverStatusView: View {
    let viewModel: SystemDNSResolverViewModel
    let localizer: DNSPilotLocalizer
    let isRefreshDisabled: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            Label(viewModel.resolverLabel, systemImage: "desktopcomputer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .help(localizer.text(.systemDNSResolverHelp))

            ForEach(viewModel.detailLines, id: \.self) { line in
                Label(line, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                Button(action: onRefresh) {
                    Label(localizer.text(.refreshCurrentDNS), systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshDisabled)
                .help("Refresh the current macOS DNS resolver summary.")

                Button {
                    copyToPasteboard(viewModel.copyText)
                } label: {
                    Label(localizer.text(.copyCurrentDNS), systemImage: "doc.on.doc")
                }
                .help("Copy the current macOS DNS resolver summary.")
            }
        }
    }
}

private struct BenchmarkProgressPanel: View {
    let viewModel: BenchmarkProgressViewModel
    let localizer: DNSPilotLocalizer
    let startedAt: Date?
    let completedElapsedMS: Int?

    var body: some View {
        BenchmarkSection(title: localizer.text(.process)) {
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
                        Text(localizer.text(.status))
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
    let localizer: DNSPilotLocalizer
    let elapsedMS: Int?

    var body: some View {
        BenchmarkSection(title: localizer.text(.benchmarkFailed)) {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                BenchmarkFailureRow(label: localizer.text(.mode), value: mode.displayLabel)
                BenchmarkFailureRow(label: localizer.text(.failedAt), value: failure.failedStep.label)
                BenchmarkFailureRow(label: localizer.text(.reason), value: failure.message)
                BenchmarkFailureRow(label: localizer.text(.suggestion), value: failure.suggestion)
                if let elapsedMS {
                    BenchmarkFailureRow(label: localizer.text(.elapsed), value: "\(elapsedMS) ms")
                }

                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                    HStack {
                        Text(localizer.text(.debugLog))
                            .font(.headline)
                        Spacer()
                        Button(action: copyIssueLog) {
                            Label(localizer.text(.copyIssueReport), systemImage: "doc.on.doc")
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

private func loadCurrentSystemDNSResolverSnapshot(now: Date = Date()) -> SystemDNSResolverSnapshot {
    guard let store = SCDynamicStoreCreate(nil, "DNSPilot" as CFString, nil, nil) else {
        return .unavailable
    }

    let globalDNS = SCDynamicStoreCopyValue(
        store,
        "State:/Network/Global/DNS" as CFString
    ) as? [String: Any]
    let scopedKeys = SCDynamicStoreCopyKeyList(
        store,
        "State:/Network/Service/.*/DNS" as CFString
    ) as? [String] ?? []

    return SystemDNSResolverSnapshot(
        servers: uniqueStrings(stringArray(from: globalDNS?["ServerAddresses"])),
        searchDomains: uniqueStrings(stringArray(from: globalDNS?["SearchDomains"])),
        supplementalResolverCount: scopedKeys.count,
        loadedAt: now
    )
}

private func stringArray(from value: Any?) -> [String] {
    if let strings = value as? [String] {
        return strings
    }
    if let values = value as? [Any] {
        return values.compactMap { $0 as? String }
    }
    return []
}

private func uniqueStrings(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
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
    let applyPlanOutcome: BenchmarkApplyPlanLoadOutcome?
    let isLoadingApplyPlan: Bool
    let currentDNSBeforeApplySnapshot: SystemDNSResolverSnapshot
    let localizer: DNSPilotLocalizer
    let onStartSystemDNSValidation: () -> Void

    private var applyPlanPresentation: BenchmarkApplyPlanPresentation {
        BenchmarkApplyPlanPresentation(
            outcome: applyPlanOutcome,
            isLoading: isLoadingApplyPlan
        )
    }

    private var nextStepViewModel: BenchmarkResultNextStepViewModel {
        BenchmarkResultNextStepViewModel(result: viewModel)
    }

    var body: some View {
        BenchmarkSection(title: localizer.text(.result)) {
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

                    Spacer(minLength: DNSPilotDesign.Spacing.panel)

                    Menu {
                        Button {
                            copyToPasteboard(resultReportText)
                        } label: {
                            Label(localizer.text(.copyResultReport), systemImage: "doc.on.doc")
                        }

                        if let fullSavedHistoryID = viewModel.fullSavedHistoryID {
                            Button {
                                copyToPasteboard(fullSavedHistoryID)
                            } label: {
                                Label(localizer.text(.copyRunID), systemImage: "number")
                            }
                        }
                    } label: {
                        Label("More result actions", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                    }
                    .menuStyle(.borderlessButton)
                    .accessibilityIdentifier("benchmark-result-actions-menu")
                    .help("Copy result report or saved run ID")
                }
                .foregroundStyle(.secondary)

                Text(viewModel.recommendationLabel)
                    .font(.title3.weight(.semibold))

                if applyPlanPresentation.showsLocalNextStep {
                    BenchmarkResultNextStepPanel(
                        viewModel: nextStepViewModel
                    )
                }

                if applyPlanPresentation.showsApplyPlanState {
                    BenchmarkApplyPlanStatusPanel(
                        outcome: applyPlanOutcome,
                        isLoading: isLoadingApplyPlan,
                        currentDNSBeforeApplySnapshot: currentDNSBeforeApplySnapshot
                    )
                }

                if nextStepViewModel.canValidateSystemDNSAfterApply {
                    Button(action: onStartSystemDNSValidation) {
                        Label(localizer.text(.validateSystemDNS), systemImage: "checkmark.seal")
                    }
                    .accessibilityIdentifier("benchmark-validate-system-dns-button")
                    .help("After manual DNS apply and cache flush, run System DNS validation against the current macOS resolver.")
                }

                if let savedHistoryLabel = viewModel.savedHistoryLabel {
                    Label(savedHistoryLabel, systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: DNSPilotDesign.Spacing.panel, verticalSpacing: DNSPilotDesign.Spacing.row) {
                        GridRow {
                            Text(localizer.text(.status)).font(.headline)
                            Text(localizer.text(.profile)).font(.headline)
                            Text(localizer.text(.resolver)).font(.headline)
                            Text(localizer.text(.medianDNS)).font(.headline)
                            Text(localizer.text(.p95DNS)).font(.headline)
                            if viewModel.showsConnectionMetrics {
                                Text(localizer.text(.medianTCP)).font(.headline)
                            }
                            Text(localizer.text(.failure)).font(.headline)
                            Text(localizer.text(.diagnosis)).font(.headline)
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

                if !viewModel.notes.isEmpty || !viewModel.warning.isEmpty {
                    DisclosureGroup("Why this result") {
                        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                            Label(viewModel.fastestObservedLabel, systemImage: "bolt")
                            Label(viewModel.balancedRecommendationLabel, systemImage: "scale.3d")

                            ForEach(viewModel.notes, id: \.self) { note in
                                Label(note, systemImage: "info.circle")
                            }

                            if !viewModel.warning.isEmpty {
                                Text(viewModel.warning)
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
                        .padding(.top, DNSPilotDesign.Spacing.controlGap)
                    }
                }
            }
        }
    }

    private var resultReportText: String {
        BenchmarkApplyPlanReportFormatter.appendApplyPlan(
            outcome: applyPlanOutcome,
            isLoading: isLoadingApplyPlan,
            restoreSnapshot: currentDNSBeforeApplySnapshot,
            to: viewModel.resultReportText(
                elapsedMS: elapsedMS,
                includeNextStep: applyPlanPresentation.reportIncludesLocalNextStep
            )
        )
    }
}

private struct BenchmarkApplyPlanStatusPanel: View {
    let outcome: BenchmarkApplyPlanLoadOutcome?
    let isLoading: Bool
    let currentDNSBeforeApplySnapshot: SystemDNSResolverSnapshot
    @AppStorage(MacOSPowerDNSActionConfiguration.userDefaultsKey) private var userEnabledPowerActions = false
    @State private var pendingGuidedApplyConfirmation: PendingGuidedApplyConfirmation?

    private var isDirectAdminEnabled: Bool {
        MacOSPowerDNSActionConfiguration.isEnabled(userDefaultValue: userEnabledPowerActions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            Divider()

            if isLoading {
                Label("Preparing apply action", systemImage: "hourglass")
                    .font(.headline)
            } else {
                switch outcome {
                case .loaded(let viewModel):
                    applyPlanContent(
                        viewModel,
                        restoreViewModel: GuidedApplyRestoreViewModel(snapshot: currentDNSBeforeApplySnapshot)
                    )
                case .failed(let message):
                    Label("Apply policy unavailable", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                        .foregroundStyle(DNSPilotDesign.Palette.warning)
                    HStack {
                        Text("Use the result only; retest before changing DNS.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            copyToPasteboard(message)
                        } label: {
                            Label("Copy apply error", systemImage: "doc.on.doc")
                                .labelStyle(.iconOnly)
                        }
                        .help("Copy apply policy error")
                    }
                case nil:
                    EmptyView()
                }
            }
        }
        .storeSafeGuidedApplyConfirmation(pending: $pendingGuidedApplyConfirmation)
    }

    @ViewBuilder
    private func applyPlanContent(
        _ viewModel: ApplyPlanViewModel,
        restoreViewModel: GuidedApplyRestoreViewModel
    ) -> some View {
        Label(viewModel.recommendedProfileLabel ?? "DNS action: \(viewModel.statusLabel)", systemImage: viewModel.canOfferPrimaryAction ? "checkmark.shield" : "shield")
            .font(.headline)

        Label(viewModel.actionLabel, systemImage: applyPlanActionImage(for: viewModel.plan.disposition))
            .foregroundStyle(.secondary)

        HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
            if isDirectAdminEnabled, viewModel.canOfferPrimaryAction, !viewModel.plan.dnsServers.isEmpty {
                PowerDNSApplyButton(
                    profileName: viewModel.plan.profileName ?? viewModel.plan.profileID,
                    dnsServers: viewModel.plan.dnsServers
                )
            } else if let primaryActionLabel = viewModel.guidedPrimaryActionLabel,
                      let primaryCopyText = viewModel.guidedPrimaryActionCopyText {
                Button {
                    pendingGuidedApplyConfirmation = PendingGuidedApplyConfirmation(
                        copyText: primaryCopyText,
                        opensNetworkSettings: viewModel.opensNetworkSettingsAfterGuidedPrimaryAction,
                        confirmation: StoreSafeDNSActionConfirmationViewModel.guidedApply(
                            profileName: viewModel.plan.profileName ?? viewModel.plan.profileID,
                            dnsServers: viewModel.plan.dnsServers,
                            hasRestoreDNS: restoreViewModel.hasRestorableDNS
                        )
                    )
                } label: {
                    Label(primaryActionLabel, systemImage: "gearshape")
                }
                .accessibilityIdentifier("benchmark-guided-apply-button")
                .help("Copy measured DNS servers, then open macOS Network Settings for manual apply.")
            }

            Menu {
                if !viewModel.dnsServerText.isEmpty {
                    Button("Copy DNS Servers") {
                        copyToPasteboard(viewModel.dnsServerText)
                    }
                }
                if let guidedApplyChecklistText = viewModel.guidedApplyChecklistText {
                    Button("Copy Apply Checklist") {
                        copyToPasteboard(
                            viewModel.guidedApplyChecklistTextWithRestore(currentDNSBeforeApplySnapshot)
                                ?? guidedApplyChecklistText
                        )
                    }
                }
                if viewModel.guidedPrimaryActionLabel != nil {
                    Button("Copy Restore DNS") {
                        copyToPasteboard(restoreViewModel.copyText)
                    }
                }
                Divider()
                Button("Copy Apply Plan") {
                    copyToPasteboard(viewModel.copyText)
                }
            } label: {
                Label("More apply actions", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .accessibilityIdentifier("benchmark-apply-actions-menu")
            .help("Copy DNS, apply checklist, restore data, or plan")
        }

        DisclosureGroup("Details") {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                if let testedResolver = viewModel.plan.testedResolver {
                    Label("Tested resolver: \(testedResolver)", systemImage: "scope")
                }
                if !viewModel.dnsServerText.isEmpty {
                    Label("DNS servers", systemImage: "server.rack")
                        .font(.subheadline.weight(.semibold))
                    ForEach(viewModel.plan.dnsServers, id: \.self) { server in
                        Text(server)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }
                }
                if viewModel.guidedPrimaryActionLabel != nil {
                    Label(restoreViewModel.statusLabel, systemImage: restoreViewModel.hasRestorableDNS ? "arrow.uturn.backward.circle" : "exclamationmark.triangle")
                    ForEach(restoreViewModel.detailLines, id: \.self) { line in
                        Text(line)
                    }
                }
                ForEach(viewModel.plan.notes, id: \.self) { note in
                    Label(note, systemImage: "info.circle")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, DNSPilotDesign.Spacing.controlGap)
        }
    }

    private func applyPlanActionImage(for disposition: DNSPilotApplyPlanDisposition) -> String {
        switch disposition {
        case .applyWithUserApproval:
            "person.crop.circle.badge.checkmark"
        case .guideOnly:
            "gearshape"
        case .protectCurrentDNS:
            "lock.shield"
        case .unsupported:
            "nosign"
        case .notRecommended:
            "arrow.triangle.2.circlepath"
        }
    }
}

private struct BenchmarkResultNextStepPanel: View {
    let viewModel: BenchmarkResultNextStepViewModel
    @AppStorage(MacOSPowerDNSActionConfiguration.userDefaultsKey) private var userEnabledPowerActions = false
    @State private var pendingGuidedApplyConfirmation: PendingGuidedApplyConfirmation?

    private var isDirectAdminEnabled: Bool {
        MacOSPowerDNSActionConfiguration.isEnabled(userDefaultValue: userEnabledPowerActions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            Divider()

            Label(viewModel.title, systemImage: viewModel.canOpenNetworkSettings ? "gearshape" : "shield")
                .font(.headline)

            if let firstLine = viewModel.lines.first {
                Text(firstLine)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                if let dnsSettings = viewModel.dnsSettings, dnsSettings.hasServers, isDirectAdminEnabled {
                    PowerDNSApplyButton(
                        profileName: dnsSettings.profileName,
                        dnsServers: dnsSettings.allServers
                    )
                } else if viewModel.canOpenNetworkSettings {
                    Button {
                        if let dnsSettings = viewModel.dnsSettings, dnsSettings.hasServers {
                            pendingGuidedApplyConfirmation = PendingGuidedApplyConfirmation(
                                copyText: dnsSettings.serverListText,
                                opensNetworkSettings: true,
                                confirmation: StoreSafeDNSActionConfirmationViewModel.guidedApply(
                                    profileName: dnsSettings.profileName,
                                    dnsServers: dnsSettings.allServers,
                                    hasRestoreDNS: false
                                )
                            )
                        } else {
                            openNetworkSettings()
                        }
                    } label: {
                        Label(viewModel.actionLabel, systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("benchmark-open-network-settings-button")
                    .help("Copy DNS servers, then open macOS Network Settings for manual apply.")
                }

                Menu {
                    if let dnsSettings = viewModel.dnsSettings, dnsSettings.hasServers {
                        Button("Copy DNS Servers") {
                            copyToPasteboard(dnsSettings.serverListText)
                        }
                    }
                    if let manualApplyChecklistText = viewModel.manualApplyChecklistText {
                        Button("Copy Apply Checklist") {
                            copyToPasteboard(manualApplyChecklistText)
                        }
                    }
                    Button("Copy Next Step") {
                        copyToPasteboard(viewModel.copyText)
                    }
                } label: {
                    Label("More next-step actions", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("benchmark-next-step-actions-menu")
                .help("Copy DNS servers, apply checklist, or next-step guidance")
            }

            DisclosureGroup("Details") {
                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                    ForEach(viewModel.lines.dropFirst(), id: \.self) { line in
                        Label(line, systemImage: "info.circle")
                    }

                    if let dnsSettings = viewModel.dnsSettings {
                        Label("DNS servers: \(dnsSettings.profileName)", systemImage: "server.rack")
                            .font(.subheadline.weight(.semibold))
                        ForEach(dnsSettings.displayLines, id: \.self) { line in
                            Text(line)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, DNSPilotDesign.Spacing.controlGap)
            }
        }
        .storeSafeGuidedApplyConfirmation(pending: $pendingGuidedApplyConfirmation)
    }
}

private struct HistoryResultPanel: View {
    let viewModel: BenchmarkHistoryViewModel
    let isDisabled: Bool
    let localizer: DNSPilotLocalizer
    let onDelete: (BenchmarkHistoryRow) -> Void

    var body: some View {
        BenchmarkSection(title: localizer.text(.savedRuns)) {
            if viewModel.rows.isEmpty {
                Label(localizer.text(.noSavedRuns), systemImage: "tray")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                    ForEach(viewModel.rows) { row in
                        HistoryRowView(
                            row: row,
                            isDisabled: isDisabled,
                            localizer: localizer,
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
    let localizer: DNSPilotLocalizer
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
                Text(row.applyGuidanceLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Label(localizer.text(.copyRunID), systemImage: "doc.on.doc")
            }
            .labelStyle(.iconOnly)
            .help("Copy saved run ID")
            Button(role: .destructive, action: onDelete) {
                Label(localizer.text(.delete), systemImage: "trash")
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
    let onApply: () -> Void

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
                if summary.canGuideApply {
                    Button(action: onApply) {
                        Label(summary.guidedApplyButtonLabel, systemImage: "gearshape")
                    }
                    .help("Confirm, copy DNS servers, and open macOS Network Settings. DNS Pilot will not change system DNS automatically.")

                    PowerDNSApplyButton(
                        profileName: summary.name,
                        dnsServers: summary.dnsServers
                    )
                }
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

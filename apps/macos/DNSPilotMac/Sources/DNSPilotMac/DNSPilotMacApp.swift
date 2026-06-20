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
        WindowGroup("DNS Pilot", id: DNSPilotWindowID.main) {
            DNSPilotShellView(navigation: navigation)
                .frame(minWidth: 900, minHeight: 620)
        }

        MenuBarExtra("DNS Pilot", systemImage: "network") {
            DNSPilotMenuBarView(navigation: navigation)
        }

        Settings {
            DNSPilotSettingsView()
        }
    }
}

private enum DNSPilotWindowID {
    static let main = "main"
}

private struct DNSPilotSettingsView: View {
    @AppStorage(DNSPilotLanguagePreferences.storageKey) private var languageCode = DNSPilotLanguage.system.rawValue

    private var localizer: DNSPilotLocalizer {
        DNSPilotLocalizer(languageCode: languageCode)
    }

    var body: some View {
        Form {
            Section {
                Picker(localizer.text(.language), selection: $languageCode) {
                    ForEach(DNSPilotLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language.rawValue)
                    }
                }
                Text(localizer.text(.languageSubtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(localizer.text(.settingsTitle))
            }

            Section {
                Label(powerActionsLabel, systemImage: MacOSPowerDNSActionConfiguration.isEnabled() ? "bolt.shield" : "lock.shield")
                    .foregroundStyle(.secondary)
            } header: {
                Text(localizer.text(.powerActions))
            }
        }
        .formStyle(.grouped)
        .padding(DNSPilotDesign.Spacing.panel)
        .frame(width: 460)
    }

    private var powerActionsLabel: String {
        MacOSPowerDNSActionConfiguration.isEnabled()
            ? localizer.text(.powerActionsEnabled)
            : localizer.text(.powerActionsDisabled)
    }
}

private enum SidebarSelection: Hashable {
    case capabilities
    case permissions
    case publish
    case benchmark
    case gamePing
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
    private let powerActionViewModel = MacOSPowerDNSActionViewModel(
        isEnabled: MacOSPowerDNSActionConfiguration.isEnabled()
    )
    @State private var powerActionAlert: PowerDNSActionAlert?
    @State private var isRunningPowerFlush = false

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
    private let powerActionViewModel = MacOSPowerDNSActionViewModel(
        isEnabled: MacOSPowerDNSActionConfiguration.isEnabled()
    )
    @State private var isShowingConfirmation = false
    @State private var isRunningApply = false
    @State private var powerActionAlert: PowerDNSActionAlert?

    var body: some View {
        if let applyButtonLabel = powerActionViewModel.applyButtonLabel, !dnsServers.isEmpty {
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
            .disabled(isRunningApply)
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
            .alert(item: $powerActionAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .help("Ask macOS for administrator approval and apply these DNS servers to the active network service.")
        }
    }

    private func runPowerApply() {
        let servers = dnsServers
        isRunningApply = true
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> (Bool, String) in
                do {
                    try MacOSPowerDNSActionRunner.fromEnvironment().applyDNS(servers: servers)
                    return (true, "DNS was applied and local DNS cache was flushed.")
                } catch {
                    return (false, error.localizedDescription)
                }
            }.value

            isRunningApply = false
            if result.0 {
                powerActionAlert = PowerDNSActionAlert(title: "DNS apply complete", message: result.1)
            } else {
                powerActionAlert = PowerDNSActionAlert(title: "DNS apply failed", message: result.1)
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

@MainActor
private final class DNSPilotNavigationModel: ObservableObject {
    @Published var selection: SidebarSelection? = .capabilities
    @Published var quickBenchmarkRequestID = 0
    @Published var systemDNSValidationRequestID = 0
    @Published var lastGuidedApplyPlan: GuidedApplyPlanSnapshot?
    @Published var pendingGuidedApplyPlanConfirmation: GuidedApplyPlanSnapshot?
    @Published var isShowingFlushDNSConfirmation = false

    private let guidedApplyPlanStore: GuidedApplyPlanStore

    init(guidedApplyPlanStore: GuidedApplyPlanStore = GuidedApplyPlanStore()) {
        self.guidedApplyPlanStore = guidedApplyPlanStore
        lastGuidedApplyPlan = guidedApplyPlanStore.load()
    }

    func requestQuickBenchmark() {
        selection = .benchmark
        quickBenchmarkRequestID += 1
    }

    func requestSystemDNSValidation() {
        selection = .benchmark
        systemDNSValidationRequestID += 1
    }

    func setLastGuidedApplyPlan(_ snapshot: GuidedApplyPlanSnapshot?) {
        lastGuidedApplyPlan = snapshot
        if let snapshot {
            guidedApplyPlanStore.save(snapshot)
        } else {
            guidedApplyPlanStore.clear()
        }
    }

    func requestGuidedApplyConfirmation(_ snapshot: GuidedApplyPlanSnapshot) {
        pendingGuidedApplyPlanConfirmation = snapshot
    }

    func clearGuidedApplyConfirmation() {
        pendingGuidedApplyPlanConfirmation = nil
    }

    func requestFlushDNSConfirmation() {
        isShowingFlushDNSConfirmation = true
    }
}

private struct DNSPilotMenuBarView: View {
    @ObservedObject var navigation: DNSPilotNavigationModel
    @Environment(\.openWindow) private var openWindow

    private var viewModel: MenuBarQuickActionsViewModel {
        MenuBarQuickActionsViewModel(lastGuidedApplyPlan: navigation.lastGuidedApplyPlan)
    }

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
        case .guidedApplyLastDNS:
            guard let plan = navigation.lastGuidedApplyPlan else {
                return
            }
            navigation.requestGuidedApplyConfirmation(plan)
            navigation.selection = .benchmark
        case .flushDNS:
            navigation.requestFlushDNSConfirmation()
            navigation.selection = .benchmark
        case .copyLastDNS:
            guard let plan = navigation.lastGuidedApplyPlan else {
                return
            }
            copyToPasteboard(plan.dnsServerText)
            return
        case .systemDNSValidation:
            navigation.requestSystemDNSValidation()
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
    @AppStorage(DNSPilotLanguagePreferences.storageKey) private var languageCode = DNSPilotLanguage.system.rawValue
    @State private var catalogViewModel = CatalogViewModel()
    @State private var hasRequestedStorageCatalogRefresh = false

    private let capabilityViewModel = CapabilityMatrixViewModel()
    private var localizer: DNSPilotLocalizer {
        DNSPilotLocalizer(languageCode: languageCode)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $navigation.selection) {
                Section(localizer.text(.overview)) {
                    Label(localizer.text(.capabilities), systemImage: "checkmark.seal")
                        .tag(SidebarSelection.capabilities)
                    Label(localizer.text(.permissions), systemImage: "lock.shield")
                        .tag(SidebarSelection.permissions)
                    Label(localizer.text(.publish), systemImage: "shippingbox")
                        .tag(SidebarSelection.publish)
                    Label(localizer.text(.benchmark), systemImage: "speedometer")
                        .tag(SidebarSelection.benchmark)
                    Label(localizer.text(.gamePing), systemImage: "gamecontroller")
                        .tag(SidebarSelection.gamePing)
                    Label(localizer.text(.customDNS), systemImage: "plus.circle")
                        .tag(SidebarSelection.customDNS)
                    Label(localizer.text(.history), systemImage: "clock.arrow.circlepath")
                        .tag(SidebarSelection.history)
                    Label(localizer.text(.catalog), systemImage: "server.rack")
                        .tag(SidebarSelection.catalog)
                }

                Section(localizer.text(.platforms)) {
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
            case .permissions:
                PermissionReadinessDetailView(localizer: localizer)
            case .publish:
                PublishReadinessDetailView(localizer: localizer)
            case .benchmark:
                BenchmarkDetailHostView(
                    catalogViewModel: catalogViewModel,
                    quickBenchmarkRequestID: navigation.quickBenchmarkRequestID,
                    systemDNSValidationRequestID: navigation.systemDNSValidationRequestID,
                    onCatalogChanged: refreshCatalogFromStorage,
                    onGuidedApplyPlanChanged: navigation.setLastGuidedApplyPlan
                )
            case .gamePing:
                GamePingDetailHostView(catalogViewModel: catalogViewModel)
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

private struct GamePingDetailHostView: View {
    let catalogViewModel: CatalogViewModel

    var body: some View {
        if let loadErrorMessage = catalogViewModel.loadErrorMessage {
            BenchmarkUnavailableView(title: "Game Ping", message: loadErrorMessage)
        } else if let catalog = catalogViewModel.catalog {
            GamePingDetailView(
                catalog: catalog,
                executableAvailability: BenchmarkExecutableResolver().resolve()
            )
        } else {
            BenchmarkUnavailableView(title: "Game Ping", message: "Catalog unavailable.")
        }
    }
}

private struct GamePingDetailView: View {
    let catalog: CatalogSnapshot
    let executableAvailability: BenchmarkExecutableAvailability

    @State private var selectedPresetID: String
    @State private var selectedProfileIDs: Set<String>
    @State private var attempts = 1
    @State private var dnsTimeoutMS = 800
    @State private var connectTimeoutMS = 1_000
    @State private var runStateMachine = BenchmarkRunStateMachine()
    @State private var currentCancellation: BenchmarkRunCancellation?
    @State private var currentStartedAt: Date?
    @State private var currentProgressEvents: [BenchmarkProgressEvent] = []
    @State private var completedElapsedMS: Int?
    @State private var outcome: BenchmarkExecutionOutcome?

    init(catalog: CatalogSnapshot, executableAvailability: BenchmarkExecutableAvailability) {
        self.catalog = catalog
        self.executableAvailability = executableAvailability
        let defaultViewModel = GamePingPlanViewModel(catalog: catalog)
        _selectedPresetID = State(initialValue: defaultViewModel.selectedPresetID ?? "")
        _selectedProfileIDs = State(initialValue: Set(defaultViewModel.selectedProfileIDs))
    }

    private var plainProfiles: [CatalogProfile] {
        catalog.profiles.filter { $0.protocol == .plain }
    }

    private var selectedProfileIDList: [String] {
        plainProfiles.map(\.id).filter { selectedProfileIDs.contains($0) }
    }

    private var planViewModel: GamePingPlanViewModel {
        GamePingPlanViewModel(
            catalog: catalog,
            selectedPresetID: selectedPresetID.isEmpty ? nil : selectedPresetID,
            selectedProfileIDs: selectedProfileIDList,
            attempts: attempts,
            dnsTimeoutMS: dnsTimeoutMS,
            connectTimeoutMS: connectTimeoutMS
        )
    }

    private var isRunning: Bool {
        if case .running = runStateMachine.state {
            return true
        }
        if case .cancelling = runStateMachine.state {
            return true
        }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                HStack {
                    Text("Game Ping")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button(action: runGamePing) {
                        Label(isRunning ? "Running" : "Run", systemImage: "play.fill")
                    }
                    .disabled(!planViewModel.canRun || isRunning || !executableAvailability.isReady)

                    if isRunning {
                        Button(action: cancelGamePing) {
                            Label("Cancel", systemImage: "xmark.circle")
                        }
                    }
                }

                Label(planViewModel.warningText, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if case .unavailable(let message) = executableAvailability {
                    BenchmarkIssueList(issues: [message])
                }

                if !planViewModel.issues.isEmpty {
                    BenchmarkIssueList(issues: planViewModel.issues)
                }

                BenchmarkSection(title: "Preset") {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                        Picker("Game", selection: $selectedPresetID) {
                            ForEach(planViewModel.presetOptions) { option in
                                Text(option.name).tag(option.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 340, alignment: .leading)
                        .disabled(isRunning)

                        if let selectedPreset = planViewModel.selectedPreset {
                            Label(selectedPreset.description, systemImage: "gamecontroller")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(selectedPreset.domains.joined(separator: ", "))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                BenchmarkSection(title: "DNS Candidates") {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                        HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                            Button("All") {
                                selectedProfileIDs = Set(plainProfiles.map(\.id))
                            }
                            .disabled(isRunning)
                            Button("Vietnam") {
                                selectedProfileIDs = Set(
                                    plainProfiles
                                        .filter { $0.tags.contains("vietnam") || $0.tags.contains("isp") }
                                        .map(\.id)
                                )
                            }
                            .disabled(isRunning)
                            Button("Global") {
                                selectedProfileIDs = Set(["cloudflare", "google-public-dns", "quad9"])
                            }
                            .disabled(isRunning)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), alignment: .leading)], alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                            ForEach(plainProfiles) { profile in
                                Toggle(profile.name, isOn: Binding(
                                    get: { selectedProfileIDs.contains(profile.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedProfileIDs.insert(profile.id)
                                        } else {
                                            selectedProfileIDs.remove(profile.id)
                                        }
                                    }
                                ))
                                .disabled(isRunning)
                            }
                        }
                    }
                }

                BenchmarkSection(title: "Probe") {
                    HStack(spacing: DNSPilotDesign.Spacing.panel) {
                        Stepper("Attempts: \(attempts)", value: $attempts, in: 1...5)
                            .disabled(isRunning)
                        Stepper("DNS timeout: \(dnsTimeoutMS) ms", value: $dnsTimeoutMS, in: 200...3_000, step: 100)
                            .disabled(isRunning)
                        Stepper("TCP timeout: \(connectTimeoutMS) ms", value: $connectTimeoutMS, in: 300...5_000, step: 100)
                            .disabled(isRunning)
                    }
                }

                if isRunning || outcome != nil {
                    BenchmarkProgressPanel(
                        viewModel: BenchmarkProgressViewModel(
                            mode: .connectionPathCompare,
                            state: runStateMachine.state,
                            outcome: outcome,
                            historySaved: false,
                            planSummary: BenchmarkProgressPlanSummary(plan: planViewModel.plan),
                            progressEvents: currentProgressEvents
                        ),
                        startedAt: currentStartedAt,
                        completedElapsedMS: completedElapsedMS
                    )
                }

                if let outcome {
                    switch outcome {
                    case .completed(let result):
                        GamePingResultPanel(
                            viewModel: result,
                            elapsedMS: completedElapsedMS,
                            setupText: planViewModel.copyText
                        )
                    case .failed(let failure):
                        BenchmarkFailurePanel(
                            failure: failure,
                            mode: .connectionPathCompare,
                            elapsedMS: completedElapsedMS
                        )
                    }
                }
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
    }

    private func runGamePing() {
        guard planViewModel.canRun,
              case .ready(let executableURL) = executableAvailability else {
            return
        }
        let plan = planViewModel.plan
        let runID = runStateMachine.start()
        let cancellation = BenchmarkRunCancellation()
        currentCancellation = cancellation
        currentStartedAt = Date()
        currentProgressEvents = []
        completedElapsedMS = nil
        outcome = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let coordinator = BenchmarkExecutionCoordinator(
                runner: BenchmarkRunner(executableURL: executableURL),
                catalog: catalog
            )
            let startedAt = Date()
            let completedOutcome = coordinator.execute(
                plan: plan,
                cancellation: cancellation
            ) { event in
                DispatchQueue.main.async {
                    currentProgressEvents.append(event)
                }
            }
            let elapsedMS = Int(Date().timeIntervalSince(startedAt) * 1_000)

            DispatchQueue.main.async {
                if cancellation.isCancelled {
                    runStateMachine.finishCancelled(runID: runID)
                    outcome = .failed(
                        BenchmarkExecutionFailure(
                            message: "Game ping cancelled.",
                            failedStep: .measuringConnection,
                            debugLog: "Cancelled by user."
                        )
                    )
                } else {
                    switch completedOutcome {
                    case .completed:
                        runStateMachine.finishCompleted(runID: runID)
                    case .failed(let failure):
                        runStateMachine.finishFailed(runID: runID, message: failure.message)
                    }
                    outcome = completedOutcome
                }
                completedElapsedMS = elapsedMS
                currentStartedAt = nil
                currentCancellation = nil
            }
        }
    }

    private func cancelGamePing() {
        guard let currentCancellation else {
            return
        }
        if case .running(let runID) = runStateMachine.state {
            runStateMachine.requestCancel(runID: runID)
        }
        currentCancellation.cancel()
    }
}

private struct GamePingResultPanel: View {
    let viewModel: BenchmarkResultViewModel
    let elapsedMS: Int?
    let setupText: String

    var body: some View {
        BenchmarkSection(title: "Result") {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
                HStack(spacing: DNSPilotDesign.Spacing.panel) {
                    Label(viewModel.healthLabel, systemImage: "waveform.path.ecg")
                    Label(viewModel.scopeLabel, systemImage: "point.3.connected.trianglepath.dotted")
                    Label(viewModel.confidenceLabel, systemImage: "gauge.with.dots.needle.67percent")
                    if let elapsedMS {
                        Label("Completed in \(BenchmarkElapsedTimeFormatter.label(milliseconds: elapsedMS))", systemImage: "timer")
                    }
                }
                .foregroundStyle(.secondary)

                Text(viewModel.recommendationLabel)
                    .font(.title3.weight(.semibold))

                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                    Label(viewModel.fastestObservedLabel, systemImage: "bolt")
                    Label(viewModel.balancedRecommendationLabel, systemImage: "scale.3d")
                }
                .foregroundStyle(.secondary)

                ScrollView(.horizontal) {
                    Grid(alignment: .leading, horizontalSpacing: DNSPilotDesign.Spacing.panel, verticalSpacing: DNSPilotDesign.Spacing.row) {
                        GridRow {
                            Text("Status").font(.headline)
                            Text("Profile").font(.headline)
                            Text("Resolver").font(.headline)
                            Text("Median DNS").font(.headline)
                            Text("Median TCP").font(.headline)
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
                                Text(row.medianConnectLatencyLabel)
                                Text(row.failureRateLabel)
                                Text(row.diagnosisLabel)
                            }
                        }
                    }
                    .frame(minWidth: 900, alignment: .leading)
                }

                ForEach(viewModel.notes, id: \.self) { note in
                    Label(note, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }

                if !viewModel.warning.isEmpty {
                    Text(viewModel.warning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    copyToPasteboard(
                        [
                            setupText,
                            "",
                            viewModel.resultReportText(elapsedMS: elapsedMS, includeNextStep: false),
                        ].joined(separator: "\n")
                    )
                } label: {
                    Label("Copy Game Ping Report", systemImage: "doc.on.doc")
                }
            }
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
    private let productGoalReadiness = ProductGoalReadinessViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
                Text("Capability Matrix")
                    .font(.title2.weight(.semibold))

                ProductGoalReadinessSection(viewModel: productGoalReadiness)

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
            }
            .padding(DNSPilotDesign.Spacing.panel)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DNSPilotDesign.Palette.background)
    }
}

private struct ProductGoalReadinessSection: View {
    let viewModel: ProductGoalReadinessViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.row) {
            Text("Product Goals")
                .font(.headline)

            ForEach(viewModel.rows) { row in
                ProductGoalReadinessRowView(row: row)
            }
        }
    }
}

private struct ProductGoalReadinessRowView: View {
    let row: ProductGoalReadinessRow

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: DNSPilotDesign.Spacing.row, verticalSpacing: 2) {
            GridRow {
                Label(row.statusLabel, systemImage: row.systemImage)
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
    private let viewModel = MacOSPermissionReadinessViewModel(
        isPowerActionsEnabled: MacOSPowerDNSActionConfiguration.isEnabled()
    )

    var body: some View {
        MacOSReadinessDetailView(
            title: localizer.text(.permissions),
            subtitle: localizer.text(.permissionsSubtitle),
            rows: viewModel.rows,
            copyText: viewModel.copyText,
            primaryActionLabel: localizer.text(.openNetworkSettings),
            primaryActionSystemImage: "gearshape",
            primaryAction: openNetworkSettings,
            copyLabel: localizer.text(.copyChecklist)
        )
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
    @State private var pendingGuidedApplyConfirmation: PendingGuidedApplyConfirmation?

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
                            CatalogProfileRow(
                                summary: summary,
                                onApply: { requestGuidedApply(summary) }
                            )
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
    let quickBenchmarkRequestID: Int
    let systemDNSValidationRequestID: Int
    let onCatalogChanged: () -> Void
    let onGuidedApplyPlanChanged: (GuidedApplyPlanSnapshot?) -> Void

    var body: some View {
        if let loadErrorMessage = catalogViewModel.loadErrorMessage {
            BenchmarkUnavailableView(message: loadErrorMessage)
        } else if let catalog = catalogViewModel.catalog {
            BenchmarkDetailView(
                catalog: catalog,
                executableAvailability: BenchmarkExecutableResolver().resolve(),
                quickBenchmarkRequestID: quickBenchmarkRequestID,
                systemDNSValidationRequestID: systemDNSValidationRequestID,
                onCatalogChanged: onCatalogChanged,
                onGuidedApplyPlanChanged: onGuidedApplyPlanChanged
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
    let systemDNSValidationRequestID: Int
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
        systemDNSValidationRequestID: Int,
        onCatalogChanged: @escaping () -> Void,
        onGuidedApplyPlanChanged: @escaping (GuidedApplyPlanSnapshot?) -> Void
    ) {
        self.catalog = catalog
        self.executableAvailability = executableAvailability
        self.quickBenchmarkRequestID = quickBenchmarkRequestID
        self.systemDNSValidationRequestID = systemDNSValidationRequestID
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
                            elapsedMS: lastBenchmarkElapsedMS,
                            applyPlanOutcome: applyPlanOutcome,
                            isLoadingApplyPlan: isLoadingApplyPlan,
                            currentDNSBeforeApplySnapshot: currentDNSBeforeApplySnapshot,
                            onStartSystemDNSValidation: startSystemDNSValidationBenchmark
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
                        Text(BenchmarkPlanMode.systemDNSValidation.displayLabel)
                            .help(BenchmarkPlanMode.systemDNSValidation.helpText)
                            .tag(BenchmarkPlanMode.systemDNSValidation)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 420, alignment: .leading)
                    .help(mode.helpText)

                    if mode == .systemDNSValidation {
                        SystemDNSResolverStatusView(
                            viewModel: SystemDNSResolverViewModel(snapshot: systemDNSResolverSnapshot),
                            isRefreshDisabled: isBenchmarkActive,
                            onRefresh: refreshSystemDNSResolverSnapshot
                        )
                    } else {
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
                    }

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

                BenchmarkSection(title: "Network Safeguards") {
                    VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                        Toggle("VPN active", isOn: $vpnActive)
                            .disabled(isBenchmarkActive)
                            .help("Protect current DNS when a VPN may own routing or DNS.")
                        Toggle("MDM managed", isOn: $mdmProfileActive)
                            .disabled(isBenchmarkActive)
                            .help("Protect current DNS when this Mac may be managed by an organization.")
                        Toggle("Corporate DNS required", isOn: $corporateDNSDetected)
                            .disabled(isBenchmarkActive)
                            .help("Protect current DNS when internal domains may require company DNS.")
                        Toggle("Captive portal", isOn: $captivePortalDetected)
                            .disabled(isBenchmarkActive)
                            .help("Protect current DNS while a hotel, airport, or guest Wi-Fi login may be active.")

                        Label(
                            "Enabled safeguards affect apply policy only; benchmark measurements still run.",
                            systemImage: "shield"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                BenchmarkSection(title: "Profiles") {
                    if mode == .systemDNSValidation {
                        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                            Label("System DNS uses the current macOS resolver; selected profiles are ignored.", systemImage: "desktopcomputer")
                                .font(.body.weight(.semibold))
                            Label("Use this after manually changing DNS to validate the active OS resolver path.", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
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
        .onChange(of: vpnActive) { _, _ in reloadApplyPlanForCurrentResult() }
        .onChange(of: mdmProfileActive) { _, _ in reloadApplyPlanForCurrentResult() }
        .onChange(of: corporateDNSDetected) { _, _ in reloadApplyPlanForCurrentResult() }
        .onChange(of: captivePortalDetected) { _, _ in reloadApplyPlanForCurrentResult() }
        .onChange(of: mode) { _, nextMode in
            if nextMode == .systemDNSValidation {
                refreshSystemDNSResolverSnapshot()
            }
        }
        .onChange(of: quickBenchmarkRequestID) { _, requestID in
            handleQuickBenchmarkRequest(requestID)
        }
        .onChange(of: systemDNSValidationRequestID) { _, requestID in
            handleSystemDNSValidationRequest(requestID)
        }
        .onAppear {
            if mode == .systemDNSValidation {
                refreshSystemDNSResolverSnapshot()
            }
            handleQuickBenchmarkRequest(quickBenchmarkRequestID)
            handleSystemDNSValidationRequest(systemDNSValidationRequestID)
        }
        .storeSafeFlushConfirmation(isPresented: $isShowingFlushDNSConfirmation)
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
    let isRefreshDisabled: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            Label(viewModel.resolverLabel, systemImage: "desktopcomputer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .help(
                    """
                    EN: System DNS mode validates the resolver path currently active in macOS.
                    VI: Mode System DNS kiểm tra đường resolver hiện đang active trong macOS.
                    """
                )

            ForEach(viewModel.detailLines, id: \.self) { line in
                Label(line, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                Button(action: onRefresh) {
                    Label("Refresh Current DNS", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshDisabled)
                .help("Refresh the current macOS DNS resolver summary.")

                Button {
                    copyToPasteboard(viewModel.copyText)
                } label: {
                    Label("Copy Current DNS", systemImage: "doc.on.doc")
                }
                .help("Copy the current macOS DNS resolver summary.")
            }
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

                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                    Label(viewModel.fastestObservedLabel, systemImage: "bolt")
                    Label(viewModel.balancedRecommendationLabel, systemImage: "scale.3d")
                }
                .foregroundStyle(.secondary)

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
                        Label("Validate System DNS", systemImage: "checkmark.seal")
                    }
                    .accessibilityIdentifier("benchmark-validate-system-dns-button")
                    .help("After manual DNS apply and cache flush, run System DNS validation against the current macOS resolver.")
                }

                Button {
                    copyToPasteboard(
                        BenchmarkApplyPlanReportFormatter.appendApplyPlan(
                            outcome: applyPlanOutcome,
                            isLoading: isLoadingApplyPlan,
                            restoreSnapshot: currentDNSBeforeApplySnapshot,
                            to: viewModel.resultReportText(
                                elapsedMS: elapsedMS,
                                includeNextStep: applyPlanPresentation.reportIncludesLocalNextStep
                            )
                        )
                    )
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

private struct BenchmarkApplyPlanStatusPanel: View {
    let outcome: BenchmarkApplyPlanLoadOutcome?
    let isLoading: Bool
    let currentDNSBeforeApplySnapshot: SystemDNSResolverSnapshot
    @State private var pendingGuidedApplyConfirmation: PendingGuidedApplyConfirmation?

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            Divider()

            if isLoading {
                Label("Checking apply policy", systemImage: "hourglass")
                    .font(.headline)
                Label(
                    "DNS Pilot is verifying the store-safe apply path for this result.",
                    systemImage: "info.circle"
                )
                .foregroundStyle(.secondary)
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
                    Label(message, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                    Button {
                        copyToPasteboard(message)
                    } label: {
                        Label("Copy Apply Error", systemImage: "doc.on.doc")
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
        Label("Apply policy: \(viewModel.statusLabel)", systemImage: viewModel.canOfferPrimaryAction ? "checkmark.shield" : "shield")
            .font(.headline)

        Label(viewModel.actionLabel, systemImage: applyPlanActionImage(for: viewModel.plan.disposition))
            .foregroundStyle(.secondary)

        if let recommendedProfileLabel = viewModel.recommendedProfileLabel {
            Label(recommendedProfileLabel, systemImage: "target")
                .foregroundStyle(.secondary)
        }

        if let testedResolver = viewModel.plan.testedResolver {
            Label("Tested resolver: \(testedResolver)", systemImage: "scope")
                .foregroundStyle(.secondary)
        }

        if !viewModel.dnsServerText.isEmpty {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                Label("DNS servers from shared plan", systemImage: "server.rack")
                    .font(.subheadline.weight(.semibold))
                ForEach(viewModel.plan.dnsServers, id: \.self) { server in
                    Label(server, systemImage: "number")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, DNSPilotDesign.Spacing.controlGap)
        }

        if !viewModel.guidedApplySteps.isEmpty {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                Label("Guided apply sequence", systemImage: "checklist")
                    .font(.subheadline.weight(.semibold))
                ForEach(viewModel.guidedApplySteps) { step in
                    HStack(alignment: .top, spacing: DNSPilotDesign.Spacing.controlGap) {
                        Image(systemName: step.systemImage)
                            .foregroundStyle(DNSPilotDesign.Palette.accent)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.body.weight(.semibold))
                            Text(step.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.vertical, DNSPilotDesign.Spacing.controlGap)
        }

        if viewModel.guidedPrimaryActionLabel != nil {
            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                Label(restoreViewModel.statusLabel, systemImage: restoreViewModel.hasRestorableDNS ? "arrow.uturn.backward.circle" : "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(restoreViewModel.hasRestorableDNS ? DNSPilotDesign.Palette.success : DNSPilotDesign.Palette.warning)

                if restoreViewModel.hasRestorableDNS {
                    ForEach(restoreViewModel.snapshot.servers, id: \.self) { server in
                        Label(server, systemImage: "number")
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                ForEach(restoreViewModel.detailLines, id: \.self) { line in
                    Label(line, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, DNSPilotDesign.Spacing.controlGap)
        }

        if !viewModel.plan.notes.isEmpty {
            ForEach(viewModel.plan.notes, id: \.self) { note in
                Label(note, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }

        HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
            if let primaryActionLabel = viewModel.guidedPrimaryActionLabel,
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

            if viewModel.canOfferPrimaryAction, !viewModel.plan.dnsServers.isEmpty {
                PowerDNSApplyButton(
                    profileName: viewModel.plan.profileName ?? viewModel.plan.profileID,
                    dnsServers: viewModel.plan.dnsServers
                )
            }

            if !viewModel.dnsServerText.isEmpty {
                Button {
                    copyToPasteboard(viewModel.dnsServerText)
                } label: {
                    Label("Copy Plan DNS", systemImage: "doc.on.doc")
                }
                .help("Copy DNS servers from the shared apply-plan output.")
            }

            if let guidedApplyChecklistText = viewModel.guidedApplyChecklistText {
                Button {
                    copyToPasteboard(
                        viewModel.guidedApplyChecklistTextWithRestore(currentDNSBeforeApplySnapshot)
                            ?? guidedApplyChecklistText
                    )
                } label: {
                    Label("Copy Apply Steps", systemImage: "checklist")
                }
                .help("Copy the guided DNS apply and retest checklist.")
            }

            if viewModel.guidedPrimaryActionLabel != nil {
                Button {
                    copyToPasteboard(restoreViewModel.copyText)
                } label: {
                    Label("Copy Restore DNS", systemImage: "arrow.uturn.backward.circle")
                }
                .help("Copy current DNS settings captured before guided apply.")
            }

            Button {
                copyToPasteboard(viewModel.copyText)
            } label: {
                Label("Copy Apply Plan", systemImage: "doc.on.doc")
            }
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
    @State private var pendingGuidedApplyConfirmation: PendingGuidedApplyConfirmation?

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
                }

                if let dnsSettings = viewModel.dnsSettings, dnsSettings.hasServers {
                    PowerDNSApplyButton(
                        profileName: dnsSettings.profileName,
                        dnsServers: dnsSettings.allServers
                    )
                }

                Button {
                    copyToPasteboard(viewModel.copyText)
                } label: {
                    Label("Copy Next Step", systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("benchmark-copy-next-step-button")
            }
        }
        .storeSafeGuidedApplyConfirmation(pending: $pendingGuidedApplyConfirmation)
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

import AppKit
import Foundation
import OSLog
import SwiftUI
import DNSPilotMacCore

enum DNSPilotWindowID {
    static let main = "main"
}

@MainActor
final class DNSPilotNavigationModel: ObservableObject {
    @Published var selection: SidebarSelection? = .benchmark
    @Published var quickBenchmarkRequestID = 0
    @Published var systemDNSValidationRequestID = 0
    @Published var benchmarkCancellationRequestID = 0
    @Published var lastGuidedApplyPlan: GuidedApplyPlanSnapshot?
    @Published var pendingGuidedApplyPlanConfirmation: GuidedApplyPlanSnapshot?
    @Published var isShowingFlushDNSConfirmation = false
    @Published var isShowingPermissionSetup = false

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

    func requestBenchmarkCancellation() {
        selection = .benchmark
        benchmarkCancellationRequestID += 1
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

struct DNSPilotMenuBarView: View {
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
        case .openApp, .benchmark:
            navigation.selection = .benchmark
        case .quickBenchmark:
            navigation.requestQuickBenchmark()
        case .guidedApplyLastDNS:
            guard let plan = navigation.lastGuidedApplyPlan else { return }
            navigation.requestGuidedApplyConfirmation(plan)
            navigation.selection = .benchmark
        case .flushDNS:
            navigation.requestFlushDNSConfirmation()
            navigation.selection = .benchmark
        case .copyLastDNS:
            guard let plan = navigation.lastGuidedApplyPlan else { return }
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

        if !DNSPilotWindowActivation.activateExistingWindows() {
            openWindow(id: DNSPilotWindowID.main)
            DNSPilotWindowActivation.activateSoon()
        }
    }
}

@MainActor
enum DNSPilotWindowActivation {
    @discardableResult
    static func activateExistingWindows() -> Bool {
        let windows = NSApp.windows.filter { $0.canBecomeKey && !$0.isMiniaturized }
        guard !windows.isEmpty else { return false }
        windows.forEach { $0.makeKeyAndOrderFront(nil) }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    static func activateSoon() {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            _ = activateExistingWindows()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(120)) {
            _ = activateExistingWindows()
        }
    }
}

@MainActor
final class DNSPilotApplicationDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.dnspilot.mac", category: "windowing")

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.logger.info("Application did finish launching")
        applyActivationPlan(.launch)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.logger.info("Application reopen requested visible_windows=\(flag, privacy: .public)")
        guard flag else { return false }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
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
            }
        }
    }
}

func copyToPasteboard(_ value: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(value, forType: .string)
}

func openNetworkSettings() {
    let settingsURLs = [
        "x-apple.systempreferences:com.apple.Network-Settings.extension",
        "x-apple.systempreferences:com.apple.preference.network",
    ]

    for urlString in settingsURLs {
        guard let url = URL(string: urlString) else { continue }
        if NSWorkspace.shared.open(url) { return }
    }

    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
}

import SwiftUI
import DNSPilotMacCore

struct DNSPilotSettingsView: View {
    @AppStorage(DNSPilotLanguagePreferences.storageKey) private var languageCode = DNSPilotLanguage.system.rawValue
    @AppStorage(MacOSPowerDNSActionConfiguration.userDefaultsKey) private var userEnabledPowerActions = false

    private var localizer: DNSPilotLocalizer {
        DNSPilotLocalizer(languageCode: languageCode)
    }

    private var presentation: MacOSSettingsPresentation {
        MacOSSettingsPresentation(
            isPowerBuild: MacOSPowerDNSActionConfiguration.isBuildCapable()
        )
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
                .accessibilityIdentifier("dns-pilot-language-picker")
                Text(localizer.text(.languageSubtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(localizer.text(.settingsTitle))
            }

            if presentation.showsPowerActions {
                Section {
                    DirectAdminActionsPanel(userEnabledPowerActions: $userEnabledPowerActions, compact: true)
                } header: {
                    Text(localizer.text(.powerActions))
                }
            }
        }
        .formStyle(.grouped)
        .padding(DNSPilotDesign.Spacing.panel)
        .frame(width: 460)
    }
}

struct PermissionSetupSheet: View {
    let localizer: DNSPilotLocalizer
    @Binding var userEnabledPowerActions: Bool
    @Binding var isPresented: Bool

    private var presentation: MacOSSettingsPresentation {
        MacOSSettingsPresentation(
            isPowerBuild: MacOSPowerDNSActionConfiguration.isBuildCapable()
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.panel) {
            HStack(alignment: .top, spacing: DNSPilotDesign.Spacing.row) {
                Image(systemName: "lock.shield")
                    .font(.largeTitle)
                    .foregroundStyle(DNSPilotDesign.Palette.accent)
                    .frame(width: 42)

                VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                    Text(localizer.text(.setup))
                        .font(.title2.weight(.semibold))
                    Text(localizer.text(.setupSubtitle))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
                Label(localizer.text(.benchmarkReady), systemImage: "checkmark.circle")
                    .foregroundStyle(DNSPilotDesign.Palette.success)
                    .help("DNS and TCP checks use normal outbound networking.")
                Label(localizer.text(.guidedApply), systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .help("macOS has no pre-grant toggle for plain DNS editing. DNSPilot copies values and opens Network Settings in Store-safe mode.")
                if presentation.showsPowerActions {
                    Label("Direct Admin: opt-in Power build", systemImage: "person.badge.key")
                        .foregroundStyle(.secondary)
                        .help("Power/direct-install builds can show admin Apply/Flush after explicit opt-in. macOS still asks for administrator approval at action time.")
                }
            }

            if presentation.showsPowerActions {
                DirectAdminActionsPanel(userEnabledPowerActions: $userEnabledPowerActions, compact: false)
            }

            HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                Spacer()

                Button(localizer.text(.useGuidedMode)) {
                    userEnabledPowerActions = false
                    isPresented = false
                }

                Button(localizer.text(.done)) {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(DNSPilotDesign.Spacing.panel)
        .frame(width: 620)
    }
}

struct DirectAdminActionsPanel: View {
    @Binding var userEnabledPowerActions: Bool
    let compact: Bool
    @State private var isConfirmingEnable = false

    private var isDirectAdminAvailable: Bool {
        MacOSPowerDNSActionConfiguration.isBuildCapable()
    }

    private var isEffectiveEnabled: Bool {
        MacOSPowerDNSActionConfiguration.isEnabled(userDefaultValue: userEnabledPowerActions)
    }

    private var isForcedByLaunch: Bool {
        MacOSPowerDNSActionConfiguration.isForcedEnabled()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNSPilotDesign.Spacing.controlGap) {
            Label(
                stateLabel,
                systemImage: isEffectiveEnabled ? "bolt.shield" : "lock.shield"
            )
            .font(compact ? .body.weight(.semibold) : .headline)
            .foregroundStyle(isEffectiveEnabled ? DNSPilotDesign.Palette.success : .secondary)

            Text(detailText)
                .font(compact ? .caption : .callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DNSPilotDesign.Spacing.controlGap) {
                if isEffectiveEnabled {
                    if isForcedByLaunch {
                        Label("Enabled by launch flag", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button(role: .destructive) {
                            userEnabledPowerActions = false
                        } label: {
                            Label("Disable Direct Admin Actions", systemImage: "lock")
                        }
                    }
                } else if isDirectAdminAvailable {
                    Button {
                        isConfirmingEnable = true
                    } label: {
                        Label("Enable Direct Admin Actions...", systemImage: "bolt.shield")
                    }
                } else {
                    Label("Power/direct-install build required", systemImage: "shippingbox")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if userEnabledPowerActions {
                        Button(role: .destructive) {
                            userEnabledPowerActions = false
                        } label: {
                            Label("Clear Direct Admin Preference", systemImage: "xmark.circle")
                        }
                    }
                }

                Button {
                    openNetworkSettings()
                } label: {
                    Label("Open Network Settings", systemImage: "gearshape")
                }
            }
        }
        .confirmationDialog(
            "Enable Direct Admin Actions?",
            isPresented: $isConfirmingEnable,
            titleVisibility: .visible
        ) {
            Button("Enable Direct Admin Actions") {
                userEnabledPowerActions = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("DNS Pilot will show Apply Now (Admin) and Flush Now (Admin). macOS will ask for administrator approval at action time, and the app may change the active network service DNS. Keep this off on managed, corporate, VPN, or App Store-safe builds.")
        }
    }

    private var stateLabel: String {
        if isEffectiveEnabled {
            return "Direct Admin Actions enabled"
        }
        if isDirectAdminAvailable {
            return "Direct Admin Actions available"
        }
        return "Guided mode active"
    }

    private var detailText: String {
        if isEffectiveEnabled {
            return "Apply Now (Admin) and Flush Now (Admin) are visible where a safe DNS plan is available. macOS still asks for administrator approval before changing DNS or flushing cache."
        }
        if isDirectAdminAvailable {
            return "This Power/direct-install build can run Apply/Flush inside the app after explicit opt-in. macOS asks for administrator approval at action time."
        }
        return "This Store-safe build only copies DNS/apply steps and opens Network Settings. Use a Power/direct-install build when this Mac should allow direct in-app Apply/Flush."
    }
}

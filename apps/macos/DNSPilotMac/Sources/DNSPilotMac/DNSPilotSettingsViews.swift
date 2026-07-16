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
                    .help(localizer.text(.networkChecksHelp))
                Label(localizer.text(.guidedApply), systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                    .help(localizer.text(.guidedApplyHelp))
                if presentation.showsPowerActions {
                    Label(localizer.text(.directAdminOptInPower), systemImage: "person.badge.key")
                        .foregroundStyle(.secondary)
                        .help(localizer.text(.directAdminOptInHelp))
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
    @AppStorage(DNSPilotLanguagePreferences.storageKey) private var languageCode = DNSPilotLanguage.system.rawValue
    @State private var isConfirmingEnable = false

    private var localizer: DNSPilotLocalizer {
        DNSPilotLocalizer(languageCode: languageCode)
    }

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
                        Label(localizer.text(.enabledByLaunchFlag), systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button(role: .destructive) {
                            userEnabledPowerActions = false
                        } label: {
                            Label(localizer.text(.disableDirectAdminActions), systemImage: "lock")
                        }
                    }
                } else if isDirectAdminAvailable {
                    Button {
                        isConfirmingEnable = true
                    } label: {
                        Label(localizer.text(.enableDirectAdminActions), systemImage: "bolt.shield")
                    }
                } else {
                    Label(localizer.text(.powerBuildRequired), systemImage: "shippingbox")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if userEnabledPowerActions {
                        Button(role: .destructive) {
                            userEnabledPowerActions = false
                        } label: {
                            Label(localizer.text(.clearDirectAdminPreference), systemImage: "xmark.circle")
                        }
                    }
                }

                Button {
                    openNetworkSettings()
                } label: {
                    Label(localizer.text(.openNetworkSettings), systemImage: "gearshape")
                }
            }
        }
        .confirmationDialog(
            localizer.text(.directAdminConfirmationTitle),
            isPresented: $isConfirmingEnable,
            titleVisibility: .visible
        ) {
            Button(localizer.text(.enableDirectAdminActions)) {
                userEnabledPowerActions = true
            }
            Button(localizer.text(.cancel), role: .cancel) {}
        } message: {
            Text(localizer.text(.directAdminConfirmationMessage))
        }
    }

    private var stateLabel: String {
        if isEffectiveEnabled {
            return localizer.text(.directAdminEnabled)
        }
        if isDirectAdminAvailable {
            return localizer.text(.directAdminAvailable)
        }
        return localizer.text(.guidedModeActive)
    }

    private var detailText: String {
        if isEffectiveEnabled {
            return localizer.text(.directAdminEnabledDetail)
        }
        if isDirectAdminAvailable {
            return localizer.text(.directAdminAvailableDetail)
        }
        return localizer.text(.guidedModeDetail)
    }
}

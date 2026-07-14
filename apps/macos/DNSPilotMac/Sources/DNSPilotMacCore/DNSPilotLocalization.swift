import Foundation

public enum DNSPilotLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case vietnamese = "vi"

    public var id: String {
        rawValue
    }

    public init(code: String) {
        let normalizedCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedCode == "system" {
            self = .system
        } else if normalizedCode == "en" || normalizedCode.hasPrefix("en-") {
            self = .english
        } else if normalizedCode == "vi" || normalizedCode.hasPrefix("vi-") {
            self = .vietnamese
        } else {
            self = .system
        }
    }

    public func resolved(preferredLanguageCodes: [String]) -> DNSPilotLanguage {
        guard self == .system else {
            return self
        }

        for code in preferredLanguageCodes {
            let candidate = DNSPilotLanguage(code: code)
            if candidate != .system {
                return candidate
            }
        }

        return .english
    }

    public var displayName: String {
        switch self {
        case .system:
            "System"
        case .english:
            "English"
        case .vietnamese:
            "Tiếng Việt"
        }
    }
}

public enum DNSPilotLanguagePreferences {
    public static let storageKey = "dnspilot.language"
}

public enum DNSPilotTextKey: String, CaseIterable, Sendable {
    case overview
    case platforms
    case capabilities
    case permissions
    case publish
    case benchmark
    case checkDNS
    case customDNS
    case history
    case catalog
    case settingsTitle
    case language
    case languageSubtitle
    case permissionsSubtitle
    case publishSubtitle
    case copyChecklist
    case openNetworkSettings
    case powerActions
    case powerActionsEnabled
    case powerActionsDisabled
    case run
    case running
    case cancel
    case refresh
    case clearAll
    case delete
    case edit
    case result
    case process
    case status
    case profile
    case resolver
    case medianDNS
    case p95DNS
    case medianTCP
    case failure
    case diagnosis
    case providers
    case suites
    case filtered
    case testSuites
    case savedRuns
    case noSavedRuns
    case capabilityMatrix
    case productGoals
    case apply
    case flush
    case platform
    case mode
    case options
    case benchmarkTargetHelp
    case networkSafeguards
    case profiles
    case targets
    case attempts
    case preset
    case dnsCandidates
    case probe
    case all
    case vietnam
    case global
    case game
    case gameCheckDisclaimer
    case dnsRecords
    case savedProfiles
    case noCustomPlainDNSProfiles
    case servers
    case name
    case newProfile
    case saveProfile
    case updateProfile
    case deleteCustomDNSProfile
    case historyNotLoaded
    case deleteSavedRun
    case clearHistory
    case customOnly
    case suiteName
    case savedSuites
    case newSuite
    case saveSuite
    case updateSuite
    case azureExample
    case deleteCustomSuite
    case copyResultReport
    case copyRunID
    case validateSystemDNS
    case refreshCurrentDNS
    case copyCurrentDNS
    case benchmarkFailed
    case failedAt
    case reason
    case suggestion
    case elapsed
    case debugLog
    case copyIssueReport
    case copyNextStep
    case copyDNSServers
    case copyApplyChecklist
    case entryPoint
    case validationEvidence
    case setup
    case setupSubtitle
    case benchmarkReady
    case guidedApply
    case useGuidedMode
    case done
    case chooseLanguage
    case showSetup
    case cancelBenchmark
    case runBenchmark
    case resolveReadinessIssues
    case modeDNSOnly
    case modeDNSTCP
    case modeSystemDNS
    case modeDNSOnlyHelp
    case modeDNSTCPHelp
    case modeSystemDNSHelp
    case recordAuto
    case recordIPv4
    case recordIPv6
    case recordAAndAAAA
    case recordAOnly
    case recordAAAAOnly
    case recordAAndAAAAHelp
    case recordAOnlyHelp
    case recordAAAAOnlyHelp
    case resolverAutoHelp
    case resolverIPv4Help
    case resolverIPv6Help
    case vpnActive
    case mdmManaged
    case corporateDNSRequired
    case captivePortal
    case safeguardExplanation
    case systemDNSProfilesIgnored
    case systemDNSValidationHelp
    case selectAllRunnable
    case selectAllRunnableHelp
    case showOptions
    case hideOptions
    case noRunnableProfiles
    case runnableProfilesSelected
    case customDomainsHelp
    case suiteNameHelp
    case saveSuiteHelp
    case newSuiteHelp
    case azureExampleHelp
    case attemptsHelp
    case dnsTimeoutHelp
    case tcpTimeoutHelp
    case tcpTargetsHelp
    case systemDNSResolverHelp
    case plainDNSProfileHelp
    case missingDNSResolver
    case missingDNSResolverHelp
    case missingDNSServer
    case missingDNSServerHelp
    case requiresDNSProfileFlow
    case requiresDNSProfileFlowHelp
    case suiteDomainCount
    case suiteDomainsHelp
    case vpnActiveHelp
    case mdmManagedHelp
    case corporateDNSRequiredHelp
    case captivePortalHelp
}

public struct DNSPilotLocalizer: Equatable, Sendable {
    public let language: DNSPilotLanguage
    private let preferredLanguageCodes: [String]

    public var resolvedLanguage: DNSPilotLanguage {
        language.resolved(preferredLanguageCodes: preferredLanguageCodes)
    }

    public var languageMenuLabel: String {
        switch resolvedLanguage {
        case .vietnamese:
            "VI"
        case .system, .english:
            "EN"
        }
    }

    public init(
        language: DNSPilotLanguage,
        preferredLanguageCodes: [String] = Locale.preferredLanguages
    ) {
        self.language = language
        self.preferredLanguageCodes = preferredLanguageCodes
    }

    public init(
        languageCode: String,
        preferredLanguageCodes: [String] = Locale.preferredLanguages
    ) {
        self.init(
            language: DNSPilotLanguage(code: languageCode),
            preferredLanguageCodes: preferredLanguageCodes
        )
    }

    public func text(_ key: DNSPilotTextKey) -> String {
        DNSPilotLocalizationCatalog.text(key, language: resolvedLanguage)
    }

    public func formatted(_ key: DNSPilotTextKey, _ arguments: CVarArg...) -> String {
        String(
            format: text(key),
            locale: Locale(identifier: resolvedLanguage.rawValue),
            arguments: arguments
        )
    }

}

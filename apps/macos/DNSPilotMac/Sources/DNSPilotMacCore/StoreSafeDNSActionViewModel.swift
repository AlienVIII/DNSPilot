import Foundation

public struct StoreSafeDNSActionConfirmationViewModel: Equatable, Sendable {
    public let title: String
    public let message: String
    public let confirmLabel: String
    public let cancelLabel: String
    public let systemImage: String

    public init(
        title: String,
        message: String,
        confirmLabel: String,
        cancelLabel: String = "Cancel",
        systemImage: String
    ) {
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
        self.cancelLabel = cancelLabel
        self.systemImage = systemImage
    }

    public static func guidedApply(
        profileName: String?,
        dnsServers: [String],
        hasRestoreDNS: Bool
    ) -> StoreSafeDNSActionConfirmationViewModel {
        let profileLabel = profileName.flatMap { $0.isEmpty ? nil : $0 } ?? "recommended DNS"
        let restoreSentence = hasRestoreDNS
            ? "Current DNS restore data is available if you need to revert."
            : "Current DNS was not captured; write down the current DNS settings before changing them."
        return StoreSafeDNSActionConfirmationViewModel(
            title: "Confirm guided DNS apply",
            message: "DNS Pilot will copy \(dnsServers.count) DNS server(s) for \(profileLabel) and open macOS Network Settings. It will not change system DNS automatically in the store-safe build. \(restoreSentence)",
            confirmLabel: "Copy DNS + Open Settings",
            systemImage: "gearshape"
        )
    }

    public static func macOSFlushGuidance() -> StoreSafeDNSActionConfirmationViewModel {
        StoreSafeDNSActionConfirmationViewModel(
            title: "Confirm DNS flush guidance",
            message: "Store-safe DNS Pilot cannot run sudo DNS flush commands. It will copy macOS flush commands and validation steps for you to run only if allowed.",
            confirmLabel: "Copy Flush Checklist",
            systemImage: "arrow.triangle.2.circlepath"
        )
    }
}

public struct StoreSafeDNSFlushGuidanceViewModel: Equatable, Sendable {
    public let buttonLabel = "Flush DNS..."
    public let confirmation = StoreSafeDNSActionConfirmationViewModel.macOSFlushGuidance()

    public init() {}

    public var checklistText: String {
        """
        System DNS validation checklist
        1. Apply DNS manually in macOS Network Settings.
        2. If allowed, flush local DNS cache before validating:
           sudo dscacheutil -flushcache
           sudo killall -HUP mDNSResponder
        3. Run System DNS validation in DNS Pilot.
        4. Treat browser Secure DNS, VPN, MDM, captive portal, and app caches as possible distortions.
        """
    }
}

public struct MacOSPowerDNSActionViewModel: Equatable, Sendable {
    public let isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public var applyButtonLabel: String? {
        isEnabled ? "Apply Now (Admin)" : nil
    }

    public var flushButtonLabel: String? {
        isEnabled ? "Flush Now (Admin)" : nil
    }

    public func applyConfirmationMessage(profileName: String?, dnsServers: [String]) -> String {
        let profileLabel = profileName.flatMap { $0.isEmpty ? nil : $0 } ?? "selected DNS"
        return "DNS Pilot will ask macOS for administrator approval, set \(dnsServers.count) DNS server(s) for \(profileLabel) on the active network service, and flush the local DNS cache. This is intended for direct-install Power builds, not App Store distribution."
    }

    public var flushConfirmationMessage: String {
        "DNS Pilot will ask macOS for administrator approval and flush the local DNS cache. This is intended for direct-install Power builds, not App Store distribution."
    }
}

public struct PowerDNSRollbackViewModel: Equatable, Sendable {
    public let isEnabled: Bool
    public let snapshot: PowerDNSRollbackSnapshot?
    public let now: Date
    public let maxAge: TimeInterval

    public init(
        isEnabled: Bool,
        snapshot: PowerDNSRollbackSnapshot?,
        now: Date = Date(),
        maxAge: TimeInterval = 86_400
    ) {
        self.isEnabled = isEnabled
        self.snapshot = snapshot
        self.now = now
        self.maxAge = maxAge
    }

    public var restorableSnapshot: PowerDNSRollbackSnapshot? {
        guard isEnabled,
              let snapshot,
              snapshot.isRestorable,
              snapshot.hasAppliedDNSState,
              snapshot.isFresh(now: now, maxAge: maxAge) else {
            return nil
        }
        return snapshot
    }

    public var restoreButtonLabel: String? {
        restorableSnapshot == nil ? nil : "Restore Previous DNS (Admin)"
    }

    public var confirmationMessage: String {
        guard let snapshot = restorableSnapshot else {
            return "No fresh Power DNS rollback is available."
        }
        return "DNS Pilot will ask macOS for administrator approval and restore \(restoreDescription(for: snapshot)) on \(snapshot.service). It will not change DNS if you cancel or the active network service has changed."
    }

    private func restoreDescription(for snapshot: PowerDNSRollbackSnapshot) -> String {
        switch snapshot.mode {
        case .automatic:
            "automatic DNS"
        case .servers:
            "the previous DNS server list"
        }
    }
}

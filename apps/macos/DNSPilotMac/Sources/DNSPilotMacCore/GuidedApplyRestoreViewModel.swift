import Foundation

public struct GuidedApplyRestoreViewModel: Equatable {
    public let snapshot: SystemDNSResolverSnapshot

    public init(snapshot: SystemDNSResolverSnapshot) {
        self.snapshot = snapshot
    }

    public var hasRestorableDNS: Bool {
        !snapshot.servers.isEmpty
    }

    public var statusLabel: String {
        hasRestorableDNS ? "Current DNS captured for restore" : "Current DNS not captured"
    }

    public var dnsServerText: String {
        snapshot.servers.joined(separator: "\n")
    }

    public var detailLines: [String] {
        guard hasRestorableDNS else {
            return [
                "Capture the current macOS DNS settings manually before changing DNS.",
                "SystemConfiguration may hide service DNS when VPN, MDM, or scoped resolvers are active.",
            ]
        }

        var lines = ["If validation fails, paste the previous DNS servers back into the active network service."]
        if !snapshot.searchDomains.isEmpty {
            lines.append("Search domains before apply: \(snapshot.searchDomains.joined(separator: ", "))")
        }
        if snapshot.supplementalResolverCount > 0 {
            lines.append("Scoped resolvers were present; restore may need VPN/MDM/service-specific settings.")
        }
        return lines
    }

    public var copyText: String {
        var lines = ["DNS Pilot restore checklist"]
        guard hasRestorableDNS else {
            lines.append("Current DNS unavailable")
            lines.append(contentsOf: detailLines)
            return lines.joined(separator: "\n")
        }

        lines.append("Current DNS before apply:")
        lines.append(dnsServerText)
        if !snapshot.searchDomains.isEmpty {
            lines.append("Search domains before apply:")
            lines.append(contentsOf: snapshot.searchDomains)
        }
        lines.append(contentsOf: detailLines)
        return lines.joined(separator: "\n")
    }
}

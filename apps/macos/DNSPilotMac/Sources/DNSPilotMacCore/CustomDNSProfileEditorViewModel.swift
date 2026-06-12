import Foundation

public enum CustomDNSProfileEditorState: Equatable, Sendable {
    case idle
    case saving
    case saved(profileID: String, name: String)
    case failed(String)
}

public struct CustomDNSProfileEditorViewModel: Equatable, Sendable {
    public let form: CustomDNSProfileFormViewModel
    public let state: CustomDNSProfileEditorState

    public var canSave: Bool {
        form.canSave && state != .saving
    }

    public var saveButtonLabel: String {
        switch state {
        case .saving:
            "Saving"
        case .idle, .saved, .failed:
            "Save Profile"
        }
    }

    public var profileIDLabel: String {
        "Profile ID: \(form.profileID)"
    }

    public var issues: [String] {
        form.issues
    }

    public var statusMessage: String? {
        switch state {
        case .idle:
            nil
        case .saving:
            "Saving \(form.name)..."
        case .saved(let profileID, let name):
            "Saved \(name) as \(profileID)."
        case .failed(let message):
            message
        }
    }

    public init(
        name: String,
        ipv4ServersText: String,
        ipv6ServersText: String,
        state: CustomDNSProfileEditorState
    ) {
        self.form = CustomDNSProfileFormViewModel(
            name: name,
            ipv4ServersText: ipv4ServersText,
            ipv6ServersText: ipv6ServersText
        )
        self.state = state
    }
}

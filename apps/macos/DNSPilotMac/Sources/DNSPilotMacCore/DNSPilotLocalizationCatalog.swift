import Foundation

public enum DNSPilotLocalizationCatalog {
    private static let resourceBundleName = "DNSPilotMac_DNSPilotMacCore.bundle"

    public static func text(_ key: DNSPilotTextKey, language: DNSPilotLanguage) -> String {
        let localeCode = switch language {
        case .vietnamese:
            "vi"
        case .system, .english:
            "en"
        }

        let bundle = localizedBundle(for: localeCode)
        return bundle.localizedString(forKey: key.rawValue, value: key.rawValue, table: "Localizable")
    }

    private static func localizedBundle(for localeCode: String) -> Bundle {
        guard let path = localizationBundle.path(forResource: localeCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return localizationBundle
        }
        return bundle
    }

    private static var localizationBundle: Bundle {
        let mainBundle = Bundle.main
        if mainBundle.bundleURL.pathExtension == "app",
           let resourceURL = mainBundle.resourceURL?.appendingPathComponent(resourceBundleName),
           let bundle = Bundle(url: resourceURL) {
            return bundle
        }

        // SwiftPM's test host is not the packaged application. Its generated accessor
        // resolves the resource bundle from the build products directory.
        return .module
    }
}

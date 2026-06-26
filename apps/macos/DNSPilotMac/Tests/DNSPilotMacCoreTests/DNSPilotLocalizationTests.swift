import XCTest
@testable import DNSPilotMacCore

final class DNSPilotLocalizationTests: XCTestCase {
    func testLanguageOptionsIncludeSystemEnglishAndVietnamese() {
        XCTAssertEqual(DNSPilotLanguage.allCases.map(\.rawValue), ["system", "en", "vi"])
        XCTAssertEqual(DNSPilotLanguage.vietnamese.displayName, "Tiếng Việt")
    }

    func testLocalizerReturnsVietnameseNavigationLabels() {
        let localizer = DNSPilotLocalizer(language: .vietnamese)

        XCTAssertEqual(localizer.text(.capabilities), "Khả năng")
        XCTAssertEqual(localizer.text(.permissions), "Quyền")
        XCTAssertEqual(localizer.text(.publish), "Phát hành")
        XCTAssertEqual(localizer.text(.language), "Ngôn ngữ")
        XCTAssertEqual(localizer.text(.run), "Chạy")
        XCTAssertEqual(localizer.text(.dnsCandidates), "DNS ứng viên")
    }

    func testLocalizerFallsBackToEnglishForSystemLanguage() {
        let localizer = DNSPilotLocalizer(language: .system)

        XCTAssertEqual(localizer.text(.benchmark), "Benchmark")
        XCTAssertEqual(localizer.text(.settingsTitle), "Settings")
    }

    func testLanguageFromCodeFallsBackToSystem() {
        XCTAssertEqual(DNSPilotLanguage(code: "vi"), .vietnamese)
        XCTAssertEqual(DNSPilotLanguage(code: "unknown"), .system)
    }

    func testAllTextKeysHaveConcreteEnglishAndVietnameseLabels() {
        let english = DNSPilotLocalizer(language: .english)
        let vietnamese = DNSPilotLocalizer(language: .vietnamese)

        for key in DNSPilotTextKey.allCases {
            XCTAssertNotEqual(english.text(key), key.rawValue, "Missing English label for \(key)")
            XCTAssertNotEqual(vietnamese.text(key), key.rawValue, "Missing Vietnamese label for \(key)")
        }
    }
}

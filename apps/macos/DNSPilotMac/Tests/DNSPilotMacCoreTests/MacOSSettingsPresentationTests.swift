import XCTest
@testable import DNSPilotMacCore

final class MacOSSettingsPresentationTests: XCTestCase {
    func testStoreSafePresentationDoesNotExposePowerActions() {
        let presentation = MacOSSettingsPresentation(isPowerBuild: false)

        XCTAssertFalse(presentation.showsPowerActions)
    }

    func testPowerPresentationExposesPowerActions() {
        let presentation = MacOSSettingsPresentation(isPowerBuild: true)

        XCTAssertTrue(presentation.showsPowerActions)
    }
}

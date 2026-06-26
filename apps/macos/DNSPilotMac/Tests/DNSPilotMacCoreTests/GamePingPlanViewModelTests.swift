import XCTest
@testable import DNSPilotMacCore

final class GamePingPlanViewModelTests: XCTestCase {
    func testViewModelListsGamingSuitesOnly() {
        let viewModel = GamePingPlanViewModel(catalog: CatalogViewModel().catalog!)

        XCTAssertEqual(viewModel.presetOptions.map(\.id), [
            "gaming-steam-valve",
            "gaming-dota2-sea",
            "gaming-cs2",
            "gaming-riot-lol",
        ])
        XCTAssertEqual(viewModel.presetOptions.first { $0.id == "gaming-dota2-sea" }?.name, "Gaming / Dota 2 SEA")
        XCTAssertTrue(viewModel.warningText.contains("not ICMP ping"))
    }

    func testViewModelBuildsPathComparePlanForGamingPreset() {
        let catalog = CatalogViewModel().catalog!
        let viewModel = GamePingPlanViewModel(
            catalog: catalog,
            selectedPresetID: "gaming-dota2-sea",
            selectedProfileIDs: ["cloudflare", "google-public-dns"],
            attempts: 2,
            dnsTimeoutMS: 700,
            connectTimeoutMS: 900
        )

        XCTAssertTrue(viewModel.canRun)
        XCTAssertEqual(viewModel.selectedPreset?.domains.first, "dota2.com")
        XCTAssertEqual(
            viewModel.plan.commandArguments,
            [
                "path-compare",
                "--resolver", "cloudflare=1.1.1.1:53",
                "--resolver", "google-public-dns=8.8.8.8:53",
                "--domain", "dota2.com",
                "--domain", "steamcommunity.com",
                "--domain", "steampowered.com",
                "--domain", "steamcontent.com",
                "--domain", "api.steampowered.com",
                "--attempts", "2",
                "--ip-family", "both",
                "--dns-timeout-ms", "700",
                "--connect-timeout-ms", "900",
                "--max-connect-targets-per-domain", "4",
            ]
        )
    }

    func testViewModelRequiresGamingPresetAndResolver() {
        let catalog = CatalogViewModel().catalog!
        let noPreset = GamePingPlanViewModel(
            catalog: catalog,
            selectedPresetID: "not-a-game",
            selectedProfileIDs: ["cloudflare"]
        )
        let noResolver = GamePingPlanViewModel(
            catalog: catalog,
            selectedPresetID: "gaming-dota2-sea",
            selectedProfileIDs: []
        )

        XCTAssertFalse(noPreset.canRun)
        XCTAssertTrue(noPreset.issues.contains("Select a game preset."))
        XCTAssertFalse(noResolver.canRun)
        XCTAssertTrue(noResolver.issues.contains("Select at least one DNS profile."))
    }
}

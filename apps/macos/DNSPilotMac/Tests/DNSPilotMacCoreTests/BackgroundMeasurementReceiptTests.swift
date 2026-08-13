import Foundation
import XCTest
@testable import DNSPilotMacCore

final class BackgroundMeasurementReceiptTests: XCTestCase {
    func testStorePersistsAndLoadsActiveBenchmarkReceipt() throws {
        let defaults = makeDefaults()
        let store = BackgroundMeasurementReceiptStore(defaults: defaults)
        let receipt = BackgroundMeasurementReceipt.starting(
            runID: "run-1",
            kind: .dnsBenchmark,
            at: Date(timeIntervalSince1970: 100)
        )

        store.save(receipt)

        XCTAssertEqual(store.load(), receipt)
    }

    func testReconcileMarksNonterminalReceiptInterruptedWithoutRetrying() {
        let defaults = makeDefaults()
        let store = BackgroundMeasurementReceiptStore(defaults: defaults)
        store.save(
            BackgroundMeasurementReceipt(
                runID: "run-1",
                kind: .dnsBenchmark,
                status: .running,
                startedAt: Date(timeIntervalSince1970: 100),
                updatedAt: Date(timeIntervalSince1970: 101),
                resultReference: nil
            )
        )

        let recovered = store.reconcileInterruptedRun(at: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(recovered?.status, .interrupted)
        XCTAssertEqual(recovered?.updatedAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(recovered?.resultReference, nil)
        XCTAssertEqual(store.load(), recovered)
    }

    func testReconcileLeavesTerminalReceiptUntouched() {
        let defaults = makeDefaults()
        let store = BackgroundMeasurementReceiptStore(defaults: defaults)
        let receipt = BackgroundMeasurementReceipt(
            runID: "run-1",
            kind: .dnsBenchmark,
            status: .completed,
            startedAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 101),
            resultReference: "history-1"
        )
        store.save(receipt)

        XCTAssertNil(store.reconcileInterruptedRun(at: Date(timeIntervalSince1970: 200)))
        XCTAssertEqual(store.load(), receipt)
    }

    func testOnlyOneNonterminalReceiptCanOwnMeasurement() {
        let active = BackgroundMeasurementReceipt.starting(
            runID: "run-1",
            kind: .dnsBenchmark,
            at: Date(timeIntervalSince1970: 100)
        )

        XCTAssertFalse(BackgroundMeasurementReceipt.canStartNewMeasurement(existing: active))

        let completed = active.transitioned(to: .completed, at: Date(timeIntervalSince1970: 101))
        XCTAssertTrue(BackgroundMeasurementReceipt.canStartNewMeasurement(existing: completed))
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "BackgroundMeasurementReceiptTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { [suiteName] in
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}

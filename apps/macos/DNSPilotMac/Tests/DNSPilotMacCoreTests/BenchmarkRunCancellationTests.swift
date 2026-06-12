import XCTest
@testable import DNSPilotMacCore

final class BenchmarkRunCancellationTests: XCTestCase {
    func testCancelMarksTokenAndInvokesRegisteredHandlerOnce() {
        let cancellation = BenchmarkRunCancellation()
        var cancelCount = 0

        cancellation.register {
            cancelCount += 1
        }
        cancellation.cancel()
        cancellation.cancel()

        XCTAssertTrue(cancellation.isCancelled)
        XCTAssertEqual(cancelCount, 1)
    }

    func testRegisterAfterCancelInvokesHandlerImmediately() {
        let cancellation = BenchmarkRunCancellation()
        var cancelCount = 0

        cancellation.cancel()
        cancellation.register {
            cancelCount += 1
        }

        XCTAssertEqual(cancelCount, 1)
    }

    func testRegistrationCanBeRemovedBeforeCancel() {
        let cancellation = BenchmarkRunCancellation()
        var cancelCount = 0

        let registration = cancellation.register {
            cancelCount += 1
        }
        registration.cancel()
        cancellation.cancel()

        XCTAssertEqual(cancelCount, 0)
    }
}

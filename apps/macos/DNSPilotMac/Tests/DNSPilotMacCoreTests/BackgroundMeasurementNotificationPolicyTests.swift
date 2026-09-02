import XCTest
@testable import DNSPilotMacCore

final class BackgroundMeasurementNotificationPolicyTests: XCTestCase {
    func testOnlySystemAuthorizedStatesAllowCompletionNotifications() {
        XCTAssertFalse(BackgroundMeasurementNotificationAuthorization.notDetermined.allowsDelivery)
        XCTAssertFalse(BackgroundMeasurementNotificationAuthorization.denied.allowsDelivery)
        XCTAssertTrue(BackgroundMeasurementNotificationAuthorization.authorized.allowsDelivery)
        XCTAssertTrue(BackgroundMeasurementNotificationAuthorization.provisional.allowsDelivery)
        XCTAssertTrue(BackgroundMeasurementNotificationAuthorization.ephemeral.allowsDelivery)
    }

    func testOffersOptInOnlyBeforePromptIsHandled() {
        XCTAssertTrue(
            BackgroundMeasurementNotificationPolicy.shouldOfferOptIn(
                notificationsEnabled: false,
                promptHandled: false
            )
        )
        XCTAssertFalse(
            BackgroundMeasurementNotificationPolicy.shouldOfferOptIn(
                notificationsEnabled: false,
                promptHandled: true
            )
        )
        XCTAssertFalse(
            BackgroundMeasurementNotificationPolicy.shouldOfferOptIn(
                notificationsEnabled: true,
                promptHandled: false
            )
        )
    }

    func testSchedulesOnlyTerminalNoncancelledCompletionWhenInactiveAndOptedIn() {
        XCTAssertTrue(
            BackgroundMeasurementNotificationPolicy.shouldScheduleCompletion(
                status: .completed,
                notificationsEnabled: true,
                applicationIsActive: false
            )
        )
        XCTAssertTrue(
            BackgroundMeasurementNotificationPolicy.shouldScheduleCompletion(
                status: .failed,
                notificationsEnabled: true,
                applicationIsActive: false
            )
        )
        XCTAssertFalse(
            BackgroundMeasurementNotificationPolicy.shouldScheduleCompletion(
                status: .cancelled,
                notificationsEnabled: true,
                applicationIsActive: false
            )
        )
        XCTAssertFalse(
            BackgroundMeasurementNotificationPolicy.shouldScheduleCompletion(
                status: .completed,
                notificationsEnabled: true,
                applicationIsActive: true
            )
        )
        XCTAssertFalse(
            BackgroundMeasurementNotificationPolicy.shouldScheduleCompletion(
                status: .completed,
                notificationsEnabled: false,
                applicationIsActive: false
            )
        )
    }
}

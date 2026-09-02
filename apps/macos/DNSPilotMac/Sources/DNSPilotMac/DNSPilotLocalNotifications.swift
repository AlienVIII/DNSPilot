import AppKit
import Foundation
import UserNotifications
import DNSPilotMacCore

@MainActor
final class DNSPilotLocalNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DNSPilotLocalNotifications()

    private enum Constants {
        static let runIDKey = "dnspilot.measurement-run-id"
        static let statusKey = "dnspilot.measurement-status"
        static let resultReferenceKey = "dnspilot.measurement-result-reference"
        static let requestPrefix = "dnspilot.measurement."
    }

    private let center = UNUserNotificationCenter.current()
    private var openResult: ((BackgroundMeasurementResultDestination) -> Void)?

    func configure(openResult: @escaping (BackgroundMeasurementResultDestination) -> Void) {
        self.openResult = openResult
        center.delegate = self
    }

    func notificationAuthorization() async -> BackgroundMeasurementNotificationAuthorization {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async -> BackgroundMeasurementNotificationAuthorization {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            // The current Settings state is the only authoritative result.
        }
        return await notificationAuthorization()
    }

    func scheduleCompletion(
        runID: String,
        status: BackgroundMeasurementStatus,
        resultReference: String?,
        title: String,
        body: String
    ) async -> DNSPilotLocalNotificationScheduleOutcome {
        guard BackgroundMeasurementNotificationPolicy.shouldScheduleCompletion(
            status: status,
            notificationsEnabled: true,
            applicationIsActive: NSApp.isActive
        ) else {
            return .notScheduled
        }

        guard (await notificationAuthorization()).allowsDelivery else {
            return .unavailable
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        var userInfo: [AnyHashable: Any] = [
            Constants.runIDKey: runID,
            Constants.statusKey: status.rawValue,
        ]
        if let resultReference, !resultReference.isEmpty {
            userInfo[Constants.resultReferenceKey] = resultReference
        }
        content.userInfo = userInfo

        let identifier = Constants.requestPrefix + runID
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
            return .scheduled
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let status = (userInfo[Constants.statusKey] as? String)
            .flatMap(BackgroundMeasurementStatus.init(rawValue:))
        let resultReference = userInfo[Constants.resultReferenceKey] as? String
        center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
        completionHandler()
        Task { @MainActor [weak self] in
            self?.openResult?(
                BackgroundMeasurementResultDestination(
                    status: status ?? .failed,
                    resultReference: resultReference
                )
            )
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

enum DNSPilotLocalNotificationScheduleOutcome: Equatable {
    case notScheduled
    case scheduled
    case unavailable
    case failed(String)
}

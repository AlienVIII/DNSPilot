import AppKit
import Foundation
import UserNotifications
import DNSPilotMacCore

@MainActor
final class DNSPilotLocalNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DNSPilotLocalNotifications()

    private enum Constants {
        static let runIDKey = "dnspilot.measurement-run-id"
        static let requestPrefix = "dnspilot.measurement."
    }

    private let center = UNUserNotificationCenter.current()
    private var openResult: ((String) -> Void)?

    func configure(openResult: @escaping (String) -> Void) {
        self.openResult = openResult
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func scheduleCompletion(runID: String, status: BackgroundMeasurementStatus, title: String, body: String) {
        guard BackgroundMeasurementNotificationPolicy.shouldScheduleCompletion(
            status: status,
            notificationsEnabled: true,
            applicationIsActive: NSApp.isActive
        ) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = [Constants.runIDKey: runID]

        let identifier = Constants.requestPrefix + runID
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
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
        let runID = response.notification.request.content.userInfo[Constants.runIDKey] as? String
        center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
        completionHandler()
        Task { @MainActor [weak self] in
            if let runID {
                self?.openResult?(runID)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

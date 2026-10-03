import Foundation
import UserNotifications

enum NotificationRoute: Equatable {
    case quickEntry
    case statistics
    case widget(LedgerWidgetRoute)
}

final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    @Published var route: NotificationRoute?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func open(_ url: URL) {
        guard let widgetRoute = LedgerWidgetRoute(url: url) else { return }
        route = .widget(widgetRoute)
    }

    func consume() {
        route = nil
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let raw = response.notification.request.content.userInfo["route"] as? String
        DispatchQueue.main.async {
            self.route = raw == "statistics" ? .statistics : .quickEntry
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

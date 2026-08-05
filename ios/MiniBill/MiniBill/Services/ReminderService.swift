import Foundation
import UserNotifications

enum ReminderPreferenceKey {
    static let dailyEnabled = "reminder.daily.enabled"
    static let dailyHour = "reminder.daily.hour"
    static let dailyMinute = "reminder.daily.minute"
    static let monthEndEnabled = "reminder.monthEnd.enabled"
    static let monthEndHour = "reminder.monthEnd.hour"
    static let monthEndMinute = "reminder.monthEnd.minute"
}

actor ReminderService {
    static let shared = ReminderService()
    static let dailyIdentifier = "minibill.reminder.daily"
    static let monthEndPrefix = "minibill.reminder.monthEnd."

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func setDailyEnabled(_ enabled: Bool, hour: Int, minute: Int) async {
        defaults.set(enabled, forKey: ReminderPreferenceKey.dailyEnabled)
        defaults.set(hour, forKey: ReminderPreferenceKey.dailyHour)
        defaults.set(minute, forKey: ReminderPreferenceKey.dailyMinute)
        if enabled { _ = await requestPermissionIfNeeded() }
        await reconcileFromPreferences()
    }

    func setMonthEndEnabled(_ enabled: Bool, hour: Int, minute: Int) async {
        defaults.set(enabled, forKey: ReminderPreferenceKey.monthEndEnabled)
        defaults.set(hour, forKey: ReminderPreferenceKey.monthEndHour)
        defaults.set(minute, forKey: ReminderPreferenceKey.monthEndMinute)
        if enabled { _ = await requestPermissionIfNeeded() }
        await reconcileFromPreferences()
    }

    func reconcileFromPreferences() async {
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.dailyIdentifier])
            await removeMonthEndRequests()
            return
        }

        if defaults.bool(forKey: ReminderPreferenceKey.dailyEnabled) {
            let hour = storedInt(ReminderPreferenceKey.dailyHour, default: 20)
            let minute = storedInt(ReminderPreferenceKey.dailyMinute, default: 0)
            await scheduleDaily(hour: hour, minute: minute)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.dailyIdentifier])
        }

        if defaults.bool(forKey: ReminderPreferenceKey.monthEndEnabled) {
            let hour = storedInt(ReminderPreferenceKey.monthEndHour, default: 21)
            let minute = storedInt(ReminderPreferenceKey.monthEndMinute, default: 0)
            await scheduleMonthEnds(hour: hour, minute: minute)
        } else {
            await removeMonthEndRequests()
        }
    }

    private func requestPermissionIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        if status == .notDetermined {
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        return status == .authorized || status == .provisional
    }

    private func scheduleDaily(hour: Int, minute: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyIdentifier])
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Daily bookkeeping reminder")
        content.body = String(localized: "Take a moment to record today's income and expenses.")
        content.sound = .default
        content.userInfo = ["route": "quickEntry"]
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        try? await center.add(UNNotificationRequest(identifier: Self.dailyIdentifier, content: content, trigger: trigger))
    }

    private func scheduleMonthEnds(hour: Int, minute: Int) async {
        await removeMonthEndRequests()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = Date()
        let dates = ReminderSchedule.monthEnds(startingAt: now, count: 13, calendar: calendar)
            .compactMap { date -> Date? in
                var components = calendar.dateComponents([.year, .month, .day], from: date)
                components.hour = hour
                components.minute = minute
                return calendar.date(from: components)
            }
            .filter { $0 > now }
            .prefix(12)

        for date in dates {
            let values = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let identifier = String(format: "%@%04d-%02d", Self.monthEndPrefix, values.year ?? 0, values.month ?? 0)
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Month-end review")
            content.body = String(localized: "Review this month's income and expenses in MiniBill.")
            content.sound = .default
            content.userInfo = ["route": "statistics"]
            let trigger = UNCalendarNotificationTrigger(dateMatching: values, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    private func removeMonthEndRequests() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.monthEndPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func storedInt(_ key: String, default fallback: Int) -> Int {
        defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }
}

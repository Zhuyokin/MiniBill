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

    func setDailyEnabled(_ enabled: Bool, hour: Int, minute: Int) async throws {
        defaults.set(enabled, forKey: ReminderPreferenceKey.dailyEnabled)
        defaults.set(hour, forKey: ReminderPreferenceKey.dailyHour)
        defaults.set(minute, forKey: ReminderPreferenceKey.dailyMinute)
        if enabled {
            do {
                _ = try await requestPermissionIfNeeded()
            } catch {
                center.removePendingNotificationRequests(withIdentifiers: [Self.dailyIdentifier])
                throw error
            }
        }
        try await reconcileFromPreferences()
    }

    func setMonthEndEnabled(_ enabled: Bool, hour: Int, minute: Int) async throws {
        defaults.set(enabled, forKey: ReminderPreferenceKey.monthEndEnabled)
        defaults.set(hour, forKey: ReminderPreferenceKey.monthEndHour)
        defaults.set(minute, forKey: ReminderPreferenceKey.monthEndMinute)
        if enabled {
            do {
                _ = try await requestPermissionIfNeeded()
            } catch {
                await removeMonthEndRequests()
                throw error
            }
        }
        try await reconcileFromPreferences()
    }

    func reconcileFromPreferences() async throws {
        let status = await authorizationStatus()
        guard canScheduleNotifications(status) else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.dailyIdentifier])
            await removeMonthEndRequests()
            return
        }

        var firstSchedulingError: Error?

        if defaults.bool(forKey: ReminderPreferenceKey.dailyEnabled) {
            let hour = storedInt(ReminderPreferenceKey.dailyHour, default: 20)
            let minute = storedInt(ReminderPreferenceKey.dailyMinute, default: 0)
            do {
                try await scheduleDaily(hour: hour, minute: minute)
            } catch {
                firstSchedulingError = error
            }
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.dailyIdentifier])
        }

        if defaults.bool(forKey: ReminderPreferenceKey.monthEndEnabled) {
            let hour = storedInt(ReminderPreferenceKey.monthEndHour, default: 21)
            let minute = storedInt(ReminderPreferenceKey.monthEndMinute, default: 0)
            do {
                try await scheduleMonthEnds(hour: hour, minute: minute)
            } catch {
                if firstSchedulingError == nil {
                    firstSchedulingError = error
                }
            }
        } else {
            await removeMonthEndRequests()
        }

        if let firstSchedulingError {
            throw firstSchedulingError
        }
    }

    private func requestPermissionIfNeeded() async throws -> Bool {
        let status = await authorizationStatus()
        if status == .notDetermined {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        return canScheduleNotifications(status)
    }

    private func scheduleDaily(hour: Int, minute: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Daily bookkeeping reminder")
        content.body = String(localized: "Take a moment to record today's income and expenses.")
        content.sound = .default
        content.userInfo = ["route": "quickEntry"]
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute), repeats: true)
        let request = UNNotificationRequest(identifier: Self.dailyIdentifier, content: content, trigger: trigger)
        let center = center

        try await ReminderBatchScheduler.replace(
            items: [request],
            removeExisting: {
                center.removePendingNotificationRequests(withIdentifiers: [Self.dailyIdentifier])
            },
            add: { try await center.add($0) }
        )
    }

    private func scheduleMonthEnds(hour: Int, minute: Int) async throws {
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

        let requests = dates.map { date in
            let values = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let identifier = String(format: "%@%04d-%02d", Self.monthEndPrefix, values.year ?? 0, values.month ?? 0)
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Month-end review")
            content.body = String(localized: "Review this month's income and expenses in MiniBill.")
            content.sound = .default
            content.userInfo = ["route": "statistics"]
            let trigger = UNCalendarNotificationTrigger(dateMatching: values, repeats: false)
            return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        }
        let center = center

        try await ReminderBatchScheduler.replace(
            items: requests,
            removeExisting: { await self.removeMonthEndRequests() },
            add: { try await center.add($0) }
        )
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

    private func canScheduleNotifications(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }
}

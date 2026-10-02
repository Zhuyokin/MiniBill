import SwiftUI
import SwiftData
import UserNotifications
import UIKit

private enum SettingsHelpTopic: String, Identifiable {
    case accounts
    case reminders
    case backup

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .accounts: "Accounts"
        case .reminders: "Reminders"
        case .backup: "Backup"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .accounts: "Entries and statistics are isolated by account."
        case .reminders: "MiniBill schedules reminders on this device. Delivery can be affected by system notification settings, Focus, or power state."
        case .backup: "Backups are not encrypted. Save them only in a location you trust."
        }
    }
}

private struct SettingsSectionHeader: View {
    let title: LocalizedStringKey
    let helpAccessibilityLabel: LocalizedStringKey
    let showHelp: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
            Button(action: showHelp) {
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(helpAccessibilityLabel)
        }
    }
}

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @Binding var selectedAccountID: UUID

    @AppStorage(ReminderPreferenceKey.dailyEnabled) private var dailyEnabled = false
    @AppStorage(ReminderPreferenceKey.dailyHour) private var dailyHour = 20
    @AppStorage(ReminderPreferenceKey.dailyMinute) private var dailyMinute = 0
    @AppStorage(ReminderPreferenceKey.monthEndEnabled) private var monthEndEnabled = false
    @AppStorage(ReminderPreferenceKey.monthEndHour) private var monthEndHour = 21
    @AppStorage(ReminderPreferenceKey.monthEndMinute) private var monthEndMinute = 0
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.simplifiedChinese.rawValue
    @AppStorage(AppInterfaceStyle.storageKey) private var interfaceStyleValue = AppInterfaceStyle.modern.rawValue

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var reminderErrorMessage: String?
    @State private var copiedEmailMessage: String?
    @State private var helpTopic: SettingsHelpTopic?

    private let supportEmail = "yokinzhu@gmail.com"
    private let appStoreReviewURL = URL(string: "itms-apps://apps.apple.com/app/id6761642667?action=write-review")
    private let appStoreWebReviewURL = URL(string: "https://apps.apple.com/app/id6761642667?action=write-review")
    private let moreAppsURL = URL(string: "https://apps.apple.com/developer/%E8%A3%95%E9%87%91-%E6%9C%B1/id1888184686")

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }

    private var selectedEntryCount: Int {
        entries.lazy.filter { $0.resolvedAccountID == selectedAccountID }.count
    }

    private var selectedInterfaceStyle: AppInterfaceStyle {
        AppInterfaceStyle(storedValue: interfaceStyleValue)
    }

    var body: some View {
        Form {
            Section {
                AccountSettingsLink(
                    selectedAccountID: $selectedAccountID,
                    entryCount: selectedEntryCount
                )
            } header: {
                SettingsSectionHeader(title: "Accounts", helpAccessibilityLabel: "Account Help") { helpTopic = .accounts }
            }

            Section {
                VStack(spacing: 8) {
                    ForEach(AppInterfaceStyle.allCases, id: \.self) { style in
                        InterfaceStyleOption(
                            style: style,
                            isSelected: selectedInterfaceStyle == style,
                            action: { interfaceStyleValue = style.rawValue }
                        )
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Appearance")
            }

            Section {
                Toggle(isOn: dailyBinding) {
                    Label("Daily Reminder", systemImage: "bell")
                }
                if dailyEnabled {
                    DatePicker("Daily Time", selection: timeBinding(hour: $dailyHour, minute: $dailyMinute, action: reconcileDaily), displayedComponents: .hourAndMinute)
                }
                Toggle(isOn: monthEndBinding) {
                    Label("Month-end Reminder", systemImage: "calendar.badge.clock")
                }
                if monthEndEnabled {
                    DatePicker("Month-end Time", selection: timeBinding(hour: $monthEndHour, minute: $monthEndMinute, action: reconcileMonthEnd), displayedComponents: .hourAndMinute)
                }
                if authorizationStatus == .denied {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System notifications are off. Your reminder preference is preserved.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Button { openSystemSettings() } label: {
                            Label("Open System Settings", systemImage: "gearshape")
                        }
                    }
                }
                if let reminderErrorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reminderErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Button("Try Again", action: retryReminderScheduling)
                    }
                }
            } header: {
                SettingsSectionHeader(title: "Reminders", helpAccessibilityLabel: "Reminder Help") { helpTopic = .reminders }
            }

            Section {
                NavigationLink {
                    BackupSettingsView(selectedAccountID: $selectedAccountID)
                } label: {
                    Label("Backup", systemImage: "externaldrive")
                }
            } header: {
                SettingsSectionHeader(title: "Backup", helpAccessibilityLabel: "Backup Help") { helpTopic = .backup }
            }

            Section("App") {
                NavigationLink {
                    LanguageSelectionView(languageCode: $languageCode)
                } label: {
                    HStack {
                        Label("Language", systemImage: "globe")
                        Spacer()
                        Text(AppLanguage(storedCode: languageCode).displayName)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink { AboutView(appVersion: appVersion) } label: {
                    Label("About MiniBill", systemImage: "info.circle")
                }
                LabeledContent {
                    Text(appVersion)
                } label: {
                    Label("Version", systemImage: "number")
                }
                Button(action: openSupportEmail) {
                    HStack {
                        Label("Contact Email", systemImage: "envelope")
                        Spacer()
                        Text(supportEmail)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Button(action: openAppStoreRating) {
                    Label("Thanks for using MiniBill. Leave a review", systemImage: "star")
                }
                Button(action: openMoreApps) {
                    Label("More Apps", systemImage: "square.grid.2x2")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                RootTabNavigationTitle("Settings")
            }
        }
        .themedForm()
        .task { await refreshReminderSchedulingState() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshReminderSchedulingState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await refreshReminderSchedulingState() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task { await refreshReminderSchedulingState() }
        }
        .alert("Email Copied", isPresented: Binding(
            get: { copiedEmailMessage != nil },
            set: { if !$0 { copiedEmailMessage = nil } }
        )) {
            Button("OK", role: .cancel) { copiedEmailMessage = nil }
        } message: {
            Text(copiedEmailMessage ?? "")
        }
        .alert(item: $helpTopic) { topic in
            Alert(
                title: Text(topic.title),
                message: Text(topic.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var dailyBinding: Binding<Bool> {
        Binding(get: { dailyEnabled }, set: { enabled in
            dailyEnabled = enabled
            applyDailyPreference(enabled: enabled, hour: dailyHour, minute: dailyMinute)
        })
    }

    private var monthEndBinding: Binding<Bool> {
        Binding(get: { monthEndEnabled }, set: { enabled in
            monthEndEnabled = enabled
            applyMonthEndPreference(enabled: enabled, hour: monthEndHour, minute: monthEndMinute)
        })
    }

    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>, action: @escaping () -> Void) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: hour.wrappedValue, minute: minute.wrappedValue)) ?? Date()
            },
            set: { date in
                hour.wrappedValue = Calendar.current.component(.hour, from: date)
                minute.wrappedValue = Calendar.current.component(.minute, from: date)
                action()
            }
        )
    }

    private func reconcileDaily() {
        applyDailyPreference(enabled: dailyEnabled, hour: dailyHour, minute: dailyMinute)
    }

    private func reconcileMonthEnd() {
        applyMonthEndPreference(enabled: monthEndEnabled, hour: monthEndHour, minute: monthEndMinute)
    }

    private func applyDailyPreference(enabled: Bool, hour: Int, minute: Int) {
        Task {
            do {
                try await ReminderService.shared.setDailyEnabled(enabled, hour: hour, minute: minute)
                reminderErrorMessage = nil
            } catch {
                reminderErrorMessage = AppLocalization.string("Could not schedule the reminder. Your preference was saved; try again.")
            }
            authorizationStatus = await ReminderService.shared.authorizationStatus()
        }
    }

    private func applyMonthEndPreference(enabled: Bool, hour: Int, minute: Int) {
        Task {
            do {
                try await ReminderService.shared.setMonthEndEnabled(enabled, hour: hour, minute: minute)
                reminderErrorMessage = nil
            } catch {
                reminderErrorMessage = AppLocalization.string("Could not schedule the reminder. Your preference was saved; try again.")
            }
            authorizationStatus = await ReminderService.shared.authorizationStatus()
        }
    }

    private func retryReminderScheduling() {
        Task {
            await refreshReminderSchedulingState()
        }
    }

    private func refreshReminderSchedulingState() async {
        do {
            try await ReminderService.shared.reconcileFromPreferences()
            reminderErrorMessage = nil
        } catch {
            reminderErrorMessage = AppLocalization.string("Could not schedule the reminder. Your preference was saved; try again.")
        }
        authorizationStatus = await ReminderService.shared.authorizationStatus()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func openSupportEmail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: AppLocalization.string("MiniBill Support"))
        ]

        guard let url = components.url else {
            copySupportEmail()
            return
        }

        UIApplication.shared.open(url) { success in
            guard !success else { return }
            DispatchQueue.main.async { copySupportEmail() }
        }
    }

    private func copySupportEmail() {
        UIPasteboard.general.string = supportEmail
        copiedEmailMessage = String(format: AppLocalization.string("Email copied: %@"), supportEmail)
    }

    private func openAppStoreRating() {
        guard let appStoreReviewURL else { return }
        UIApplication.shared.open(appStoreReviewURL) { success in
            if !success, let appStoreWebReviewURL {
                UIApplication.shared.open(appStoreWebReviewURL)
            }
        }
    }

    private func openMoreApps() {
        guard let moreAppsURL else { return }
        UIApplication.shared.open(moreAppsURL)
    }

}

private struct LanguageSelectionView: View {
    @Binding var languageCode: String

    private var selectedLanguage: AppLanguage {
        AppLanguage(storedCode: languageCode)
    }

    var body: some View {
        List(AppLanguage.allCases) { language in
            Button {
                languageCode = language.rawValue
            } label: {
                HStack {
                    Text(verbatim: language.displayName)
                    Spacer()
                    if language.rawValue == languageCode {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(language.rawValue == languageCode ? .isSelected : [])
        }
        .navigationTitle(AppLocalization.string("Language", language: selectedLanguage))
        .themedForm()
    }
}

private struct AboutView: View {
    let appVersion: String

    var body: some View {
        List {
            VStack(spacing: 12) {
                AppBrandIcon(size: 96, cornerRadius: 20)
                Text("MiniBill").font(.title2.bold())
                Text("Offline bookkeeping for small businesses and side work.")
                    .foregroundStyle(AppTheme.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

            Section {
                AboutParagraph("Simple offline bills, effortless bookkeeping for small business")
                AboutParagraph("Offline bookkeeping for small businesses and side work.")
            }

            Section("Bills") {
                AboutFeatureBlock(
                    title: "Add Entry",
                    detail: "Tap Add Entry to record income or expense."
                )
            }

            Section("Statistics") {
                AboutFeatureBlock(
                    title: "Income and Expense by Type",
                    detail: "Monthly Income and Expense"
                )
            }

            Section("Backup") {
                AboutFeatureBlock(
                    title: "Backup Entries",
                    detail: "Restore replaces the entire local ledger. It does not merge entries."
                )
            }

            Section("Reminders") {
                AboutParagraph("MiniBill schedules reminders on this device. Delivery can be affected by system notification settings, Focus, or power state.")
            }

            Section("Privacy") {
                AboutParagraph("MiniBill stores ledger entries only on this device. It has no account, analytics, advertising, cloud sync, or network dependency.")
            }

            Section("App") {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("About MiniBill")
        .themedForm()
    }
}

private struct AboutParagraph: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(AppTheme.ink)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AboutFeatureBlock: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Text(detail)
                .font(.body)
                .foregroundStyle(AppTheme.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

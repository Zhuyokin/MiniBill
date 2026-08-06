import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]

    @AppStorage(ReminderPreferenceKey.dailyEnabled) private var dailyEnabled = false
    @AppStorage(ReminderPreferenceKey.dailyHour) private var dailyHour = 20
    @AppStorage(ReminderPreferenceKey.dailyMinute) private var dailyMinute = 0
    @AppStorage(ReminderPreferenceKey.monthEndEnabled) private var monthEndEnabled = false
    @AppStorage(ReminderPreferenceKey.monthEndHour) private var monthEndHour = 21
    @AppStorage(ReminderPreferenceKey.monthEndMinute) private var monthEndMinute = 0
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.simplifiedChinese.rawValue

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var exportedDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var restorePreview: RestorePreview?
    @State private var errorMessage: String?
    @State private var reminderErrorMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text("\(entries.count)")
                } label: {
                    Label("Local Entries", systemImage: "tray.full")
                }
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
                Text("Reminders")
            } footer: {
                Text("MiniBill schedules reminders on this device. Delivery can be affected by system notification settings, Focus, or power state.")
            }

            Section {
                Button { prepareExport() } label: { Label("Export Backup", systemImage: "arrow.up.doc") }
                Button { showImporter = true } label: { Label("Restore from Backup", systemImage: "arrow.down.doc") }
            } header: {
                Text("Backup")
            } footer: {
                Text("Backups are not encrypted. Save them only in a location you trust.")
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
                NavigationLink { PrivacyView() } label: {
                    Label("Privacy", systemImage: "hand.raised")
                }
                NavigationLink { AboutView() } label: {
                    Label("About MiniBill", systemImage: "info.circle")
                }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Me")
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
        .fileExporter(
            isPresented: $showExporter,
            document: exportedDocument,
            contentType: .miniBillBackup,
            defaultFilename: "\(BackupService.filename()).minibill"
        ) { result in
            if case .failure(let error) = result, !isCancellation(error) {
                errorMessage = AppLocalization.string("Export failed. Choose another location or try again.")
            }
            exportedDocument = nil
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.miniBillBackup]) { result in
            importBackup(result)
        }
        .sheet(item: $restorePreview) { preview in
            RestorePreviewView(
                preview: preview,
                onExportCurrent: prepareExport,
                onRestore: { try BackupService.replace(with: preview.archive, in: modelContext) }
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

    private func prepareExport() {
        do {
            exportedDocument = try BackupService.document(entries: entries)
            showExporter = true
        } catch {
            errorMessage = AppLocalization.string("Export failed. Choose another location or try again.")
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                restorePreview = try BackupService.preview(data: Data(contentsOf: url), currentRecordCount: entries.count)
            } catch let error as BackupValidationError {
                switch error {
                case .schemaTooNew: errorMessage = AppLocalization.string("This backup needs a newer version of MiniBill. Your ledger was not changed.")
                default: errorMessage = AppLocalization.string("This backup is damaged or invalid. Your ledger was not changed.")
                }
            } catch {
                errorMessage = AppLocalization.string("This backup could not be read. Your ledger was not changed.")
            }
        case .failure(let error):
            if !isCancellation(error) { errorMessage = AppLocalization.string("This backup could not be read. Your ledger was not changed.") }
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        (error as NSError).code == NSUserCancelledError
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

}

private struct LanguageSelectionView: View {
    @Binding var languageCode: String

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
        .navigationTitle("Language")
    }
}

private struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                Text("MiniBill stores ledger entries only on this device. It has no account, analytics, advertising, cloud sync, or network dependency.")
                Text("Share images are generated locally and never include notes. Backup files are not encrypted.")
                Text("Deleting MiniBill removes its local ledger and scheduled notifications from this device.")
            }
        }
        .navigationTitle("Privacy")
    }
}

private struct AboutView: View {
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
        }
        .navigationTitle("About MiniBill")
    }
}

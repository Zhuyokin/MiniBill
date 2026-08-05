import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]

    @AppStorage(ReminderPreferenceKey.dailyEnabled) private var dailyEnabled = false
    @AppStorage(ReminderPreferenceKey.dailyHour) private var dailyHour = 20
    @AppStorage(ReminderPreferenceKey.dailyMinute) private var dailyMinute = 0
    @AppStorage(ReminderPreferenceKey.monthEndEnabled) private var monthEndEnabled = false
    @AppStorage(ReminderPreferenceKey.monthEndHour) private var monthEndHour = 21
    @AppStorage(ReminderPreferenceKey.monthEndMinute) private var monthEndMinute = 0

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var exportedDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var restorePreview: RestorePreview?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Local Entries", value: "\(entries.count)")
            }

            Section {
                Toggle("Daily Reminder", isOn: dailyBinding)
                if dailyEnabled {
                    DatePicker("Daily Time", selection: timeBinding(hour: $dailyHour, minute: $dailyMinute, action: reconcileDaily), displayedComponents: .hourAndMinute)
                }
                Toggle("Month-end Reminder", isOn: monthEndBinding)
                if monthEndEnabled {
                    DatePicker("Month-end Time", selection: timeBinding(hour: $monthEndHour, minute: $monthEndMinute, action: reconcileMonthEnd), displayedComponents: .hourAndMinute)
                }
                if authorizationStatus == .denied {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System notifications are off. Your reminder preference is preserved.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Button("Open System Settings") { openSystemSettings() }
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("MiniBill schedules reminders on this device. Delivery can be affected by system notification settings, Focus, or power state.")
            }

            Section {
                Button { prepareExport() } label: { Label("Export Backup", systemImage: "square.and.arrow.up") }
                Button { showImporter = true } label: { Label("Restore from Backup", systemImage: "square.and.arrow.down") }
            } header: {
                Text("Backup")
            } footer: {
                Text("Backups are not encrypted. Save them only in a location you trust.")
            }

            Section("App") {
                Button { openAppLanguageSettings() } label: {
                    LabeledContent("Language", value: String(localized: "System App Language"))
                }
                NavigationLink("Privacy") { PrivacyView() }
                NavigationLink("About MiniBill") { AboutView() }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Me")
        .task { authorizationStatus = await ReminderService.shared.authorizationStatus() }
        .fileExporter(
            isPresented: $showExporter,
            document: exportedDocument,
            contentType: .miniBillBackup,
            defaultFilename: "\(BackupService.filename()).minibill"
        ) { result in
            if case .failure(let error) = result, !isCancellation(error) {
                errorMessage = String(localized: "Export failed. Choose another location or try again.")
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
            Task {
                await ReminderService.shared.setDailyEnabled(enabled, hour: dailyHour, minute: dailyMinute)
                authorizationStatus = await ReminderService.shared.authorizationStatus()
            }
        })
    }

    private var monthEndBinding: Binding<Bool> {
        Binding(get: { monthEndEnabled }, set: { enabled in
            monthEndEnabled = enabled
            Task {
                await ReminderService.shared.setMonthEndEnabled(enabled, hour: monthEndHour, minute: monthEndMinute)
                authorizationStatus = await ReminderService.shared.authorizationStatus()
            }
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
        Task { await ReminderService.shared.setDailyEnabled(dailyEnabled, hour: dailyHour, minute: dailyMinute) }
    }

    private func reconcileMonthEnd() {
        Task { await ReminderService.shared.setMonthEndEnabled(monthEndEnabled, hour: monthEndHour, minute: monthEndMinute) }
    }

    private func prepareExport() {
        do {
            exportedDocument = try BackupService.document(entries: entries)
            showExporter = true
        } catch {
            errorMessage = String(localized: "Export failed. Choose another location or try again.")
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
                case .schemaTooNew: errorMessage = String(localized: "This backup needs a newer version of MiniBill. Your ledger was not changed.")
                default: errorMessage = String(localized: "This backup is damaged or invalid. Your ledger was not changed.")
                }
            } catch {
                errorMessage = String(localized: "This backup could not be read. Your ledger was not changed.")
            }
        case .failure(let error):
            if !isCancellation(error) { errorMessage = String(localized: "This backup could not be read. Your ledger was not changed.") }
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        (error as NSError).code == NSUserCancelledError
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func openAppLanguageSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
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
                Image(systemName: "book.closed.fill").font(.system(size: 48)).foregroundStyle(AppTheme.brand)
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

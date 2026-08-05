import SwiftUI
import UIKit

struct RestorePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: RestorePreview
    let onExportCurrent: () -> Void
    let onRestore: () throws -> Void

    @State private var confirmReplace = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Backup") {
                    LabeledContent("Exported", value: preview.archive.exportedAt.formatted())
                    LabeledContent("Backup Entries", value: "\(preview.archive.recordCount)")
                    if let earliest = preview.earliestDate, let latest = preview.latestDate {
                        LabeledContent("Date Range", value: "\(earliest.formatted(date: .abbreviated, time: .omitted)) – \(latest.formatted(date: .abbreviated, time: .omitted))")
                    } else {
                        Text("This backup is empty. Restoring it will erase every current entry.")
                            .foregroundStyle(AppTheme.destructive)
                    }
                }
                Section("Current Ledger") {
                    LabeledContent("Current Entries", value: "\(preview.currentRecordCount)")
                    Button("Export Current Ledger First", action: onExportCurrent)
                }
                Section {
                    Button("Replace and Restore", role: .destructive) { confirmReplace = true }
                } footer: {
                    Text("Restore replaces the entire local ledger. It does not merge entries.")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Restore Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .confirmationDialog("Replace the current ledger?", isPresented: $confirmReplace, titleVisibility: .visible) {
                Button("Replace and Restore", role: .destructive) {
                    do {
                        try onRestore()
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        dismiss()
                    } catch {
                        errorMessage = String(localized: "Restore failed. Your original ledger was not changed.")
                    }
                }
            }
        }
    }
}

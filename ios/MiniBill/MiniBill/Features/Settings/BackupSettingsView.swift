import SwiftUI
import SwiftData

struct BackupSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedAccountID: UUID

    @State private var exportedDocument: BackupDocument?
    @State private var exportFormat: BackupFileFormat = .json
    @State private var importFormat: BackupFileFormat = .json
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var restorePreview: RestorePreview?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button { prepareExport(.json) } label: {
                    Label("Export JSON", systemImage: "arrow.up.doc")
                }
                Button { prepareImport(.json) } label: {
                    Label("Import JSON", systemImage: "arrow.down.doc")
                }
            } header: {
                Text(verbatim: "JSON")
            }

            Section {
                Button { prepareExport(.csv) } label: {
                    Label("Export CSV", systemImage: "arrow.up.doc")
                }
                Button { prepareImport(.csv) } label: {
                    Label("Import CSV", systemImage: "arrow.down.doc")
                }
            } header: {
                Text(verbatim: "CSV")
            } footer: {
                Text("Backups are not encrypted. Save them only in a location you trust.")
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .themedForm()
        .fileExporter(
            isPresented: $showExporter,
            document: exportedDocument,
            contentType: exportFormat.contentType,
            defaultFilename: "\(BackupService.filename()).\(exportFormat.rawValue)"
        ) { result in
            if case .failure(let error) = result, !isCancellation(error) {
                errorMessage = AppLocalization.string("Export failed. Choose another location or try again.")
            }
            exportedDocument = nil
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: importFormat.importContentTypes, onCompletion: importBackup)
        .sheet(item: $restorePreview) { preview in
            RestorePreviewView(
                preview: preview,
                onExportCurrent: { try document(.json) },
                onRestore: {
                    try BackupService.replace(with: preview.archive, in: modelContext)
                    selectedAccountID = preview.archive.selectedAccountID
                }
            )
        }
    }

    private func document(_ format: BackupFileFormat) throws -> BackupDocument {
        let entries = try modelContext.fetch(FetchDescriptor<LedgerEntry>(
            sortBy: [SortDescriptor(\LedgerEntry.occurredAt, order: .reverse)]
        ))
        let accounts = try modelContext.fetch(FetchDescriptor<LedgerAccount>(
            sortBy: [SortDescriptor(\LedgerAccount.createdAt)]
        ))
        return try BackupService.document(entries: entries, accounts: accounts, selectedAccountID: selectedAccountID, format: format)
    }

    private func prepareExport(_ format: BackupFileFormat) {
        errorMessage = nil
        do {
            exportedDocument = try document(format)
            exportFormat = format
            showExporter = true
        } catch {
            errorMessage = AppLocalization.string("Export failed. Choose another location or try again.")
        }
    }

    private func prepareImport(_ format: BackupFileFormat) {
        errorMessage = nil
        importFormat = format
        showImporter = true
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                restorePreview = try BackupService.preview(
                    data: Data(contentsOf: url),
                    currentRecordCount: modelContext.fetchCount(FetchDescriptor<LedgerEntry>()),
                    format: importFormat
                )
            } catch let error as BackupValidationError {
                switch error {
                case .schemaTooNew: errorMessage = AppLocalization.string("This backup needs a newer version of MiniBill. Your ledger was not changed.")
                default: errorMessage = AppLocalization.string("This backup is damaged or invalid. Your ledger was not changed.")
                }
            } catch {
                errorMessage = AppLocalization.string("This backup could not be read. Your ledger was not changed.")
            }
        case .failure(let error):
            if !isCancellation(error) {
                errorMessage = AppLocalization.string("This backup could not be read. Your ledger was not changed.")
            }
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        (error as NSError).code == NSUserCancelledError
    }
}

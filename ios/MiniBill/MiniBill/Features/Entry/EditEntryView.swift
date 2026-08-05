import SwiftUI
import SwiftData
import UIKit

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: LedgerEntry

    @State private var amountText = ""
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @State private var shareRecord: LedgerRecord?

    var body: some View {
        Form {
            Picker("Type", selection: Binding(get: { entry.kind }, set: { entry.kind = $0 })) {
                Text("Income").tag(LedgerKind.income)
                Text("Expense").tag(LedgerKind.expense)
            }
            .pickerStyle(.segmented)

            Section("Amount") {
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.title2.bold())
            }
            Section("Project Name") {
                TextField("What was this for?", text: $entry.projectName)
            }
            Section("Note and Date") {
                TextField("Optional note", text: Binding(get: { entry.note ?? "" }, set: { entry.note = $0.isEmpty ? nil : $0 }), axis: .vertical)
                    .lineLimit(2...4)
                DatePicker("Date", selection: $entry.occurredAt)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
            Section {
                Button("Share Entry") { shareRecord = LedgerEntryMapper.record(from: entry) }
                Button("Delete Entry", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle("Entry Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { modelContext.rollback(); dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }
        .onAppear { amountText = AppFormat.amountInput(entry.amountCents) }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                do {
                    try modelContext.save()
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    dismiss()
                } catch {
                    modelContext.rollback()
                    errorMessage = String(localized: "Delete failed. The entry was not changed.")
                }
            }
        } message: {
            Text("Deleting it also updates statistics.")
        }
        .sheet(item: $shareRecord) { record in
            SharePreviewView(payload: .entry(EntrySharePayload(record: record)))
        }
    }

    private func save() {
        do {
            let cents = try EntryValidator.amountCents(from: amountText)
            try EntryValidator.validate(amountCents: cents, projectName: entry.projectName, note: entry.note)
            entry.amountCents = cents
            entry.projectName = entry.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.note = entry.note?.trimmingCharacters(in: .whitespacesAndNewlines)
            if entry.note?.isEmpty == true { entry.note = nil }
            entry.updatedAt = Date()
            try modelContext.save()
            dismiss()
        } catch let error as EntryValidationError {
            switch error {
            case .invalidAmount: errorMessage = String(localized: "Enter an amount greater than zero with at most two decimal places.")
            case .emptyProjectName: errorMessage = String(localized: "Project name is required.")
            case .noteTooLong: errorMessage = String(localized: "Note must be 200 characters or fewer.")
            }
        } catch {
            errorMessage = String(localized: "Could not save. Your changes are still here; try again.")
        }
    }
}

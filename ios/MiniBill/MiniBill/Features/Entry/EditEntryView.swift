import SwiftUI
import SwiftData
import UIKit

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @State private var originalRecord: LedgerRecord
    @State private var draft: EntryDraft
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @FocusState private var amountIsFocused: Bool

    init(record: LedgerRecord) {
        let value = EntryDraft(record: record)
        _originalRecord = State(initialValue: record)
        _draft = State(initialValue: value)
    }

    private var hasChanges: Bool { draft != EntryDraft(record: originalRecord) }

    var body: some View {
        Form {
            Picker("Type", selection: $draft.kind) {
                Text("Income").tag(LedgerKind.income)
                Text("Expense").tag(LedgerKind.expense)
            }
            .pickerStyle(.segmented)
            .tint(AppTheme.strongColor(for: draft.kind))

            Section("Amount") {
                TextField("0.00", text: $draft.amountText)
                    .keyboardType(.decimalPad)
                    .font(.title2.bold())
                    .themedInputWell()
                    .focused($amountIsFocused)
                    .onChange(of: draft.amountText) { _, value in
                        let limited = EntryValidator.limitedAmountText(
                            value,
                            decimalSeparator: locale.decimalSeparator ?? "."
                        )
                        if limited != value { draft.amountText = limited }
                    }
                    .onChange(of: amountIsFocused) { _, isFocused in
                        guard !isFocused else { return }
                        draft.amountText = EntryValidator.fixedAmountText(
                            draft.amountText,
                            decimalSeparator: locale.decimalSeparator ?? "."
                        )
                    }
            }
            Section("Project Name") {
                TextField("What was this for?", text: $draft.projectName)
                    .themedInputWell()
            }
            Section("Note and Date") {
                TextField("Optional note", text: $draft.note, axis: .vertical)
                    .lineLimit(2...4)
                    .themedInputWell()
                DatePicker("Date", selection: $draft.occurredAt)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.footnote)
            }
            Section {
                if let sharePayload {
                    ShareImageLink(
                        payload: .entry(sharePayload),
                        title: "Share Entry",
                        systemImage: "square.and.arrow.up",
                        colorOnlyInRetro: true
                    )
                } else {
                    Button(action: validateForSharing) {
                        Label("Share Entry", systemImage: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete Entry", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Entry Details")
        .themedForm()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasChanges { confirmDiscard = true } else { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }
        .interactiveDismissDisabled(hasChanges)
        .confirmationDialog("Discard your changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: deleteEntry)
        } message: {
            Text("Deleting it also updates statistics.")
        }
    }

    private var sharePayload: EntrySharePayload? {
        guard let record = try? draft.validatedRecord(
            updatedAt: originalRecord.updatedAt,
            decimalSeparator: locale.decimalSeparator ?? "."
        ) else { return nil }
        return EntrySharePayload(record: record)
    }

    private func save() {
        do {
            let record = try draft.validatedRecord(
                updatedAt: Date(),
                decimalSeparator: locale.decimalSeparator ?? "."
            )
            try LedgerMutationStore.apply(
                WatchLedgerMutation(ledgerID: UUID(), kind: .saveEntry, record: record, baseRecord: originalRecord),
                in: modelContext.container
            )
            dismiss()
        } catch is WatchSyncRejection {
            errorMessage = AppLocalization.string("The ledger changed while you were editing. Close this screen, review the latest entries and accounts, then try again.")
        } catch let error as EntryValidationError {
            switch error {
            case .invalidAmount: errorMessage = AppLocalization.string("Enter an amount greater than zero with at most two decimal places.")
            case .amountTooLarge: errorMessage = AppLocalization.string("Amount cannot exceed ¥99,999,999.99.")
            case .emptyProjectName: errorMessage = AppLocalization.string("Project name is required.")
            case .noteTooLong: errorMessage = AppLocalization.string("Note must be 200 characters or fewer.")
            }
        } catch {
            errorMessage = AppLocalization.string("Could not save. Your changes are still here; try again.")
        }
    }

    private func deleteEntry() {
        do {
            try LedgerMutationStore.apply(
                WatchLedgerMutation(ledgerID: UUID(), kind: .deleteEntry, record: originalRecord, baseRecord: originalRecord),
                in: modelContext.container
            )
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            dismiss()
        } catch is WatchSyncRejection {
            errorMessage = AppLocalization.string("The ledger changed while you were editing. Close this screen, review the latest entries and accounts, then try again.")
        } catch {
            errorMessage = AppLocalization.string("Delete failed. The entry was not changed.")
        }
    }

    private func validateForSharing() {
        do {
            _ = try draft.validatedRecord(
                updatedAt: originalRecord.updatedAt,
                decimalSeparator: locale.decimalSeparator ?? "."
            )
            errorMessage = nil
        } catch let error as EntryValidationError {
            switch error {
            case .invalidAmount: errorMessage = AppLocalization.string("Enter an amount greater than zero with at most two decimal places.")
            case .amountTooLarge: errorMessage = AppLocalization.string("Amount cannot exceed ¥99,999,999.99.")
            case .emptyProjectName: errorMessage = AppLocalization.string("Project name is required.")
            case .noteTooLong: errorMessage = AppLocalization.string("Note must be 200 characters or fewer.")
            }
        } catch {
            errorMessage = AppLocalization.string("Could not prepare this entry for sharing.")
        }
    }
}

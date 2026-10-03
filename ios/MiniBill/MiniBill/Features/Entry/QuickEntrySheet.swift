import SwiftUI
import SwiftData
import UIKit

struct QuickEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @State private var accountID: UUID
    @State private var candidates: [String]

    @State private var kind: LedgerKind = .income
    @State private var amountText = ""
    @State private var projectName = ""
    @State private var note = ""
    @State private var occurredAt = Date()
    @State private var showOptional = false
    @State private var validationMessage: String?
    @State private var isSaving = false
    @State private var showDiscardConfirmation = false
    @FocusState private var amountIsFocused: Bool

    init(accountID: UUID, candidates: [String], initialKind: LedgerKind = .income) {
        _kind = State(initialValue: initialKind)
        _accountID = State(initialValue: accountID)
        _candidates = State(initialValue: candidates)
    }

    private var hasInput: Bool {
        !amountText.isEmpty || !projectName.isEmpty || !note.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Income").tag(LedgerKind.income)
                    Text("Expense").tag(LedgerKind.expense)
                }
                .pickerStyle(.segmented)
                .tint(AppTheme.strongColor(for: kind))

                Section("Amount") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("Amount")
                        .themedInputWell()
                        .focused($amountIsFocused)
                        .onChange(of: amountText) { _, value in
                            let limited = EntryValidator.limitedAmountText(
                                value,
                                decimalSeparator: locale.decimalSeparator ?? "."
                            )
                            if limited != value { amountText = limited }
                        }
                        .onChange(of: amountIsFocused) { _, isFocused in
                            guard !isFocused else { return }
                            amountText = EntryValidator.fixedAmountText(
                                amountText,
                                decimalSeparator: locale.decimalSeparator ?? "."
                            )
                        }
                }

                Section("Project Name") {
                    TextField("What was this for?", text: $projectName)
                        .textInputAutocapitalization(.sentences)
                        .themedInputWell()
                    if !candidates.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(candidates, id: \.self) { candidate in
                                    Button(candidate) { projectName = candidate }
                                        .themedSecondaryButton(tint: AppTheme.brandDark)
                                }
                            }
                        }
                    }
                }

                DisclosureGroup("Note and Date", isExpanded: $showOptional) {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .themedInputWell()
                    DatePicker("Date", selection: $occurredAt)
                }

                if let validationMessage {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Button(action: save) {
                    HStack {
                        Spacer()
                        if isSaving { ProgressView().tint(.white) }
                        Text(isSaving ? "Saving…" : "Save")
                        Spacer()
                    }
                }
                .themedPrimaryButton(tint: AppTheme.brand, colorOnlyInRetro: true)
                .disabled(isSaving)
            }
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasInput { showDiscardConfirmation = true } else { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(hasInput)
            .confirmationDialog("Discard this entry?", isPresented: $showDiscardConfirmation) {
                Button("Discard", role: .destructive) { dismiss() }
            }
            .themedForm()
        }
    }

    private func save() {
        validationMessage = nil
        do {
            let cents = try EntryValidator.amountCents(
                from: amountText,
                decimalSeparator: locale.decimalSeparator ?? "."
            )
            let trimmedProject = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            try EntryValidator.validate(
                amountCents: cents,
                projectName: trimmedProject,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            isSaving = true
            let now = Date()
            let record = LedgerRecord(
                id: UUID(),
                accountID: accountID,
                kind: kind,
                amountCents: cents,
                projectName: trimmedProject,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                occurredAt: occurredAt,
                createdAt: now,
                updatedAt: now
            )
            try LedgerMutationStore.apply(
                WatchLedgerMutation(ledgerID: UUID(), kind: .saveEntry, record: record),
                in: modelContext.container
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch is WatchSyncRejection {
            isSaving = false
            validationMessage = AppLocalization.string("The ledger changed while you were editing. Close this screen, review the latest entries and accounts, then try again.")
        } catch let error as EntryValidationError {
            isSaving = false
            switch error {
            case .invalidAmount: validationMessage = AppLocalization.string("Enter an amount greater than zero with at most two decimal places.")
            case .amountTooLarge: validationMessage = AppLocalization.string("Amount cannot exceed ¥99,999,999.99.")
            case .emptyProjectName: validationMessage = AppLocalization.string("Project name is required.")
            case .noteTooLong: validationMessage = AppLocalization.string("Note must be 200 characters or fewer.")
            }
        } catch {
            isSaving = false
            validationMessage = AppLocalization.string("Could not save. Your input is still here; try again.")
        }
    }
}

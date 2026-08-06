import SwiftUI
import SwiftData
import UIKit

struct QuickEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let candidates: [String]

    @State private var kind: LedgerKind = .income
    @State private var amountText = ""
    @State private var projectName = ""
    @State private var note = ""
    @State private var occurredAt = Date()
    @State private var showOptional = false
    @State private var validationMessage: String?
    @State private var isSaving = false
    @State private var showDiscardConfirmation = false
    @FocusState private var amountFocused: Bool

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
                        .focused($amountFocused)
                        .accessibilityLabel("Amount")
                }

                Section("Project Name") {
                    TextField("What was this for?", text: $projectName)
                        .textInputAutocapitalization(.sentences)
                    if !candidates.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(candidates, id: \.self) { candidate in
                                    Button(candidate) { projectName = candidate }
                                        .buttonStyle(.bordered)
                                        .tint(AppTheme.brandDark)
                                }
                            }
                        }
                    }
                }

                DisclosureGroup("Note and Date", isExpanded: $showOptional) {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
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
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brand)
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
            .onAppear { amountFocused = true }
        }
    }

    private func save() {
        validationMessage = nil
        var insertedEntry: LedgerEntry?
        do {
            let cents = try EntryValidator.amountCents(from: amountText)
            let trimmedProject = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            try EntryValidator.validate(
                amountCents: cents,
                projectName: trimmedProject,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            isSaving = true
            let now = Date()
            let entry = LedgerEntry(
                kindRawValue: kind.rawValue,
                amountCents: cents,
                projectName: trimmedProject,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                occurredAt: occurredAt,
                createdAt: now,
                updatedAt: now
            )
            insertedEntry = entry
            modelContext.insert(entry)
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch let error as EntryValidationError {
            isSaving = false
            switch error {
            case .invalidAmount: validationMessage = AppLocalization.string("Enter an amount greater than zero with at most two decimal places.")
            case .amountTooLarge: validationMessage = AppLocalization.string("Amount cannot exceed ¥99,999,999.99.")
            case .emptyProjectName: validationMessage = AppLocalization.string("Project name is required.")
            case .noteTooLong: validationMessage = AppLocalization.string("Note must be 200 characters or fewer.")
            }
        } catch {
            if let insertedEntry {
                modelContext.delete(insertedEntry)
            }
            modelContext.rollback()
            isSaving = false
            validationMessage = AppLocalization.string("Could not save. Your input is still here; try again.")
        }
    }
}

import SwiftUI

struct WatchEntryEditor: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @Environment(\.dismiss) private var dismiss
    let accountID: UUID
    let original: LedgerRecord?
    private let initialDraft: EntryDraft
    private let decimalSeparator: String
    @State private var draft: EntryDraft
    @State private var errorMessage: String?
    @State private var confirmDiscard = false
    @State private var confirmDelete = false

    init(accountID: UUID, language: AppLanguage, record: LedgerRecord? = nil) {
        self.accountID = accountID
        original = record
        decimalSeparator = language.locale.decimalSeparator ?? "."
        let now = Date()
        let initial = record ?? LedgerRecord(
            id: UUID(), accountID: accountID, kind: .income, amountCents: 0,
            projectName: "", note: nil, occurredAt: now, createdAt: now, updatedAt: now
        )
        var value = EntryDraft(record: initial, decimalSeparator: decimalSeparator)
        if record == nil { value.amountText = "" }
        initialDraft = value
        _draft = State(initialValue: value)
    }

    private var strings: WatchStrings { WatchStrings(language: store.language) }
    private var hasChanges: Bool { draft != initialDraft }
    private var candidates: [String] {
        ProjectSuggestionService.candidates(
            from: LedgerRecordFilter.records(forAccountID: accountID, from: store.records)
        )
    }

    var body: some View {
        Form {
            Picker(strings("Type"), selection: $draft.kind) {
                Text(strings("Income")).tag(LedgerKind.income)
                Text(strings("Expense")).tag(LedgerKind.expense)
            }
            .tint(WatchFormat.color(draft.kind))
            Section(strings("Amount")) {
                NavigationLink {
                    WatchAmountPad(amount: $draft.amountText, decimalSeparator: decimalSeparator)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CNY").font(.caption2).foregroundStyle(.secondary)
                        Text(draft.amountText.isEmpty ? "0\(decimalSeparator)00" : draft.amountText)
                            .font(.title3.bold()).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .foregroundStyle(WatchFormat.color(draft.kind))
                    }
                }
            }
            Section(strings("Project Name")) {
                TextField(strings("What was this for?"), text: $draft.projectName)
                if !candidates.isEmpty {
                    NavigationLink {
                        WatchProjectSuggestions(projectName: $draft.projectName, candidates: candidates)
                    } label: {
                        Label(strings("Recent projects"), systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            Section(strings("Note and Date")) {
                TextField(strings("Optional note"), text: $draft.note)
                Text("\(draft.note.count)/200").font(.caption2)
                    .foregroundStyle(draft.note.count > 200 ? .red : .secondary)
                NavigationLink {
                    WatchDateEditor(date: $draft.occurredAt)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(strings("Date")).font(.caption2).foregroundStyle(.secondary)
                        Text(WatchFormat.dateTime(draft.occurredAt, language: store.language))
                            .font(.caption)
                    }
                }
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            Button(strings("Save"), action: save)
                .tint(.green).disabled(!store.hasSnapshot)
            if original != nil {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label(strings("Delete Entry"), systemImage: "trash")
                }
            }
        }
        .navigationTitle(strings(original == nil ? "Add Entry" : "Entry Details"))
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(strings("Cancel")) {
                    if hasChanges { confirmDiscard = true } else { dismiss() }
                }
            }
        }
        .interactiveDismissDisabled(hasChanges)
        .confirmationDialog(strings("Discard your changes?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button(strings("Discard"), role: .destructive) { dismiss() }
            Button(strings("Cancel"), role: .cancel) {}
        }
        .confirmationDialog(strings("Delete this entry?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(strings("Delete"), role: .destructive, action: delete)
            Button(strings("Cancel"), role: .cancel) {}
        } message: {
            Text(strings("Deleting it also updates statistics."))
        }
    }

    private func save() {
        do {
            let record = try draft.validatedRecord(decimalSeparator: decimalSeparator)
            try store.saveEntry(record, replacing: original)
            dismiss()
        } catch {
            errorMessage = WatchFormat.validationMessage(error, language: store.language)
        }
    }

    private func delete() {
        guard let original else { return }
        do {
            try store.deleteEntry(original)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? strings("Delete failed. The entry was not changed.")
        }
    }
}

private struct WatchProjectSuggestions: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @Environment(\.dismiss) private var dismiss
    @Binding var projectName: String
    let candidates: [String]

    var body: some View {
        List(candidates, id: \.self) { candidate in
            Button(candidate) {
                projectName = candidate
                dismiss()
            }
        }
        .navigationTitle(WatchStrings(language: store.language)("Recent projects"))
    }
}

private struct WatchAmountPad: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @Environment(\.dismiss) private var dismiss
    @Binding var amount: String
    let decimalSeparator: String
    private let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    private var strings: WatchStrings { WatchStrings(language: store.language) }

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                Text(amount.isEmpty ? "0\(decimalSeparator)00" : amount)
                    .font(.title2.bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.35)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel(strings("Amount"))
                    .accessibilityValue(amount)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                    ForEach(digits, id: \.self) { digit in
                        key(digit) { append(digit) }
                    }
                    key(decimalSeparator) { append(decimalSeparator) }
                    key("0") { append("0") }
                    Button {
                        if !amount.isEmpty { amount.removeLast() }
                    } label: {
                        Image(systemName: "delete.left").frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .accessibilityLabel(strings("Delete digit"))
                }
                HStack {
                    Button(strings("Clear")) { amount = "" }
                    Button(strings("Done")) {
                        amount = EntryValidator.fixedAmountText(amount, decimalSeparator: decimalSeparator)
                        dismiss()
                    }
                    .tint(.green)
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 3)
        }
        .navigationTitle(strings("Amount"))
        .onDisappear {
            amount = EntryValidator.fixedAmountText(amount, decimalSeparator: decimalSeparator)
        }
    }

    private func key(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.title3).frame(maxWidth: .infinity, minHeight: 30)
        }
    }

    private func append(_ value: String) {
        amount = EntryValidator.limitedAmountText(amount + value, decimalSeparator: decimalSeparator)
    }
}

private struct WatchDateEditor: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @Binding var date: Date
    private var strings: WatchStrings { WatchStrings(language: store.language) }
    private let fields: [(Calendar.Component, String)] = [
        (.year, "Year"), (.month, "Month"), (.day, "Day"), (.hour, "Hour"), (.minute, "Minute")
    ]

    var body: some View {
        List {
            Text(WatchFormat.dateTime(date, language: store.language)).font(.caption)
            ForEach(fields, id: \.0) { field in
                NavigationLink {
                    WatchDateComponentPicker(date: $date, component: field.0, title: field.1)
                } label: {
                    HStack {
                        Text(strings(field.1))
                        Spacer()
                        Text(Calendar.current.component(field.0, from: date).formatted(.number.grouping(.never)))
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
            Button(strings("Now")) { date = Date() }
        }
        .navigationTitle(strings("Date"))
    }
}

private struct WatchDateComponentPicker: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date
    let component: Calendar.Component
    let title: String
    @State private var selection: Int = 0
    @State private var values: [Int] = []
    private var strings: WatchStrings { WatchStrings(language: store.language) }

    var body: some View {
        VStack {
            Picker(strings(title), selection: $selection) {
                ForEach(values, id: \.self) { value in
                    Text(value.formatted(.number.grouping(.never))).tag(value)
                }
            }
            .labelsHidden()
            Button(strings("Done")) {
                applySelection()
                dismiss()
            }
        }
        .navigationTitle(strings(title))
        .onAppear {
            selection = Calendar.current.component(component, from: date)
            switch component {
            case .year: values = Array(max(1, selection - 100)...(selection + 100))
            case .month: values = Array(Calendar.current.range(of: .month, in: .year, for: date) ?? 1..<13)
            case .day: values = Array(Calendar.current.range(of: .day, in: .month, for: date) ?? 1..<32)
            case .hour: values = Array(0..<24)
            default: values = Array(0..<60)
            }
        }
    }

    private func applySelection() {
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute], from: date)
        parts.setValue(selection, for: component)
        let selectedDay = parts.day ?? 1
        parts.day = 1
        guard let firstDay = calendar.date(from: parts),
              let days = calendar.range(of: .day, in: .month, for: firstDay) else { return }
        parts.day = min(selectedDay, days.count)
        if let updated = calendar.date(from: parts) { date = updated }
    }
}

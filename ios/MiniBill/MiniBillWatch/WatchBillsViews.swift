import SwiftUI

struct WatchBillsView: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @State private var month: Date
    @State private var editingEntry: LedgerRecord?
    private var strings: WatchStrings { WatchStrings(language: store.language) }

    init(month: Date = Date()) {
        _month = State(initialValue: month)
    }

    private var summary: MonthlySummary {
        LedgerAnalytics.summary(records: store.selectedRecords, month: month, calendar: .current)
    }

    private var records: [LedgerRecord] {
        WatchEntrySelection.month(month).records(from: store.selectedRecords)
    }

    var body: some View {
        List {
            WatchPeriodNavigator(date: $month, language: store.language)
            NavigationLink { WatchReportsView(month: month) } label: {
                WatchTotalsView(income: summary.incomeCents, expense: summary.expenseCents,
                                net: summary.netCents, count: summary.recordCount, language: store.language)
            }
            WatchEntrySections(records: records, editingEntry: $editingEntry, language: store.language)
        }
        .navigationTitle(strings("Bills"))
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                WatchEntryEditor(accountID: entry.accountID, language: store.language, record: entry)
            }
        }
    }
}

enum WatchEntrySelection {
    case day(Date)
    case month(Date)
    case project(ProjectTotal, LedgerKind, Date)
    case kind(LedgerKind, Date)

    func records(from records: [LedgerRecord]) -> [LedgerRecord] {
        switch self {
        case .day(let date):
            return LedgerRecordFilter.records(on: date, from: records, calendar: .current)
        case .project(let project, let kind, let month):
            return LedgerRecordFilter.records(forProjectKey: project.normalizedKey, kind: kind,
                                              inMonth: month, from: records, calendar: .current)
        case .month(let month):
            return monthRecords(month, from: records)
        case .kind(let kind, let month):
            return monthRecords(month, from: records).filter { $0.kind == kind }
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .day(let date): return WatchFormat.date(date, language: language)
        case .month(let month): return WatchFormat.month(month, language: language)
        case .project(let project, _, _): return project.displayName
        case .kind(let kind, _): return WatchStrings(language: language)(kind == .income ? "Income" : "Expense")
        }
    }

    private func monthRecords(_ month: Date, from records: [LedgerRecord]) -> [LedgerRecord] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return [] }
        return records.filter { interval.start <= $0.occurredAt && $0.occurredAt < interval.end }
            .sorted {
                $0.occurredAt == $1.occurredAt ? $0.id.uuidString < $1.id.uuidString : $0.occurredAt > $1.occurredAt
            }
    }
}

struct WatchFilteredEntriesView: View {
    @EnvironmentObject private var store: WatchLedgerStore
    let selection: WatchEntrySelection
    @State private var editingEntry: LedgerRecord?
    private var records: [LedgerRecord] { selection.records(from: store.selectedRecords) }

    var body: some View {
        List {
            let income = WatchFormat.sum(records.filter { $0.kind == .income }.map(\.amountCents))
            let expense = WatchFormat.sum(records.filter { $0.kind == .expense }.map(\.amountCents))
            WatchTotalsView(income: income, expense: expense, net: income - expense,
                            count: records.count, language: store.language)
            WatchEntrySections(records: records, editingEntry: $editingEntry, language: store.language)
        }
        .navigationTitle(selection.title(language: store.language))
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                WatchEntryEditor(accountID: entry.accountID, language: store.language, record: entry)
            }
        }
    }
}

private struct WatchEntrySections: View {
    let records: [LedgerRecord]
    @Binding var editingEntry: LedgerRecord?
    let language: AppLanguage

    private var days: [Date] {
        Set(records.map { Calendar.current.startOfDay(for: $0.occurredAt) }).sorted(by: >)
    }

    var body: some View {
        if records.isEmpty {
            Text(WatchStrings(language: language)("No matching entries"))
                .font(.caption).foregroundStyle(.secondary)
        } else {
            ForEach(days, id: \.self) { day in
                Section(WatchFormat.date(day, language: language)) {
                    ForEach(LedgerRecordFilter.records(on: day, from: records, calendar: .current)) { record in
                        Button { editingEntry = record } label: {
                            WatchEntryRow(record: record, language: language)
                        }
                    }
                }
            }
        }
    }
}

struct WatchEntryRow: View {
    let record: LedgerRecord
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.projectName).font(.headline).lineLimit(2)
            Text(WatchFormat.money(record.kind == .income ? record.amountCents : -record.amountCents,
                                   language: language, signed: true))
                .font(.headline).monospacedDigit().foregroundStyle(WatchFormat.color(record.kind))
                .lineLimit(1).minimumScaleFactor(0.5)
            HStack {
                Text(WatchStrings(language: language)(record.kind == .income ? "Income" : "Expense"))
                Text(WatchFormat.time(record.occurredAt, language: language))
            }
            .font(.caption2).foregroundStyle(.secondary)
            if let note = record.note, !note.isEmpty {
                Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

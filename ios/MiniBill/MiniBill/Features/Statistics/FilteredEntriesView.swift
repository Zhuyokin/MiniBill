import SwiftUI
import SwiftData

enum StatisticsDrilldown {
    case day(Date)
    case project(month: Date, kind: LedgerKind, normalizedKey: String, displayName: String)

    var title: String {
        switch self {
        case .day(let date):
            return AppFormat.shortDate(date)
        case .project(_, _, _, let displayName):
            return displayName
        }
    }

    func records(from records: [LedgerRecord], calendar: Calendar) -> [LedgerRecord] {
        switch self {
        case .day(let date):
            return LedgerRecordFilter.records(on: date, from: records, calendar: calendar)
        case .project(let month, let kind, let normalizedKey, _):
            return LedgerRecordFilter.records(
                forProjectKey: normalizedKey,
                kind: kind,
                inMonth: month,
                from: records,
                calendar: calendar
            )
        }
    }
}

struct FilteredEntriesView: View {
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @State private var editingEntry: LedgerEntry?
    @State private var editEntryDetent: PresentationDetent = .medium

    let selection: StatisticsDrilldown
    let accountID: UUID

    private var filteredEntries: [LedgerEntry] {
        let entriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let records = selection.records(
            from: entries
                .filter { $0.resolvedAccountID == accountID }
                .map(LedgerEntryMapper.record),
            calendar: .current
        )
        return records.compactMap { entriesByID[$0.id] }
    }

    var body: some View {
        List {
            if filteredEntries.isEmpty {
                ContentUnavailableView(
                    "No matching entries",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .frame(maxWidth: .infinity, minHeight: 240)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(filteredEntries) { entry in
                        Button {
                            editEntryDetent = .medium
                            editingEntry = entry
                        } label: {
                            LedgerRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(AppTheme.surface)
                    }
                } header: {
                    Text("\(filteredEntries.count) entries")
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(selection.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingEntry) { entry in
            NavigationStack { EditEntryView(entry: entry) }
                .presentationDetents([.medium, .large], selection: $editEntryDetent)
                .presentationDragIndicator(.visible)
        }
    }
}

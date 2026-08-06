import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @Binding var showQuickEntry: Bool
    let onOpenStatistics: (Date) -> Void
    @State private var editingEntry: LedgerEntry?
    @State private var pendingDelete: LedgerEntry?
    @State private var deletionError: String?

    private var records: [LedgerRecord] { entries.map(LedgerEntryMapper.record) }
    private var summary: MonthlySummary {
        LedgerAnalytics.summary(records: records, month: Date(), calendar: .current)
    }
    private var groupedDays: [(Date, [LedgerEntry])] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.occurredAt) }
            .sorted { $0.key > $1.key }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                Button { onOpenStatistics(Date()) } label: {
                    MonthlySummaryCard(summary: summary)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens monthly statistics")
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if entries.isEmpty {
                    ContentUnavailableView("No entries yet", systemImage: "doc.text.magnifyingglass", description: Text("Tap Add Entry to record income or expense."))
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(groupedDays, id: \.0) { day, items in
                        Section {
                            ForEach(items) { entry in
                                Button { editingEntry = entry } label: {
                                    LedgerRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowBackground(AppTheme.surface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { pendingDelete = entry } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(Calendar.current.isDateInToday(day) ? AppLocalization.string("Today") : AppFormat.shortDate(day))
                                .font(.headline)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 72, for: .scrollContent)

            Button { showQuickEntry = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.brand, in: Circle())
                    .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
            }
            .accessibilityLabel("Add Entry")
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle("MiniBill")
        .sheet(isPresented: $showQuickEntry) {
            QuickEntrySheet(candidates: ProjectSuggestionService.candidates(from: records))
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack { EditEntryView(entry: entry) }
        }
        .confirmationDialog("Delete this entry?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let entry = pendingDelete else { return }
                modelContext.delete(entry)
                do {
                    try modelContext.save()
                    pendingDelete = nil
                } catch {
                    modelContext.rollback()
                    pendingDelete = nil
                    deletionError = AppLocalization.string("Delete failed. The entry was not changed.")
                }
            }
        } message: {
            Text("Deleting it also updates statistics.")
        }
        .alert("Could not delete entry", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "")
        }
    }
}

import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @Binding var showQuickEntry: Bool
    let onOpenStatistics: (Date) -> Void
    @State private var editingEntry: LedgerEntry?
    @State private var pendingDelete: LedgerEntry?

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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Button { onOpenStatistics(Date()) } label: {
                        MonthlySummaryCard(summary: summary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens monthly statistics")

                    if entries.isEmpty {
                        ContentUnavailableView("No entries yet", systemImage: "tray", description: Text("Tap Add Entry to record income or expense."))
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        ForEach(groupedDays, id: \.0) { day, items in
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(items) { entry in
                                        Button { editingEntry = entry } label: {
                                            LedgerRow(entry: entry)
                                        }
                                        .buttonStyle(.plain)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) { pendingDelete = entry } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        if entry.id != items.last?.id { Divider().padding(.leading, 60) }
                                    }
                                }
                                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                            } header: {
                                Text(Calendar.current.isDateInToday(day) ? String(localized: "Today") : day.formatted(date: .abbreviated, time: .omitted))
                                    .font(.headline)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 72)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }

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
                try? modelContext.save()
                pendingDelete = nil
            }
        } message: {
            Text("Deleting it also updates statistics.")
        }
    }
}

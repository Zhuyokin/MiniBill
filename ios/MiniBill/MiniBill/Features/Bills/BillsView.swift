import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var language
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @Binding var showQuickEntry: Bool
    @Binding var selectedAccountID: UUID
    let onOpenStatistics: (Date) -> Void
    @State private var editingEntry: LedgerEntry?
    @State private var pendingDelete: LedgerEntry?
    @State private var deletionError: String?
    @State private var quickEntryDetent: PresentationDetent = .medium
    @State private var editEntryDetent: PresentationDetent = .medium

    private var selectedEntries: [LedgerEntry] {
        entries.filter { $0.resolvedAccountID == selectedAccountID }
    }
    private var records: [LedgerRecord] { selectedEntries.map(LedgerEntryMapper.record) }
    private var summary: MonthlySummary {
        LedgerAnalytics.summary(records: records, month: Date(), calendar: .current)
    }
    private var groupedDays: [(Date, [LedgerEntry])] {
        Dictionary(grouping: selectedEntries) { Calendar.current.startOfDay(for: $0.occurredAt) }
            .sorted { $0.key > $1.key }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                Button { onOpenStatistics(Date()) } label: {
                    MonthlySummaryCard(summary: summary, showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens monthly statistics")
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if selectedEntries.isEmpty {
                    ContentUnavailableView("No entries yet", systemImage: "doc.text.magnifyingglass", description: Text("Tap Add Entry to record income or expense."))
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(groupedDays, id: \.0) { day, items in
                        Section {
                            ForEach(items) { entry in
                                Button {
                                    editEntryDetent = .medium
                                    editingEntry = entry
                                } label: {
                                    LedgerRow(entry: entry)
                                        .themedPanel(cornerRadius: 10)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { pendingDelete = entry } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(
                                Calendar.current.isDateInToday(day)
                                    ? AppLocalization.string("Today", language: language)
                                    : AppFormat.shortDate(day, locale: language.locale)
                            )
                                .font(.headline)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 72, for: .scrollContent)

            Button {
                quickEntryDetent = .medium
                showQuickEntry = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background { ThemedFloatingButtonBackground() }
            }
            .accessibilityLabel("Add Entry")
            .padding(20)
        }
        .themedScreen()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showQuickEntry) {
            QuickEntrySheet(accountID: selectedAccountID, candidates: ProjectSuggestionService.candidates(from: records))
                .presentationDetents([.medium, .large], selection: $quickEntryDetent)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack { EditEntryView(entry: entry) }
                .presentationDetents([.medium, .large], selection: $editEntryDetent)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showQuickEntry) { _, isPresented in
            if isPresented { quickEntryDetent = .medium }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                RootTabNavigationTitle("MiniBill")
            }
            ToolbarItem(placement: .topBarTrailing) {
                AccountSwitcher(selectedAccountID: $selectedAccountID)
            }
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

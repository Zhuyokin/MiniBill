import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var language
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @Binding var showQuickEntry: Bool
    @Binding var selectedAccountID: UUID
    let onOpenStatistics: (Date) -> Void
    @State private var editingEntry: LedgerRecord?
    @State private var pendingDelete: LedgerRecord?
    @State private var deletionError: String?
    @State private var quickEntryDetent: PresentationDetent = .medium
    @State private var editEntryDetent: PresentationDetent = .medium
    @State private var selectedMonth = Calendar.current.startOfDay(for: Date())
    @State private var showMonthPicker = false

    private var selectedEntries: [LedgerEntry] {
        entries.filter { $0.resolvedAccountID == selectedAccountID }
    }
    private var records: [LedgerRecord] { selectedEntries.map(LedgerEntryMapper.record) }
    private var summary: MonthlySummary {
        LedgerAnalytics.summary(records: records, month: selectedMonth, calendar: .current)
    }
    private var monthRecords: [LedgerRecord] {
        LedgerRecordFilter.records(inMonth: selectedMonth, from: records, calendar: .current)
    }
    private var groupedDays: [(Date, [LedgerRecord])] {
        Dictionary(grouping: monthRecords) { Calendar.current.startOfDay(for: $0.occurredAt) }
            .sorted { $0.key > $1.key }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                Section {
                    monthNavigator
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    Button { onOpenStatistics(selectedMonth) } label: {
                        MonthlySummaryCard(summary: summary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens monthly statistics")
                    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                if monthRecords.isEmpty {
                    ContentUnavailableView("No entries this month", systemImage: "doc.text.magnifyingglass", description: Text("Tap Add Entry to record income or expense."))
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
                                    LedgerRow(record: entry)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                                .themedListRowBackground()
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { pendingDelete = entry } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            dayHeader(day)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 6, for: .scrollContent)
            .contentMargins(.horizontal, 16, for: .scrollContent)
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
        .ledgerScreen()
        .rootTabHeader()
        .sheet(isPresented: $showMonthPicker) {
            BillMonthPicker(selectedMonth: $selectedMonth)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQuickEntry) {
            QuickEntrySheet(accountID: selectedAccountID, candidates: ProjectSuggestionService.candidates(from: records))
                .presentationDetents([.medium, .large], selection: $quickEntryDetent)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack { EditEntryView(record: entry) }
                .presentationDetents([.medium, .large], selection: $editEntryDetent)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showQuickEntry) { _, isPresented in
            if isPresented { quickEntryDetent = .medium }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountSwitcher(selectedAccountID: $selectedAccountID)
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard let entry = pendingDelete else { return }
                do {
                    try LedgerMutationStore.apply(
                        WatchLedgerMutation(ledgerID: UUID(), kind: .deleteEntry, record: entry, baseRecord: entry),
                        in: modelContext.container
                    )
                    pendingDelete = nil
                } catch is WatchSyncRejection {
                    pendingDelete = nil
                    deletionError = AppLocalization.string("The ledger changed while you were editing. Close this screen, review the latest entries and accounts, then try again.")
                } catch {
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

    private var monthNavigator: some View {
        HStack(spacing: 12) {
            Button { moveMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 40)
                    .background(AppTheme.muted.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Previous month")

            Button { showMonthPicker = true } label: {
                HStack(spacing: 8) {
                    Text(AppFormat.month(selectedMonth, locale: language.locale))
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Image(systemName: "chevron.down").font(.caption.bold())
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityLabel("Select month")
            .accessibilityValue(AppFormat.month(selectedMonth, locale: language.locale))

            Button { moveMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 40, height: 40)
                    .background(AppTheme.muted.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Next month")

            Button("This month") { selectedMonth = Date() }
                .font(.subheadline.weight(.medium))
                .fixedSize()
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(AppTheme.muted.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .foregroundStyle(AppTheme.ink)
        .buttonStyle(.plain)
    }

    private func moveMonth(_ offset: Int) {
        guard let start = Calendar.current.dateInterval(of: .month, for: selectedMonth)?.start,
              let month = Calendar.current.date(byAdding: .month, value: offset, to: start) else { return }
        selectedMonth = month
    }

    private func dayHeader(_ day: Date) -> some View {
        let net = summary.dailyNet.first(where: { $0.date == day })?.netCents ?? 0
        return HStack(alignment: .firstTextBaseline) {
            Text(day.formatted(.dateTime.month().day().weekday(.abbreviated).locale(language.locale)))
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                Text("Net Profit").foregroundStyle(AppTheme.muted)
                Text(AppFormat.money(net, signed: true, locale: language.locale))
                    .foregroundStyle(AppTheme.strongColor(for: net >= 0 ? .income : .expense))
            }
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .textCase(nil)
        .padding(.bottom, 4)
        .listRowInsets(EdgeInsets(top: 0, leading: 2, bottom: 8, trailing: 2))
    }
}

private struct BillMonthPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @Binding var selectedMonth: Date
    @State private var year = Calendar.current.component(.year, from: Date())

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack {
                    Button { year -= 1 } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Previous year")
                    Spacer()
                    Text(String(year)).font(.title2.bold()).monospacedDigit()
                    Spacer()
                    Button { year += 1 } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Next year")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                    ForEach(1...12, id: \.self) { month in
                        if let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) {
                            let isSelected = Calendar.current.isDate(date, equalTo: selectedMonth, toGranularity: .month)
                            Button {
                                selectedMonth = date
                                dismiss()
                            } label: {
                                Text(date.formatted(.dateTime.month(.abbreviated).locale(language.locale)))
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(isSelected ? AppTheme.brandSoft : AppTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .themedScreen()
            .navigationTitle("Select month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { year = Calendar.current.component(.year, from: selectedMonth) }
    }
}

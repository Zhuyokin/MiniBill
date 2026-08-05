import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @State private var selectedMonth: Date
    @State private var sharingSummary: MonthlySummary?

    init(initialMonth: Date) {
        _selectedMonth = State(initialValue: initialMonth)
    }

    private var summary: MonthlySummary {
        LedgerAnalytics.summary(records: entries.map(LedgerEntryMapper.record), month: selectedMonth, calendar: .current)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    Spacer()
                    Text(AppFormat.month(selectedMonth)).font(.headline)
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                }

                MonthlySummaryCard(summary: summary)

                HStack {
                    Label("\(summary.recordCount) entries", systemImage: "number")
                        .font(.subheadline)
                    Spacer()
                    Button { sharingSummary = summary } label: { Label("Share Month", systemImage: "square.and.arrow.up") }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Net").font(.headline)
                    DailyNetChart(values: summary.dailyNet)
                }
                .padding(16)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                ProjectRankingView(
                    title: "Income Projects",
                    totals: summary.incomeProjects,
                    tint: AppTheme.brand,
                    month: summary.month,
                    kind: .income
                )
                ProjectRankingView(
                    title: "Expense Projects",
                    totals: summary.expenseProjects,
                    tint: AppTheme.ink,
                    month: summary.month,
                    kind: .expense
                )
            }
            .padding(16)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.background)
        .navigationTitle("Statistics")
        .sheet(item: $sharingSummary) { value in
            SharePreviewView(payload: .month(MonthlySharePayload(summary: value)))
        }
    }

    private func moveMonth(_ value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = next
        }
    }
}

private struct DailyNetChart: View {
    let values: [DailyTotal]

    var body: some View {
        if values.isEmpty {
            Text("No entries this month")
                .foregroundStyle(AppTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 100)
        } else {
            GeometryReader { proxy in
                let maximum = max(values.map { abs($0.netCents) }.max() ?? 1, 1)
                HStack(alignment: .center, spacing: 4) {
                    ForEach(values) { item in
                        NavigationLink {
                            FilteredEntriesView(selection: .day(item.date))
                        } label: {
                            VStack(spacing: 3) {
                                Spacer(minLength: 0)
                                Capsule()
                                    .fill(item.netCents >= 0 ? AppTheme.brand : AppTheme.ink)
                                    .frame(height: max(4, CGFloat(abs(item.netCents)) / CGFloat(maximum) * (proxy.size.height - 24)))
                                Text(item.date.formatted(.dateTime.day()))
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppTheme.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(item.date.formatted(date: .abbreviated, time: .omitted)), \(AppFormat.money(item.netCents, signed: true))")
                        .accessibilityHint("Shows entries for this day")
                    }
                }
            }
            .frame(height: 150)
        }
    }
}

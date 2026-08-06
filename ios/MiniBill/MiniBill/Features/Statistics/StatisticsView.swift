import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @State private var selectedMonth: Date

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
                    Label("\(summary.recordCount) entries", systemImage: "doc.plaintext")
                        .font(.subheadline)
                    Spacer()
                    ShareImageLink(
                        payload: .month(MonthlySharePayload(summary: summary)),
                        title: "Share Month",
                        systemImage: "square.and.arrow.up"
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Net").font(.headline)
                    DailyNetChart(values: summary.dailyNet, month: summary.month)
                }
                .padding(16)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))

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
    }

    private func moveMonth(_ value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = next
        }
    }
}

private struct DailyNetChart: View {
    let values: [DailyTotal]
    let month: Date
    @State private var selectedDay: Date?

    var body: some View {
        if values.isEmpty {
            Text("No entries this month")
                .foregroundStyle(AppTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 100)
        } else if let interval = StatisticsChartScale.monthInterval(containing: month, calendar: .current) {
            let yDomain = StatisticsChartScale.symmetricYDomain(values: values.map(\.netCents))
            Chart {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(AppTheme.muted.opacity(0.45))

                ForEach(values) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        yStart: .value("Zero", 0),
                        yEnd: .value("Net", Double(item.netCents)),
                        width: .fixed(9)
                    )
                    .foregroundStyle(item.netCents >= 0 ? AppTheme.brand : AppTheme.ink)
                    .accessibilityLabel(AppFormat.shortDate(item.date))
                    .accessibilityValue(AppFormat.money(item.netCents, signed: true))

                    if item.netCents == 0 {
                        PointMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Net", 0)
                        )
                        .symbolSize(24)
                        .foregroundStyle(AppTheme.muted)
                    }
                }
            }
            .chartXScale(domain: interval.start...interval.end)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisTick().foregroundStyle(AppTheme.muted.opacity(0.5))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(AppFormat.day(date))
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture().onEnded { event in
                                selectDay(at: event.location, proxy: proxy, geometry: geometry)
                            }
                        )
                }
            }
            .frame(height: 180)
            .accessibilityHint("Shows entries for this day")
            .navigationDestination(item: $selectedDay) { date in
                FilteredEntriesView(selection: .day(date))
            }
        }
    }

    private func selectDay(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        guard frame.contains(location),
              let date: Date = proxy.value(atX: location.x - frame.origin.x),
              let value = values.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return
        }
        selectedDay = value.date
    }
}

import SwiftUI
import SwiftData
import Charts

private enum StatisticsChartMode: String, CaseIterable, Identifiable {
    case month
    case year
    case type

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .month: return "Month"
        case .year: return "Year"
        case .type: return "Type"
        }
    }
}

struct StatisticsView: View {
    @Environment(\.appLanguage) private var language
    @Query(sort: \LedgerEntry.occurredAt, order: .reverse) private var entries: [LedgerEntry]
    @Binding private var selectedMonth: Date
    @Binding private var selectedAccountID: UUID
    @State private var chartMode: StatisticsChartMode = .month

    init(selectedMonth: Binding<Date>, selectedAccountID: Binding<UUID>) {
        _selectedMonth = selectedMonth
        _selectedAccountID = selectedAccountID
    }

    private var records: [LedgerRecord] {
        entries
            .filter { $0.resolvedAccountID == selectedAccountID }
            .map(LedgerEntryMapper.record)
    }

    private var summary: MonthlySummary {
        LedgerAnalytics.summary(records: records, month: selectedMonth, calendar: .current)
    }

    private var yearlyTotals: [MonthlyLedgerTotal] {
        LedgerAnalytics.yearlyTotals(records: records, year: selectedMonth, calendar: .current)
    }

    private var kindTotals: [LedgerKindTotal] {
        LedgerAnalytics.kindTotals(records: records, month: selectedMonth, calendar: .current)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Chart View", selection: $chartMode) {
                    ForEach(StatisticsChartMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                periodNavigator

                if chartMode == .year {
                    YearSummaryCard(values: yearlyTotals)
                    YearlyChart(values: yearlyTotals)
                } else {
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

                    if chartMode == .month {
                        DailyNetChart(values: summary.dailyNet, month: summary.month, accountID: selectedAccountID)
                    } else {
                        KindDistributionChart(values: kindTotals)
                    }

                    ProjectRankingView(
                        title: "Income Projects",
                        totals: summary.incomeProjects,
                        tint: AppTheme.income,
                        month: summary.month,
                        kind: .income,
                        accountID: selectedAccountID
                    )
                    ProjectRankingView(
                        title: "Expense Projects",
                        totals: summary.expenseProjects,
                        tint: AppTheme.expense,
                        month: summary.month,
                        kind: .expense,
                        accountID: selectedAccountID
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .themedScreen()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                RootTabNavigationTitle("Statistics")
            }
            ToolbarItem(placement: .topBarTrailing) {
                AccountSwitcher(selectedAccountID: $selectedAccountID)
            }
        }
    }

    private var periodNavigator: some View {
        HStack {
            Button { movePeriod(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            Spacer()
            Text(periodTitle).font(.headline)
            Spacer()
            Button { movePeriod(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
        }
    }

    private var periodTitle: String {
        if chartMode == .year {
            return selectedMonth.formatted(.dateTime.year().locale(language.locale))
        }
        return AppFormat.month(selectedMonth, locale: language.locale)
    }

    private func movePeriod(_ value: Int) {
        let component: Calendar.Component = chartMode == .year ? .year : .month
        if let next = Calendar.current.date(byAdding: component, value: value, to: selectedMonth) {
            selectedMonth = next
        }
    }
}

private struct DailyNetChart: View {
    @Environment(\.appLanguage) private var language
    let values: [DailyTotal]
    let month: Date
    let accountID: UUID
    @State private var selectedDay: Date?

    var body: some View {
        chartCard(title: "Daily Net") {
            if values.isEmpty {
                emptyState("No entries this month")
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
                        .foregroundStyle(item.netCents >= 0 ? AppTheme.income : AppTheme.expense)
                        .accessibilityLabel(AppFormat.shortDate(item.date, locale: language.locale))
                        .accessibilityValue(AppFormat.money(item.netCents, signed: true, locale: language.locale))

                        if item.netCents == 0 {
                            PointMark(x: .value("Date", item.date, unit: .day), y: .value("Net", 0))
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
                                Text(AppFormat.day(date, locale: language.locale))
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
                            .gesture(SpatialTapGesture().onEnded { event in
                                selectDay(at: event.location, proxy: proxy, geometry: geometry)
                            })
                    }
                }
                .frame(height: 180)
                .accessibilityHint("Shows entries for this day")
                .navigationDestination(item: $selectedDay) { date in
                    FilteredEntriesView(selection: .day(date), accountID: accountID)
                }
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

private struct YearlyChart: View {
    let values: [MonthlyLedgerTotal]

    var body: some View {
        chartCard(title: "Monthly Income and Expense") {
            Chart {
                ForEach(values) { item in
                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value("Amount", Double(item.incomeCents))
                    )
                    .position(by: .value("Type", "Income"))
                    .foregroundStyle(by: .value("Type", "Income"))

                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value("Amount", Double(item.expenseCents))
                    )
                    .position(by: .value("Type", "Expense"))
                    .foregroundStyle(by: .value("Type", "Expense"))
                }
            }
            .chartForegroundStyleScale(["Income": AppTheme.income, "Expense": AppTheme.expense])
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisValueLabel(format: .dateTime.month(.narrow))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 220)
        }
    }
}

private struct KindDistributionChart: View {
    @Environment(\.appLanguage) private var language
    let values: [LedgerKindTotal]

    private var hasData: Bool { values.contains { $0.totalCents > 0 } }

    var body: some View {
        chartCard(title: "Income and Expense by Type") {
            if hasData {
                Chart(values) { item in
                    SectorMark(
                        angle: .value("Amount", Double(item.totalCents)),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(AppTheme.color(for: item.kind))
                    .cornerRadius(5)
                }
                .frame(height: 210)

                HStack(spacing: 20) {
                    ForEach(values) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Label {
                                Text(item.kind == .income ? "Income" : "Expense")
                            } icon: {
                                Circle().fill(AppTheme.color(for: item.kind)).frame(width: 8, height: 8)
                            }
                            .font(.caption)
                            Text(AppFormat.money(item.totalCents, locale: language.locale))
                                .font(.subheadline.bold())
                                .monospacedDigit()
                            Text("\(item.recordCount) entries")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                emptyState("No entries this month")
            }
        }
    }
}

private struct YearSummaryCard: View {
    @Environment(\.appLanguage) private var language
    let values: [MonthlyLedgerTotal]

    private var income: Int64 { clampedSum(values.map(\.incomeCents)) }
    private var expense: Int64 { clampedSum(values.map(\.expenseCents)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Year Summary").font(.headline)
            HStack {
                metric("Income", value: income, color: AppTheme.incomeStrong)
                metric("Expense", value: expense, color: AppTheme.expenseStrong)
            }
            Label("\(values.map(\.recordCount).reduce(0, +)) entries", systemImage: "doc.plaintext")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(16)
        .themedPanel(cornerRadius: 8)
    }

    private func metric(_ title: LocalizedStringKey, value: Int64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(AppTheme.muted)
            Text(AppFormat.money(value, locale: language.locale))
                .font(.title3.bold())
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clampedSum(_ values: [Int64]) -> Int64 {
        values.reduce(0) { partial, value in
            let (result, overflow) = partial.addingReportingOverflow(value)
            return overflow ? Int64.max : result
        }
    }
}

private func chartCard<Content: View>(
    title: LocalizedStringKey,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text(title).font(.headline)
            Spacer()
            chartLegend("Income", color: AppTheme.income)
            chartLegend("Expense", color: AppTheme.expense)
        }
        content()
    }
    .padding(16)
    .themedPanel(cornerRadius: 8)
}

private func chartLegend(_ title: LocalizedStringKey, color: Color) -> some View {
    HStack(spacing: 5) {
        Circle().fill(color).frame(width: 7, height: 7)
        Text(title)
    }
    .font(.caption)
    .foregroundStyle(AppTheme.muted)
}

private func emptyState(_ title: LocalizedStringKey) -> some View {
    Text(title)
        .foregroundStyle(AppTheme.muted)
        .frame(maxWidth: .infinity, minHeight: 120)
}

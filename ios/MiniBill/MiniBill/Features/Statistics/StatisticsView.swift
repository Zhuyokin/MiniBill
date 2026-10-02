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

    private var yearSummary: YearlySharePayload {
        YearlySharePayload(months: yearlyTotals, year: selectedMonth)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Chart View", selection: $chartMode) {
                    ForEach(StatisticsChartMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                periodNavigator

                if chartMode == .year {
                    YearSummaryCard(summary: yearSummary)
                    summaryActions
                    YearlyChart(values: yearlyTotals)
                    YearlyBreakdownCard(values: yearlyTotals)
                } else {
                    MonthlySummaryCard(summary: summary, artwork: chartMode == .type ? .rings : .leaves)
                    summaryActions

                    if chartMode == .month {
                        DailyNetChart(values: summary.dailyNet, month: summary.month)
                    } else {
                        KindDistributionChart(values: kindTotals)
                    }

                    ProjectRankingView(
                        title: "Income Projects",
                        totals: summary.incomeProjects,
                        tint: AppTheme.income
                    )
                    ProjectRankingView(
                        title: "Expense Projects",
                        totals: summary.expenseProjects,
                        tint: AppTheme.expense
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .ledgerScreen()
        .rootTabHeader()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountSwitcher(selectedAccountID: $selectedAccountID)
            }
        }
    }

    private var periodNavigator: some View {
        HStack {
            Button { movePeriod(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .background(AppTheme.muted.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel(chartMode == .year ? "Previous year" : "Previous month")
            Spacer()
            Text(periodTitle)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer()
            Button { movePeriod(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .background(AppTheme.muted.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel(chartMode == .year ? "Next year" : "Next month")
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.ink)
    }

    private var summaryActions: some View {
        HStack(spacing: 12) {
            Label("\(chartMode == .year ? yearSummary.recordCount : summary.recordCount) entries", systemImage: "doc.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
            Spacer(minLength: 0)
            if chartMode == .year {
                ShareImageLink(payload: .year(yearSummary), title: "Share Year", systemImage: "square.and.arrow.up")
            } else {
                ShareImageLink(payload: .month(MonthlySharePayload(summary: summary)), title: "Share Month", systemImage: "square.and.arrow.up")
            }
        }
        .font(.subheadline)
        .frame(minHeight: 44)
        .padding(.horizontal, 4)
    }

    private var periodTitle: String {
        if chartMode == .year {
            return selectedMonth.formatted(.dateTime.year().locale(language.locale))
        }
        return AppFormat.month(selectedMonth, locale: language.locale)
    }

    private func movePeriod(_ value: Int) {
        let component: Calendar.Component = chartMode == .year ? .year : .month
        let start = Calendar.current.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
        if let next = Calendar.current.date(byAdding: component, value: value, to: start) {
            selectedMonth = next
        }
    }
}

private struct DailyNetChart: View {
    @Environment(\.appLanguage) private var language
    let values: [DailyTotal]
    let month: Date

    var body: some View {
        chartCard(title: "Daily Net", systemImage: "chart.xyaxis.line", netLegend: true) {
            if values.isEmpty {
                emptyState("No entries this month")
            } else if let interval = StatisticsChartScale.monthInterval(containing: month, calendar: .current) {
                let centsDomain = StatisticsChartScale.symmetricYDomain(values: values.map(\.netCents))
                Chart {
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(AppTheme.muted.opacity(0.45))

                    ForEach(values) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            yStart: .value("Zero", 0),
                            yEnd: .value("Net", Double(item.netCents) / 100),
                            width: .fixed(9)
                        )
                        .foregroundStyle(item.netCents >= 0 ? AppTheme.income : AppTheme.expense)
                        .cornerRadius(3)
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
                .chartYScale(domain: (centsDomain.lowerBound / 100)...(centsDomain.upperBound / 100))
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
                .chartYAxis { amountAxis }
                .frame(height: 200)
            }
        }
    }
}

private struct YearlyChart: View {
    @Environment(\.appLanguage) private var language
    let values: [MonthlyLedgerTotal]

    var body: some View {
        chartCard(title: "Monthly Income and Expense", systemImage: "chart.bar.xaxis") {
            if values.allSatisfy({ $0.recordCount == 0 }) {
                emptyState("No entries this year")
            } else {
                Chart {
                    ForEach(values) { item in
                        BarMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Amount", Double(item.incomeCents) / 100)
                        )
                        .position(by: .value("Type", "Income"))
                        .foregroundStyle(by: .value("Type", "Income"))
                        .cornerRadius(3)
                        .accessibilityLabel(Text(item.month, format: .dateTime.month(.wide)) + Text(" · ") + Text("Income"))
                        .accessibilityValue(AppFormat.money(item.incomeCents, locale: language.locale))

                        BarMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Amount", Double(item.expenseCents) / 100)
                        )
                        .position(by: .value("Type", "Expense"))
                        .foregroundStyle(by: .value("Type", "Expense"))
                        .cornerRadius(3)
                        .accessibilityLabel(Text(item.month, format: .dateTime.month(.wide)) + Text(" · ") + Text("Expense"))
                        .accessibilityValue(AppFormat.money(item.expenseCents, locale: language.locale))
                    }
                }
                .chartForegroundStyleScale(["Income": AppTheme.income, "Expense": AppTheme.expense])
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: values.map(\.month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                    }
                }
                .chartYAxis { amountAxis }
                .frame(height: 220)
            }
        }
    }
}

private struct KindDistributionChart: View {
    @Environment(\.appLanguage) private var language
    let values: [LedgerKindTotal]

    private var hasData: Bool { values.contains { $0.totalCents > 0 } }

    var body: some View {
        chartCard(title: "Income and Expense by Type", systemImage: "chart.donut", showsAmountAxis: false) {
            if hasData {
                Chart(values) { item in
                    SectorMark(
                        angle: .value("Amount", Double(item.totalCents)),
                        innerRadius: .ratio(0.72),
                        angularInset: 3
                    )
                    .foregroundStyle(AppTheme.color(for: item.kind))
                    .cornerRadius(5)
                    .accessibilityLabel(item.kind == .income ? "Income" : "Expense")
                    .accessibilityValue(AppFormat.money(item.totalCents, locale: language.locale))
                }
                .chartBackground { _ in
                    VStack(spacing: 4) {
                        Text("\(values.reduce(0) { $0 + $1.recordCount })")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("Entries")
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    .accessibilityElement(children: .combine)
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
                                .foregroundStyle(AppTheme.strongColor(for: item.kind))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("\(item.recordCount) entries")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(AppTheme.color(for: item.kind).opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
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
    let summary: YearlySharePayload

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Yearly Net Profit")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.muted)
                Text(AppFormat.money(summary.netCents, locale: language.locale))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(summary.netCents >= 0 ? AppTheme.ink : AppTheme.destructive)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 16) {
                LedgerSummaryMetric(cents: summary.incomeCents, kind: .income)
                Divider().frame(height: 42)
                LedgerSummaryMetric(cents: summary.expenseCents, kind: .expense)
            }
            LedgerBalanceBar(income: summary.incomeCents, expense: summary.expenseCents)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { LedgerCardArtwork(motif: .bars) }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .themedPanel(cornerRadius: 22)
    }
}

private struct YearlyBreakdownCard: View {
    @Environment(\.appLanguage) private var language
    let values: [MonthlyLedgerTotal]

    private var activeMonths: [MonthlyLedgerTotal] {
        values.filter { $0.recordCount > 0 }.sorted { $0.month > $1.month }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label {
                Text("Monthly Breakdown")
            } icon: {
                Image(systemName: "list.bullet.rectangle").foregroundStyle(AppTheme.brand)
            }
            .font(.headline)

            if activeMonths.isEmpty {
                emptyState("No entries this year")
            } else {
                ForEach(Array(activeMonths.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().opacity(0.5) }
                    HStack(spacing: 12) {
                        Text(item.month.formatted(.dateTime.month(.abbreviated).locale(language.locale)))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))

                        VStack(alignment: .leading, spacing: 5) {
                            monthAmount("Income", cents: item.incomeCents, color: AppTheme.income)
                            monthAmount("Expense", cents: item.expenseCents, color: AppTheme.expense)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 5) {
                            Text(AppFormat.money(item.netCents, signed: true, locale: language.locale))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(item.netCents >= 0 ? AppTheme.incomeStrong : AppTheme.expenseStrong)
                            Text("\(item.recordCount) entries")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(20)
        .themedPanel(cornerRadius: 22)
    }

    private func monthAmount(_ title: LocalizedStringKey, cents: Int64, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(AppFormat.money(cents, locale: language.locale))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.caption)
        .foregroundStyle(AppTheme.muted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(AppFormat.money(cents, locale: language.locale))
    }
}

private func chartCard<Content: View>(
    title: LocalizedStringKey,
    systemImage: String,
    netLegend: Bool = false,
    showsAmountAxis: Bool = true,
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 18) {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(AppTheme.brand)
        }
        .font(.headline)

        HStack {
            if showsAmountAxis {
                Text("CNY").font(.caption2).foregroundStyle(AppTheme.muted)
            }
            Spacer()
            chartLegend(netLegend ? "Positive Net" : "Income", color: AppTheme.income)
            chartLegend(netLegend ? "Negative Net" : "Expense", color: AppTheme.expense)
        }
        content()
    }
    .padding(20)
    .themedPanel(cornerRadius: 22)
}

private var amountAxis: some AxisContent {
    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
        AxisGridLine().foregroundStyle(AppTheme.muted.opacity(0.1))
        AxisValueLabel {
            if let amount = value.as(Double.self) {
                Text(amount, format: .number.notation(.compactName))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
            }
        }
    }
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

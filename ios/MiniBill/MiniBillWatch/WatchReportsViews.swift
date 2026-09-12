import SwiftUI
import Charts

private enum WatchReportMode: String, CaseIterable, Identifiable {
    case month = "Month"
    case year = "Year"
    case type = "Type"
    var id: Self { self }
}

struct WatchReportsView: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @State private var month: Date
    @State private var mode: WatchReportMode = .month
    private var strings: WatchStrings { WatchStrings(language: store.language) }

    init(month: Date = Date()) { _month = State(initialValue: month) }

    private var summary: MonthlySummary {
        LedgerAnalytics.summary(records: store.selectedRecords, month: month, calendar: .current)
    }

    private var yearlyTotals: [MonthlyLedgerTotal] {
        LedgerAnalytics.yearlyTotals(records: store.selectedRecords, year: month, calendar: .current)
    }

    private var kindTotals: [LedgerKindTotal] {
        LedgerAnalytics.kindTotals(records: store.selectedRecords, month: month, calendar: .current)
    }

    var body: some View {
        List {
            Picker(strings("Chart View"), selection: $mode) {
                ForEach(WatchReportMode.allCases) { mode in
                    Text(strings(mode.rawValue)).tag(mode)
                }
            }
            WatchPeriodNavigator(date: $month, component: mode == .year ? .year : .month,
                                 language: store.language)
            if mode == .year {
                yearContent
            } else {
                WatchTotalsView(income: summary.incomeCents, expense: summary.expenseCents,
                                net: summary.netCents, count: summary.recordCount, language: store.language)
                if mode == .month {
                    monthContent
                } else {
                    typeContent
                }
                WatchProjectSection(title: "Income Projects", projects: summary.incomeProjects,
                                    kind: .income, month: month, language: store.language)
                WatchProjectSection(title: "Expense Projects", projects: summary.expenseProjects,
                                    kind: .expense, month: month, language: store.language)
            }
        }
        .navigationTitle(strings("Statistics"))
    }

    @ViewBuilder private var monthContent: some View {
        Section(strings("Daily Net")) {
            if summary.dailyNet.isEmpty {
                Text(strings("No entries this month")).font(.caption).foregroundStyle(.secondary)
            } else {
                WatchDailyChart(values: summary.dailyNet, month: month, language: store.language)
                ForEach(summary.dailyNet.reversed()) { day in
                    NavigationLink {
                        WatchFilteredEntriesView(selection: .day(day.date))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(WatchFormat.date(day.date, language: store.language)).font(.caption)
                            Text(WatchFormat.money(day.netCents, language: store.language, signed: true))
                                .font(.headline).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.5)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var typeContent: some View {
        Section(strings("Income and Expense by Type")) {
            if summary.recordCount == 0 {
                Text(strings("No entries this month")).font(.caption).foregroundStyle(.secondary)
            } else {
                WatchTypeChart(values: kindTotals, language: store.language)
                ForEach(kindTotals) { item in
                    NavigationLink {
                        WatchFilteredEntriesView(selection: .kind(item.kind, month))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(strings(item.kind == .income ? "Income" : "Expense")).font(.caption)
                            Text(WatchFormat.money(item.totalCents, language: store.language))
                                .font(.headline).monospacedDigit().foregroundStyle(WatchFormat.color(item.kind))
                                .lineLimit(1).minimumScaleFactor(0.5)
                            Text(strings.entries(item.recordCount)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var yearContent: some View {
        let values = yearlyTotals
        let income = WatchFormat.sum(values.map(\.incomeCents))
        let expense = WatchFormat.sum(values.map(\.expenseCents))
        WatchTotalsView(income: income, expense: expense, net: income - expense,
                        count: values.map(\.recordCount).reduce(0, +), language: store.language)
        Section(strings("Monthly Income and Expense")) {
            WatchYearChart(values: values, language: store.language)
            ForEach(values) { total in
                NavigationLink { WatchReportsView(month: total.month) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(total.month.formatted(.dateTime.month(.wide).locale(store.language.locale)))
                            .font(.headline)
                        Text(WatchFormat.money(total.netCents, language: store.language, signed: true))
                            .font(.caption).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                        Text(strings.entries(total.recordCount)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct WatchProjectSection: View {
    let title: String
    let projects: [ProjectTotal]
    let kind: LedgerKind
    let month: Date
    let language: AppLanguage

    var body: some View {
        let strings = WatchStrings(language: language)
        Section(strings(title)) {
            if projects.isEmpty {
                Text(strings("No project data")).font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(projects) { project in
                    NavigationLink {
                        WatchFilteredEntriesView(selection: .project(project, kind, month))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.displayName).font(.headline)
                            Text(WatchFormat.money(project.totalCents, language: language))
                                .font(.caption).monospacedDigit().foregroundStyle(WatchFormat.color(kind))
                                .lineLimit(1).minimumScaleFactor(0.5)
                            Text(strings.entries(project.recordCount)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct WatchDailyChart: View {
    let values: [DailyTotal]
    let month: Date
    let language: AppLanguage

    var body: some View {
        if let interval = Calendar.current.dateInterval(of: .month, for: month) {
            Chart {
                RuleMark(y: .value("Zero", 0)).foregroundStyle(.secondary)
                ForEach(values) { item in
                    BarMark(x: .value("Date", item.date, unit: .day),
                            y: .value("Net", Double(item.netCents) / 100))
                        .foregroundStyle(WatchFormat.color(item.netCents >= 0 ? .income : .expense))
                        .accessibilityLabel(WatchFormat.date(item.date, language: language))
                        .accessibilityValue(WatchFormat.money(item.netCents, language: language, signed: true))
                    if item.netCents == 0 {
                        PointMark(x: .value("Date", item.date, unit: .day), y: .value("Net", 0))
                            .foregroundStyle(.secondary).symbolSize(15)
                    }
                }
            }
            .chartXScale(domain: interval.start...interval.end)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 125)
        }
    }
}

private struct WatchYearChart: View {
    let values: [MonthlyLedgerTotal]
    let language: AppLanguage

    var body: some View {
        let strings = WatchStrings(language: language)
        Chart {
            ForEach(values) { item in
                BarMark(x: .value("Month", item.month, unit: .month),
                        y: .value("Amount", Double(item.incomeCents) / 100))
                    .position(by: .value("Type", strings("Income")))
                    .foregroundStyle(WatchFormat.color(.income))
                    .accessibilityLabel("\(WatchFormat.month(item.month, language: language)), \(strings("Income"))")
                    .accessibilityValue(WatchFormat.money(item.incomeCents, language: language))
                BarMark(x: .value("Month", item.month, unit: .month),
                        y: .value("Amount", Double(item.expenseCents) / 100))
                    .position(by: .value("Type", strings("Expense")))
                    .foregroundStyle(WatchFormat.color(.expense))
                    .accessibilityLabel("\(WatchFormat.month(item.month, language: language)), \(strings("Expense"))")
                    .accessibilityValue(WatchFormat.money(item.expenseCents, language: language))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 125)
    }
}

private struct WatchTypeChart: View {
    let values: [LedgerKindTotal]
    let language: AppLanguage

    var body: some View {
        Chart(values) { item in
            SectorMark(angle: .value("Amount", Double(item.totalCents) / 100),
                       innerRadius: .ratio(0.55), angularInset: 2)
                .foregroundStyle(WatchFormat.color(item.kind))
                .accessibilityLabel(WatchStrings(language: language)(item.kind == .income ? "Income" : "Expense"))
                .accessibilityValue(WatchFormat.money(item.totalCents, language: language))
        }
        .frame(height: 125)
    }
}

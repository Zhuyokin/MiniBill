import SwiftUI
import Charts

struct MonthlyShareCard: View {
    let payload: MonthlySharePayload
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            brandHeader
            VStack(alignment: .leading, spacing: 14) {
                Text(AppFormat.month(payload.month, locale: locale)).font(.system(size: 30, weight: .semibold)).foregroundStyle(.gray)
                Text("Net Profit").font(.system(size: 26, weight: .medium)).foregroundStyle(.gray)
                Text(AppFormat.money(payload.netCents, signed: true, locale: locale))
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .foregroundStyle(payload.netCents >= 0 ? AppTheme.brandDark : .black)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            HStack(spacing: 70) {
                shareMetric("Income", payload.incomeCents, sign: "+", color: AppTheme.brandDark)
                shareMetric("Expense", payload.expenseCents, sign: "−", color: .black)
                shareMetric("Entries", Int64(payload.recordCount * 100), sign: "", color: .black, isCount: true)
            }
            trend
            HStack(alignment: .top, spacing: 30) {
                topProject("Top Income", payload.topIncomeProject, color: AppTheme.brandDark)
                topProject("Top Expense", payload.topExpenseProject, color: .black)
            }
            Spacer()
            Text("Made locally with MiniBill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.gray)
        }
        .padding(72)
        .frame(width: 900, height: 1200, alignment: .topLeading)
        .background(Color.white)
    }

    private var brandHeader: some View {
        HStack {
            AppBrandIcon(size: 64, cornerRadius: 14)
            Text("MiniBill").font(.system(size: 32, weight: .bold)).foregroundStyle(.black)
            Spacer()
            Text("MONTHLY").font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
        }
    }

    private func shareMetric(_ title: LocalizedStringKey, _ cents: Int64, sign: String, color: Color, isCount: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 20)).foregroundStyle(.gray)
            Text(isCount ? "\(payload.recordCount)" : "\(sign)\(AppFormat.money(cents, locale: locale))")
                .font(.system(size: 30, weight: .bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Daily Net").font(.system(size: 24, weight: .semibold)).foregroundStyle(.black)
            if payload.dailyNet.isEmpty {
                Text("No entries this month")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else if let interval = StatisticsChartScale.monthInterval(containing: payload.month, calendar: .current) {
                let yDomain = StatisticsChartScale.symmetricYDomain(values: payload.dailyNet.map(\.netCents))
                Chart {
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(Color.gray.opacity(0.45))

                    ForEach(payload.dailyNet) { item in
                        BarMark(
                            x: .value("Date", item.date, unit: .day),
                            yStart: .value("Zero", 0),
                            yEnd: .value("Net", Double(item.netCents)),
                            width: .fixed(14)
                        )
                        .foregroundStyle(item.netCents >= 0 ? AppTheme.brand : Color.black)

                        if item.netCents == 0 {
                            PointMark(
                                x: .value("Date", item.date, unit: .day),
                                y: .value("Net", 0)
                            )
                            .symbolSize(34)
                            .foregroundStyle(Color.gray)
                        }
                    }
                }
                .chartXScale(domain: interval.start...interval.end)
                .chartYScale(domain: yDomain)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 180)
            }
        }
        .padding(26)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 20))
    }

    private func topProject(_ title: LocalizedStringKey, _ project: ProjectTotal?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 19)).foregroundStyle(.gray)
            Text(project?.displayName ?? "—").font(.system(size: 28, weight: .semibold)).foregroundStyle(.black).lineLimit(1)
            Text(project.map { AppFormat.money($0.totalCents, locale: locale) } ?? "—").font(.system(size: 24, weight: .bold)).foregroundStyle(color)
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 20))
    }
}

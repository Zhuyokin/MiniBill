import SwiftUI
import Charts

struct YearlyShareCard: View {
    let payload: YearlySharePayload
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            brandHeader
            yearlyBalance
            HStack(spacing: 16) {
                metric("Income", value: AppFormat.money(payload.incomeCents, locale: locale), color: AppTheme.incomeStrong, background: AppTheme.incomeSoft)
                metric("Expense", value: AppFormat.money(payload.expenseCents, locale: locale), color: AppTheme.expenseStrong, background: AppTheme.expenseSoft)
                metric("Entries", value: payload.recordCount.formatted(.number.locale(locale)), color: .black, background: .white.opacity(0.85))
            }
            monthlyTrend
            Spacer(minLength: 0)
            Text("Made locally with MiniBill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.gray)
        }
        .padding(64)
        .frame(width: 900, height: 1200, alignment: .topLeading)
        .background {
            LinearGradient(
                colors: [.white, AppTheme.expenseSoft.opacity(0.75), AppTheme.incomeSoft.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 18) {
            AppBrandIcon(size: 64, cornerRadius: 16)
            Text("MiniBill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.black)
            Spacer()
            Text("YEARLY")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.expenseStrong)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(AppTheme.expenseSoft, in: Capsule())
        }
    }

    private var yearlyBalance: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(payload.year.formatted(.dateTime.year().locale(locale)))
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.black.opacity(0.7))
            Text("Net Profit")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.gray)
            Text(AppFormat.money(payload.netCents, signed: true, locale: locale))
                .font(.system(size: 78, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(payload.netCents >= 0 ? Color.black : AppTheme.destructive)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private func metric(_ title: LocalizedStringKey, value: String, color: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.black.opacity(0.6))
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(background, in: RoundedRectangle(cornerRadius: 24))
    }

    private var monthlyTrend: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Monthly Income and Expense")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.black)

            HStack(spacing: 26) {
                legend("Income", color: AppTheme.income)
                legend("Expense", color: AppTheme.expense)
            }

            Chart {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.black.opacity(0.08))

                ForEach(payload.months) { month in
                    BarMark(
                        x: .value("Month", month.month, unit: .month),
                        y: .value("Amount", Double(month.incomeCents)),
                        width: .ratio(0.7)
                    )
                    .position(by: .value("Type", "Income"))
                    .foregroundStyle(AppTheme.income)
                    .cornerRadius(4)

                    BarMark(
                        x: .value("Month", month.month, unit: .month),
                        y: .value("Amount", Double(month.expenseCents)),
                        width: .ratio(0.7)
                    )
                    .position(by: .value("Type", "Expense"))
                    .foregroundStyle(AppTheme.expense)
                    .cornerRadius(4)
                }
            }
            .chartYScale(domain: 0...maximumChartAmount)
            .chartXAxis {
                AxisMarks(values: payload.months.map(\.month)) { value in
                    AxisValueLabel {
                        if let month = value.as(Date.self) {
                            Text(month.formatted(.dateTime.month(.narrow).locale(locale)))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 230)
        }
        .padding(30)
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 30))
    }

    private var maximumChartAmount: Double {
        let maximum = payload.months.reduce(0.0) {
            max($0, Double($1.incomeCents), Double($1.expenseCents))
        }
        return max(100, maximum * 1.12)
    }

    private func legend(_ title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title).font(.system(size: 19, weight: .medium))
        }
        .foregroundStyle(.gray)
    }
}

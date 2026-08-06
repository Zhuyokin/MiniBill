import SwiftUI

struct MonthlySummaryCard: View {
    let summary: MonthlySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(AppFormat.month(summary.month))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Image(systemName: "chevron.forward")
                    .foregroundStyle(AppTheme.muted)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Net Profit")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                Text(AppFormat.money(summary.netCents, signed: true))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(summary.netCents >= 0 ? AppTheme.brandDark : AppTheme.ink)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 32) {
                metric("Income", summary.incomeCents, color: AppTheme.brandDark, sign: "+")
                metric("Expense", summary.expenseCents, color: AppTheme.ink, sign: "−")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func metric(_ title: LocalizedStringKey, _ cents: Int64, color: Color, sign: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(AppTheme.muted)
            Text("\(sign)\(AppFormat.money(cents))")
                .font(.headline).monospacedDigit().foregroundStyle(color)
        }
    }
}

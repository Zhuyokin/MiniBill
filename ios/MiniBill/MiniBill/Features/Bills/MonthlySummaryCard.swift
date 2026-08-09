import SwiftUI

struct MonthlySummaryCard: View {
    let summary: MonthlySummary
    let showsChevron: Bool

    init(summary: MonthlySummary, showsChevron: Bool = false) {
        self.summary = summary
        self.showsChevron = showsChevron
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(AppFormat.month(summary.month))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.forward")
                        .foregroundStyle(AppTheme.muted)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Net Profit")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                Text(AppFormat.money(summary.netCents, signed: true))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(summary.netCents >= 0 ? AppTheme.ink : AppTheme.destructive)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 16) {
                metric("Income", summary.incomeCents, kind: .income, sign: "+")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider().frame(height: 38)
                metric("Expense", summary.expenseCents, kind: .expense, sign: "−")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            compositionBar
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func metric(_ title: LocalizedStringKey, _ cents: Int64, kind: LedgerKind, sign: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.color(for: kind))
                    .frame(width: 8, height: 8)
                Text(title)
            }
            .font(.caption)
            .foregroundStyle(AppTheme.muted)
            Text("\(sign)\(AppFormat.money(cents))")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(AppTheme.strongColor(for: kind))
        }
    }

    @ViewBuilder
    private var compositionBar: some View {
        let total = Double(summary.incomeCents) + Double(summary.expenseCents)
        if total > 0 {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(AppTheme.income)
                        .frame(width: proxy.size.width * CGFloat(Double(summary.incomeCents) / total))
                    Rectangle()
                        .fill(AppTheme.expense)
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(AppLocalization.string("Income")), \(AppFormat.money(summary.incomeCents)); "
                + "\(AppLocalization.string("Expense")), \(AppFormat.money(summary.expenseCents))"
            )
        }
    }
}

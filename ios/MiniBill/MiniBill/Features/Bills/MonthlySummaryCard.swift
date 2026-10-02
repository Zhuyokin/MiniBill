import SwiftUI

struct MonthlySummaryCard: View {
    @Environment(\.appLanguage) private var language
    let summary: MonthlySummary
    var artwork: LedgerArtworkMotif = .leaves

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Monthly Net Profit")
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
        .background { LedgerCardArtwork(motif: artwork) }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .themedPanel(cornerRadius: 22)
    }
}

struct LedgerSummaryMetric: View {
    @Environment(\.appLanguage) private var language
    let cents: Int64
    let kind: LedgerKind

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.color(for: kind))
                    .frame(width: 8, height: 8)
                Text(kind == .income ? "Income" : "Expense")
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.muted)
            Text(AppFormat.money(cents, locale: language.locale))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(AppTheme.strongColor(for: kind))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LedgerBalanceBar: View {
    let income: Int64
    let expense: Int64

    var body: some View {
        GeometryReader { geometry in
            let total = Double(income) + Double(expense)
            HStack(spacing: 2) {
                if income > 0 {
                    AppTheme.income
                        .frame(width: (geometry.size.width - (expense > 0 ? 2 : 0)) * Double(income) / total)
                }
                if expense > 0 { AppTheme.expense }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(AppTheme.muted.opacity(0.1))
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

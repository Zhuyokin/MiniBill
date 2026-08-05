import SwiftUI

struct MonthlyShareCard: View {
    let payload: MonthlySharePayload

    var body: some View {
        VStack(alignment: .leading, spacing: 44) {
            brandHeader
            VStack(alignment: .leading, spacing: 14) {
                Text(AppFormat.month(payload.month)).font(.system(size: 30, weight: .semibold)).foregroundStyle(.gray)
                Text("Net Profit").font(.system(size: 26, weight: .medium)).foregroundStyle(.gray)
                Text(AppFormat.money(payload.netCents, signed: true))
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
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(AppTheme.brand).frame(width: 64, height: 64)
                Image(systemName: "book.closed.fill").font(.system(size: 30)).foregroundStyle(.white)
            }
            Text("MiniBill").font(.system(size: 32, weight: .bold)).foregroundStyle(.black)
            Spacer()
            Text("MONTHLY").font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
        }
    }

    private func shareMetric(_ title: LocalizedStringKey, _ cents: Int64, sign: String, color: Color, isCount: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 20)).foregroundStyle(.gray)
            Text(isCount ? "\(payload.recordCount)" : "\(sign)\(AppFormat.money(cents))")
                .font(.system(size: 30, weight: .bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Daily Net").font(.system(size: 24, weight: .semibold)).foregroundStyle(.black)
            GeometryReader { proxy in
                let maximum = max(payload.dailyNet.map { abs($0.netCents) }.max() ?? 1, 1)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(payload.dailyNet.suffix(18)) { item in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(item.netCents >= 0 ? AppTheme.brand : Color.black)
                            .frame(maxWidth: .infinity, minHeight: 6, maxHeight: max(6, CGFloat(abs(item.netCents)) / CGFloat(maximum) * proxy.size.height))
                    }
                }
            }
            .frame(height: 180)
        }
        .padding(26)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 20))
    }

    private func topProject(_ title: LocalizedStringKey, _ project: ProjectTotal?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 19)).foregroundStyle(.gray)
            Text(project?.displayName ?? "—").font(.system(size: 28, weight: .semibold)).foregroundStyle(.black).lineLimit(1)
            Text(project.map { AppFormat.money($0.totalCents) } ?? "—").font(.system(size: 24, weight: .bold)).foregroundStyle(color)
        }
        .padding(26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 20))
    }
}

import SwiftUI

struct ProjectRankingView: View {
    @Environment(\.appLanguage) private var language
    let title: LocalizedStringKey
    let totals: [ProjectTotal]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 9, height: 9)
                Text(title)
            }
            .font(.headline)
            if totals.isEmpty {
                Text("No project data")
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let maximum = max(totals.first?.totalCents ?? 1, 1)
                ForEach(Array(totals.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                            .frame(width: 28, height: 28)
                            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

                        VStack(alignment: .leading, spacing: 9) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(item.displayName)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(AppFormat.money(item.totalCents, locale: language.locale))
                                        .font(.subheadline.weight(.semibold))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    Text("\(item.recordCount) entries")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                            }
                            GeometryReader { proxy in
                                Capsule().fill(tint.opacity(0.1))
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(tint).frame(width: proxy.size.width * CGFloat(item.totalCents) / CGFloat(maximum))
                                    }
                            }
                            .frame(height: 5)
                            .accessibilityHidden(true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(20)
        .themedPanel(cornerRadius: 22)
    }
}

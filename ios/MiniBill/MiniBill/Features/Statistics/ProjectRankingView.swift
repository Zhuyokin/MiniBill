import SwiftUI

struct ProjectRankingView: View {
    @Environment(\.appLanguage) private var language
    let title: LocalizedStringKey
    let totals: [ProjectTotal]
    let tint: Color
    let month: Date
    let kind: LedgerKind
    let accountID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                    NavigationLink {
                        FilteredEntriesView(selection: .project(
                            month: month,
                            kind: kind,
                            normalizedKey: item.normalizedKey,
                            displayName: item.displayName
                        ), accountID: accountID)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(index + 1). \(item.displayName)").lineLimit(1)
                                Spacer()
                                Text(AppFormat.money(item.totalCents, locale: language.locale)).monospacedDigit()
                                Image(systemName: "chevron.forward")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.muted)
                            }
                            GeometryReader { proxy in
                                Capsule().fill(tint.opacity(0.18))
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(tint).frame(width: proxy.size.width * CGFloat(item.totalCents) / CGFloat(maximum))
                                    }
                            }
                            .frame(height: 8)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Shows entries for this project")
                }
            }
        }
        .padding(16)
        .themedPanel(cornerRadius: 8)
    }
}

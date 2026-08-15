import SwiftUI

struct LedgerRow: View {
    @Environment(\.appLanguage) private var language
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(String(entry.projectName.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "•"))
                .font(.headline)
                .foregroundStyle(AppTheme.strongColor(for: entry.kind))
                .frame(width: 40, height: 40)
                .background { ThemedLedgerKindBadgeBackground(kind: entry.kind) }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.projectName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(entry.kind == .income ? "Income" : "Expense")
                    Text(AppFormat.shortTime(entry.occurredAt, locale: language.locale))
                    if let note = entry.note, !note.isEmpty {
                        Text("· \(note)").lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 8)
            Text("\(entry.kind == .income ? "+" : "−")\(AppFormat.money(entry.amountCents, locale: language.locale))")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.strongColor(for: entry.kind))
        }
        .padding(12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.kind == .income ? AppLocalization.string("Income", language: language) : AppLocalization.string("Expense", language: language)), "
            + "\(entry.projectName), \(AppFormat.money(entry.amountCents, locale: language.locale)), "
            + "\(AppFormat.dateTime(entry.occurredAt, locale: language.locale))"
        )
    }
}

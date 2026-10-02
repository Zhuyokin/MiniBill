import SwiftUI

struct LedgerRow: View {
    @Environment(\.appLanguage) private var language
    let entry: LedgerRecord

    init(entry: LedgerEntry) {
        self.entry = LedgerEntryMapper.record(from: entry)
    }

    init(record: LedgerRecord) {
        self.entry = record
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(String(entry.projectName.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "•"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.strongColor(for: entry.kind))
                .frame(width: 42, height: 42)
                .background { ThemedLedgerKindBadgeBackground(kind: entry.kind) }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.projectName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(entry.kind == .income ? "Income" : "Expense")
                    Text("·")
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
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .layoutPriority(1)
                .foregroundStyle(AppTheme.strongColor(for: entry.kind))
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(entry.kind == .income ? AppLocalization.string("Income", language: language) : AppLocalization.string("Expense", language: language)), "
            + "\(entry.projectName), \(AppFormat.money(entry.amountCents, locale: language.locale)), "
            + "\(AppFormat.dateTime(entry.occurredAt, locale: language.locale))"
        )
    }
}

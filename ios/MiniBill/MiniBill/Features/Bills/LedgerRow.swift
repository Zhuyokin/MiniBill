import SwiftUI

struct LedgerRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(String(entry.projectName.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "•"))
                .font(.headline)
                .foregroundStyle(AppTheme.brandDark)
                .frame(width: 40, height: 40)
                .background(AppTheme.brandSoft, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.projectName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(entry.kind == .income ? "Income" : "Expense")
                    Text(AppFormat.shortTime(entry.occurredAt))
                    if let note = entry.note, !note.isEmpty {
                        Text("· \(note)").lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            }
            Spacer(minLength: 8)
            Text("\(entry.kind == .income ? "+" : "−")\(AppFormat.money(entry.amountCents))")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.kind == .income ? AppTheme.brandDark : AppTheme.ink)
        }
        .padding(12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.kind == .income ? AppLocalization.string("Income") : AppLocalization.string("Expense")), \(entry.projectName), \(AppFormat.money(entry.amountCents)), \(AppFormat.dateTime(entry.occurredAt))")
    }
}

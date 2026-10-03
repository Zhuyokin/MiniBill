import SwiftUI
import WidgetKit

@main
struct MiniBillWidgets: WidgetBundle {
    var body: some Widget {
        MonthlyOverviewWidget()
        QuickEntryWidget()
    }
}

private struct LedgerWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: LedgerWidgetSnapshot?

    var language: AppLanguage { AppLanguage(storedCode: snapshot?.languageCode) }
    var accountName: String {
        guard let snapshot else { return "" }
        if snapshot.accountID == LedgerAccountDefaults.id,
           snapshot.accountName == LedgerAccountDefaults.name {
            return text("Default Account")
        }
        return snapshot.accountName
    }

    func text(_ key: String) -> String {
        AppLocalization.string(key, language: language)
    }

    func amount(_ cents: Int64) -> String {
        AppFormat.money(cents, locale: language.locale)
    }

    var overviewURL: URL? {
        snapshot.map { LedgerWidgetRoute.overview(accountID: $0.accountID).url }
    }
}

private struct LedgerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LedgerWidgetEntry { sample }

    func getSnapshot(in context: Context, completion: @escaping (LedgerWidgetEntry) -> Void) {
        completion(context.isPreview ? sample : LedgerWidgetEntry(date: Date(), snapshot: LedgerWidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LedgerWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = LedgerWidgetStore.load()
        let calendar = Calendar.current
        var entries = [LedgerWidgetEntry(date: now, snapshot: snapshot)]
        for day in 1...7 {
            if let date = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: now)) {
                entries.append(LedgerWidgetEntry(date: date, snapshot: snapshot))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private var sample: LedgerWidgetEntry {
        let now = Date()
        let records: [LedgerRecord] = [
            LedgerRecord(id: UUID(), kind: .income, amountCents: 128000, projectName: "", note: nil,
                         occurredAt: now, createdAt: now, updatedAt: now),
            LedgerRecord(id: UUID(), kind: .expense, amountCents: 36000, projectName: "", note: nil,
                         occurredAt: now, createdAt: now, updatedAt: now)
        ]
        return LedgerWidgetEntry(date: now, snapshot: LedgerWidgetSnapshot(
            records: records, accounts: [.default], selectedAccountID: LedgerAccountDefaults.id,
            languageCode: AppLanguage.simplifiedChinese.rawValue
        ))
    }
}

private struct MonthlyOverviewWidget: Widget {
    let kind = "MiniBillMonthlyOverview"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LedgerWidgetProvider()) { entry in
            MonthlyOverviewView(entry: entry)
                .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
        }
        .configurationDisplayName("Monthly Overview")
        .description("Monthly income, expenses and net profit for your current account.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct QuickEntryWidget: Widget {
    let kind = "MiniBillQuickEntry"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LedgerWidgetProvider()) { entry in
            QuickEntryWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
        }
        .configurationDisplayName("Quick Entry")
        .description("Today's totals and shortcuts to add income or expenses.")
        .supportedFamilies([.systemMedium])
    }
}

private struct MonthlyOverviewView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LedgerWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                let totals = snapshot.totals(in: .month, at: entry.date, calendar: .current)
                VStack(alignment: .leading, spacing: 8) {
                    WidgetHeading(entry: entry, title: "This month", icon: "chart.bar.xaxis")
                    if family == .systemSmall {
                        profit(totals.netCents, size: 25)
                        Spacer(minLength: 0)
                        HStack(spacing: 8) {
                            WidgetAmount(entry: entry, kind: .income, cents: totals.incomeCents)
                            Spacer(minLength: 0)
                            WidgetAmount(entry: entry, kind: .expense, cents: totals.expenseCents)
                        }
                    } else {
                        Spacer(minLength: 0)
                        HStack(spacing: 20) {
                            profit(totals.netCents, size: 30)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Rectangle().fill(.quaternary).frame(width: 1)
                            VStack(alignment: .leading, spacing: 10) {
                                WidgetAmount(entry: entry, kind: .income, cents: totals.incomeCents)
                                WidgetAmount(entry: entry, kind: .expense, cents: totals.expenseCents)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .widgetURL(entry.overviewURL)
            } else {
                EmptyLedgerWidgetView(entry: entry)
            }
        }
    }

    private func profit(_ cents: Int64, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.text("Net Profit"))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(entry.amount(cents))
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .privacySensitive()
        }
        .accessibilityElement(children: .combine)
    }
}

private struct QuickEntryWidgetView: View {
    let entry: LedgerWidgetEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            let totals = snapshot.totals(in: .day, at: entry.date, calendar: .current)
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeading(entry: entry, title: "Today", icon: "calendar")
                HStack(spacing: 16) {
                    WidgetAmount(entry: entry, kind: .income, cents: totals.incomeCents)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    WidgetAmount(entry: entry, kind: .expense, cents: totals.expenseCents)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    entryLink(kind: .income, accountID: snapshot.accountID)
                    entryLink(kind: .expense, accountID: snapshot.accountID)
                }
            }
            .widgetURL(entry.overviewURL)
        } else {
            EmptyLedgerWidgetView(entry: entry)
        }
    }

    private func entryLink(kind: LedgerKind, accountID: UUID) -> some View {
        Link(destination: LedgerWidgetRoute.entry(accountID: accountID, kind: kind).url) {
            Label(entry.text(kind == .income ? "Record Income" : "Record Expense"), systemImage: "plus")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .foregroundStyle(AppTheme.strongColor(for: kind))
                .background(AppTheme.softColor(for: kind), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct WidgetHeading: View {
    let entry: LedgerWidgetEntry
    let title: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon).foregroundStyle(AppTheme.brand)
                Text(entry.text(title)).fontWeight(.semibold)
                Spacer(minLength: 0)
                Text(entry.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).locale(entry.language.locale)))
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
            Text(entry.accountName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .privacySensitive()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

private struct WidgetAmount: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: LedgerWidgetEntry
    let kind: LedgerKind
    let cents: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.text(kind == .income ? "Income" : "Expense"))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(entry.amount(cents))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(colorScheme == .dark ? AppTheme.color(for: kind) : AppTheme.strongColor(for: kind))
                .privacySensitive()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyLedgerWidgetView: View {
    let entry: LedgerWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(entry.text("MiniBill"), systemImage: "book.closed.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.brandDark)
            Text(entry.text("Open MiniBill to load your ledger."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

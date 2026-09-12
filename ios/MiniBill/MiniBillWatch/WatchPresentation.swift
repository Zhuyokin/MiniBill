import SwiftUI

struct WatchStrings {
    let language: AppLanguage

    func callAsFunction(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let value = bundle.localizedString(forKey: key, value: key, table: "WatchLocalizable")
            if value != key { return value }
        }
        return AppLocalization.string(key, language: language)
    }

    func entries(_ count: Int) -> String {
        String(format: self("%lld entries"), locale: language.locale, Int64(count))
    }

    func accountName(_ account: LedgerAccountRecord) -> String {
        account.id == LedgerAccountDefaults.id && account.name == LedgerAccountDefaults.name
            ? self("Default Account") : account.name
    }
}

enum WatchFormat {
    static func money(_ cents: Int64, language: AppLanguage, signed: Bool = false) -> String {
        let value = (Decimal(cents) / 100).formatted(
            .currency(code: "CNY").precision(.fractionLength(0...2)).locale(language.locale)
        )
        return signed && cents > 0 ? "+\(value)" : value
    }

    static func month(_ date: Date, language: AppLanguage) -> String {
        date.formatted(.dateTime.year().month(.wide).locale(language.locale))
    }

    static func date(_ date: Date, language: AppLanguage) -> String {
        date.formatted(.dateTime.year().month(.abbreviated).day().locale(language.locale))
    }

    static func time(_ date: Date, language: AppLanguage) -> String {
        date.formatted(.dateTime.hour().minute().locale(language.locale))
    }

    static func dateTime(_ date: Date, language: AppLanguage) -> String {
        date.formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(language.locale))
    }

    static func color(_ kind: LedgerKind) -> Color {
        kind == .income ? .yellow : .green
    }

    static func validationMessage(_ error: Error, language: AppLanguage) -> String {
        let strings = WatchStrings(language: language)
        switch error {
        case EntryValidationError.invalidAmount:
            return strings("Enter an amount greater than zero with at most two decimal places.")
        case EntryValidationError.amountTooLarge:
            return strings("Amount cannot exceed ¥99,999,999.99.")
        case EntryValidationError.emptyProjectName:
            return strings("Project name is required.")
        case EntryValidationError.noteTooLong:
            return strings("Note must be 200 characters or fewer.")
        case LedgerAccountNameError.empty:
            return strings("Account name is required.")
        case LedgerAccountNameError.tooLong:
            return strings("Account name must be 30 characters or fewer.")
        default:
            return (error as? LocalizedError)?.errorDescription
                ?? strings("Could not save. Your input is still here; try again.")
        }
    }

    static func sum(_ values: [Int64]) -> Int64 {
        values.reduce(0) { partial, value in
            let (result, overflow) = partial.addingReportingOverflow(value)
            return overflow ? Int64.max : result
        }
    }
}

struct WatchTotalsView: View {
    let income: Int64
    let expense: Int64
    let net: Int64
    let count: Int
    let language: AppLanguage

    var body: some View {
        let strings = WatchStrings(language: language)
        VStack(alignment: .leading, spacing: 9) {
            metric(strings("Net"), cents: net, color: .primary, signed: true)
            metric(strings("Income"), cents: income, color: WatchFormat.color(.income))
            metric(strings("Expense"), cents: expense, color: WatchFormat.color(.expense))
            Text(strings.entries(count)).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metric(_ title: String, cents: Int64, color: Color, signed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(WatchFormat.money(cents, language: language, signed: signed))
                .font(.headline).monospacedDigit().foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

struct WatchPeriodNavigator: View {
    @Binding var date: Date
    var component: Calendar.Component = .month
    let language: AppLanguage

    var body: some View {
        let strings = WatchStrings(language: language)
        VStack(spacing: 6) {
            Text(component == .year
                 ? date.formatted(.dateTime.year().locale(language.locale))
                 : WatchFormat.month(date, language: language))
                .font(.headline).multilineTextAlignment(.center)
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel(strings("Previous period"))
                Button(strings("Today")) { date = Date() }.font(.caption)
                Button { move(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel(strings("Next period"))
            }
        }
    }

    private func move(_ offset: Int) {
        let start = Calendar.current.dateInterval(of: component, for: date)?.start ?? date
        if let next = Calendar.current.date(byAdding: component, value: offset, to: start) {
            date = next
        }
    }
}

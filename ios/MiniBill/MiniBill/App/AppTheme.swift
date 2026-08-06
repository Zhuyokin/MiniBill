import SwiftUI

enum AppTheme {
    static let expense = Color(red: 7 / 255, green: 193 / 255, blue: 96 / 255)
    static let expenseStrong = Color(red: 5 / 255, green: 128 / 255, blue: 66 / 255)
    static let expenseSoft = Color(red: 232 / 255, green: 248 / 255, blue: 239 / 255)

    static let income = Color(red: 246 / 255, green: 183 / 255, blue: 60 / 255)
    static let incomeStrong = Color(red: 164 / 255, green: 93 / 255, blue: 0 / 255)
    static let incomeSoft = Color(red: 255 / 255, green: 244 / 255, blue: 214 / 255)

    static let brand = expense
    static let brandDark = expenseStrong
    static let brandSoft = expenseSoft
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let destructive = Color(red: 217 / 255, green: 66 / 255, blue: 53 / 255)

    static func color(for kind: LedgerKind) -> Color {
        kind == .income ? income : expense
    }

    static func strongColor(for kind: LedgerKind) -> Color {
        kind == .income ? incomeStrong : expenseStrong
    }

    static func softColor(for kind: LedgerKind) -> Color {
        kind == .income ? incomeSoft : expenseSoft
    }
}

enum AppFormat {
    static func money(
        _ cents: Int64,
        signed: Bool = false,
        locale: Locale = AppLanguage.current.locale
    ) -> String {
        let decimal = Decimal(cents) / Decimal(100)
        let value = decimal.formatted(
            .currency(code: "CNY")
                .precision(.fractionLength(0...2))
                .locale(locale)
        )
        guard signed else { return value }
        if cents > 0 { return "+\(value)" }
        if cents < 0 { return "−\(money(abs(cents), locale: locale))" }
        return value
    }

    static func amountInput(_ cents: Int64) -> String {
        EntryValidator.amountText(cents: cents)
    }

    static func month(_ date: Date, locale: Locale = AppLanguage.current.locale) -> String {
        date.formatted(.dateTime.year().month(.wide).locale(locale))
    }

    static func shortDate(_ date: Date, locale: Locale = AppLanguage.current.locale) -> String {
        date.formatted(.dateTime.year().month(.abbreviated).day().locale(locale))
    }

    static func shortTime(_ date: Date, locale: Locale = AppLanguage.current.locale) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }

    static func dateTime(_ date: Date, locale: Locale = AppLanguage.current.locale) -> String {
        date.formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(locale))
    }

    static func longDateTime(_ date: Date, locale: Locale = AppLanguage.current.locale) -> String {
        date.formatted(.dateTime.year().month(.wide).day().hour().minute().locale(locale))
    }

    static func day(_ date: Date, locale: Locale = AppLanguage.current.locale) -> String {
        date.formatted(.dateTime.day().locale(locale))
    }
}

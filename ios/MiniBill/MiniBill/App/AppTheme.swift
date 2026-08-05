import SwiftUI

enum AppTheme {
    static let brand = Color(red: 7 / 255, green: 193 / 255, blue: 96 / 255)
    static let brandDark = Color(red: 7 / 255, green: 148 / 255, blue: 71 / 255)
    static let brandSoft = Color(red: 233 / 255, green: 248 / 255, blue: 239 / 255)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let destructive = Color(red: 217 / 255, green: 66 / 255, blue: 53 / 255)
}

enum AppFormat {
    static func money(_ cents: Int64, signed: Bool = false) -> String {
        let decimal = Decimal(cents) / Decimal(100)
        let value = decimal.formatted(.currency(code: "CNY").precision(.fractionLength(0...2)))
        guard signed else { return value }
        if cents > 0 { return "+\(value)" }
        if cents < 0 { return "−\(money(abs(cents)))" }
        return value
    }

    static func amountInput(_ cents: Int64) -> String {
        String(format: "%lld.%02lld", cents / 100, cents % 100)
    }

    static func month(_ date: Date) -> String {
        date.formatted(.dateTime.year().month(.wide))
    }
}

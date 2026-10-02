import SwiftUI
import UIKit

enum ShareCardPayload: Identifiable {
    case month(MonthlySharePayload)
    case year(YearlySharePayload)
    case entry(EntrySharePayload)

    var id: String {
        switch self {
        case .month(let value):
            let days = value.dailyNet.map { "\($0.date.timeIntervalSince1970):\($0.netCents)" }.joined(separator: ",")
            let topIncome = value.topIncomeProject.map { "\($0.normalizedKey):\($0.totalCents)" } ?? "none"
            let topExpense = value.topExpenseProject.map { "\($0.normalizedKey):\($0.totalCents)" } ?? "none"
            return [
                "month", String(value.month.timeIntervalSince1970), String(value.netCents),
                String(value.incomeCents), String(value.expenseCents), String(value.recordCount),
                days, topIncome, topExpense
            ].joined(separator: "|")
        case .year(let value):
            let months = value.months.map {
                "\($0.month.timeIntervalSince1970):\($0.incomeCents):\($0.expenseCents)"
            }.joined(separator: ",")
            return [
                "year", String(value.year.timeIntervalSince1970), String(value.netCents),
                String(value.incomeCents), String(value.expenseCents), String(value.recordCount), months
            ].joined(separator: "|")
        case .entry(let value):
            return [
                "entry", value.kind.rawValue, String(value.amountCents), value.projectName,
                String(value.occurredAt.timeIntervalSince1970)
            ].joined(separator: "|")
        }
    }
}

@MainActor
enum ShareImageService {
    enum RenderError: Error { case renderingFailed }

    static func render(_ payload: ShareCardPayload, language: AppLanguage) throws -> UIImage {
        let card: AnyView
        switch payload {
        case .month(let value):
            card = AnyView(MonthlyShareCard(payload: value, locale: language.locale))
        case .year(let value):
            card = AnyView(YearlyShareCard(payload: value, locale: language.locale))
        case .entry(let value):
            card = AnyView(EntryShareCard(payload: value, locale: language.locale))
        }

        let renderer = ImageRenderer(
            content: card
                .frame(width: 900, height: 1200)
                .environment(\.locale, language.locale)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 2
        guard let image = renderer.uiImage else { throw RenderError.renderingFailed }
        return image
    }
}

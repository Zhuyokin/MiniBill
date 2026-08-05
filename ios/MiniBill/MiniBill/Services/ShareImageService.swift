import SwiftUI
import UIKit

enum ShareCardPayload: Identifiable {
    case month(MonthlySharePayload)
    case entry(EntrySharePayload)

    var id: String {
        switch self {
        case .month(let value): return "month-\(value.month.timeIntervalSince1970)"
        case .entry(let value): return "entry-\(value.occurredAt.timeIntervalSince1970)-\(value.projectName)"
        }
    }
}

@MainActor
enum ShareImageService {
    enum RenderError: Error { case renderingFailed }

    static func render(_ payload: ShareCardPayload) throws -> URL {
        let card: AnyView
        let name: String
        switch payload {
        case .month(let value):
            card = AnyView(MonthlyShareCard(payload: value))
            name = "MiniBill-Month"
        case .entry(let value):
            card = AnyView(EntryShareCard(payload: value))
            name = "MiniBill-Entry"
        }

        let renderer = ImageRenderer(content: card.frame(width: 900, height: 1200).environment(\.colorScheme, .light))
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else { throw RenderError.renderingFailed }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)")
            .appendingPathExtension("png")
        try data.write(to: url, options: .atomic)
        return url
    }
}

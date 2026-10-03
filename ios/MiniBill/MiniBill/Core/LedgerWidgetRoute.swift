import Foundation

public enum LedgerWidgetRoute: Equatable {
    case overview(accountID: UUID)
    case entry(accountID: UUID, kind: LedgerKind)

    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "minibill", components.path.isEmpty,
              let items = components.queryItems,
              items.filter({ $0.name == "account" }).count == 1,
              let value = items.first(where: { $0.name == "account" })?.value,
              let accountID = UUID(uuidString: value) else { return nil }
        switch components.host {
        case "overview":
            self = .overview(accountID: accountID)
        case "entry":
            guard items.filter({ $0.name == "kind" }).count == 1,
                  let value = items.first(where: { $0.name == "kind" })?.value,
                  let kind = LedgerKind(rawValue: value) else { return nil }
            self = .entry(accountID: accountID, kind: kind)
        default:
            return nil
        }
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = "minibill"
        switch self {
        case .overview(let accountID):
            components.host = "overview"
            components.queryItems = [URLQueryItem(name: "account", value: accountID.uuidString)]
        case .entry(let accountID, let kind):
            components.host = "entry"
            components.queryItems = [
                URLQueryItem(name: "account", value: accountID.uuidString),
                URLQueryItem(name: "kind", value: kind.rawValue)
            ]
        }
        return components.url!
    }
}

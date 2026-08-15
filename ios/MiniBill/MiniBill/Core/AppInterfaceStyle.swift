import Foundation

public enum AppInterfaceStyle: String, CaseIterable, Sendable {
    case modern
    case skeuomorphic

    public static let storageKey = "appInterfaceStyle"

    public init(storedValue: String?) {
        self = storedValue.flatMap(AppInterfaceStyle.init(rawValue:)) ?? .modern
    }
}

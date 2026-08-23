enum AppNavigationPresentation: Equatable {
    case tabs
    case splitView
}

enum AppNavigationLayoutPolicy {
    static func presentation(isRegularWidth: Bool) -> AppNavigationPresentation {
        isRegularWidth ? .splitView : .tabs
    }
}

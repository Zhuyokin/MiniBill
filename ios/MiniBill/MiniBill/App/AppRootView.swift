import SwiftUI

private enum RootTab: Hashable {
    case bills
    case statistics
    case settings
}

struct AppRootView: View {
    @EnvironmentObject private var router: NotificationRouter
    @State private var selectedTab: RootTab = .bills
    @State private var selectedStatisticsMonth = Date()
    @State private var showQuickEntry = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                BillsView(
                    showQuickEntry: $showQuickEntry,
                    onOpenStatistics: { month in
                        selectedStatisticsMonth = month
                        selectedTab = .statistics
                    }
                )
            }
            .tabItem { Label("Home", systemImage: "list.bullet.clipboard") }
            .tag(RootTab.bills)

            NavigationStack {
                StatisticsView(selectedMonth: $selectedStatisticsMonth)
            }
            .tabItem { Label("Statistics", systemImage: "chart.bar.xaxis") }
            .tag(RootTab.statistics)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Me", systemImage: "gearshape") }
            .tag(RootTab.settings)
        }
        .tint(AppTheme.brand)
        .onAppear(perform: consumeRoute)
        .onChange(of: router.route) { _, _ in consumeRoute() }
    }

    private func consumeRoute() {
        guard let route = router.route else { return }
        switch route {
        case .quickEntry:
            selectedTab = .bills
            showQuickEntry = true
        case .statistics:
            selectedStatisticsMonth = Date()
            selectedTab = .statistics
        }
        router.consume()
    }
}

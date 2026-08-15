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
    @AppStorage(LedgerAccountDefaults.selectionStorageKey) private var selectedAccountValue = LedgerAccountDefaults.id.uuidString

    private var selectedAccountID: Binding<UUID> {
        Binding(
            get: { UUID(uuidString: selectedAccountValue) ?? LedgerAccountDefaults.id },
            set: { selectedAccountValue = $0.uuidString }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                BillsView(
                    showQuickEntry: $showQuickEntry,
                    selectedAccountID: selectedAccountID,
                    onOpenStatistics: { month in
                        selectedStatisticsMonth = month
                        selectedTab = .statistics
                    }
                )
            }
            .themedNavigationChrome()
            .tabItem { Label("Home", systemImage: "list.bullet.clipboard") }
            .tag(RootTab.bills)

            NavigationStack {
                StatisticsView(selectedMonth: $selectedStatisticsMonth, selectedAccountID: selectedAccountID)
            }
            .themedNavigationChrome()
            .tabItem { Label("Statistics", systemImage: "chart.bar.xaxis") }
            .tag(RootTab.statistics)

            NavigationStack {
                SettingsView(selectedAccountID: selectedAccountID)
            }
            .themedNavigationChrome()
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(RootTab.settings)
        }
        .themedTabChrome()
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

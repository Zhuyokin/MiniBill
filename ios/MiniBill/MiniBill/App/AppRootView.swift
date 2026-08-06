import SwiftUI

private enum RootTab: Hashable {
    case bills
    case settings
}

private enum BillsDestination: Hashable {
    case statistics(Date)
}

struct AppRootView: View {
    @EnvironmentObject private var router: NotificationRouter
    @State private var selectedTab: RootTab = .bills
    @State private var billsPath: [BillsDestination] = []
    @State private var showQuickEntry = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $billsPath) {
                BillsView(
                    showQuickEntry: $showQuickEntry,
                    onOpenStatistics: { month in billsPath.append(.statistics(month)) }
                )
                .navigationDestination(for: BillsDestination.self) { destination in
                    switch destination {
                    case .statistics(let month): StatisticsView(initialMonth: month)
                    }
                }
            }
            .tabItem { Label("Bills", systemImage: "list.bullet.clipboard") }
            .tag(RootTab.bills)

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
        selectedTab = .bills
        switch route {
        case .quickEntry:
            billsPath.removeAll()
            showQuickEntry = true
        case .statistics:
            billsPath = [.statistics(Date())]
        }
        router.consume()
    }
}

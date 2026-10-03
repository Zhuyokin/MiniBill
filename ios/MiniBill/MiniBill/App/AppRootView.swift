import SwiftUI
import SwiftData

private enum RootTab: String, CaseIterable, Hashable, Identifiable {
    case bills
    case statistics
    case settings

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .bills: return "Home"
        case .statistics: return "Statistics"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .bills: return "house.fill"
        case .statistics: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}

struct AppRootView: View {
    @EnvironmentObject private var router: NotificationRouter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: RootTab = .bills
    @State private var selectedStatisticsMonth = Date()
    @State private var showQuickEntry = false
    @State private var quickEntryKind: LedgerKind = .income
    @State private var editingEntry: LedgerRecord?
    @Query private var accounts: [LedgerAccount]
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all
    @AppStorage(LedgerAccountDefaults.selectionStorageKey) private var selectedAccountValue = LedgerAccountDefaults.id.uuidString

    private var selectedAccountID: Binding<UUID> {
        Binding(
            get: { UUID(uuidString: selectedAccountValue) ?? LedgerAccountDefaults.id },
            set: { selectedAccountValue = $0.uuidString }
        )
    }

    var body: some View {
        Group {
            switch AppNavigationLayoutPolicy.presentation(isRegularWidth: horizontalSizeClass == .regular) {
            case .tabs:
                phoneTabs
            case .splitView:
                tabletSplitView
            }
        }
        .onAppear(perform: consumeRoute)
        .onChange(of: router.route) { _, _ in consumeRoute() }
        .onChange(of: selectedAccountValue) { _, _ in
            LedgerWidgetSyncService.shared.refresh()
        }
    }

    private var phoneTabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(RootTab.allCases) { tab in
                rootView(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
        .themedTabChrome()
    }

    private var tabletSplitView: some View {
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            List {
                ForEach(RootTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: tab.icon)
                                .frame(width: 20)
                            Text(tab.title)
                                .font(.body.weight(selectedTab == tab ? .semibold : .regular))
                            Spacer()
                        }
                        .foregroundStyle(selectedTab == tab ? AppTheme.brandDark : AppTheme.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 44)
                        .background(selectedTab == tab ? AppTheme.brandSoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("MiniBill")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 280)
        } detail: {
            rootView(for: selectedTab)
                .id(selectedTab)
                .toolbar(removing: .sidebarToggle)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation {
                                splitViewVisibility = splitViewVisibility == .detailOnly ? .all : .detailOnly
                            }
                        } label: {
                            Image(systemName: "sidebar.left")
                        }
                        .accessibilityLabel(splitViewVisibility == .detailOnly ? "Show Sidebar" : "Hide Sidebar")
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func rootView(for tab: RootTab) -> some View {
        switch tab {
        case .bills:
            NavigationStack {
                BillsView(
                    showQuickEntry: $showQuickEntry,
                    quickEntryKind: $quickEntryKind,
                    editingEntry: $editingEntry,
                    selectedAccountID: selectedAccountID,
                    onOpenStatistics: { month in
                        selectedStatisticsMonth = month
                        selectedTab = .statistics
                    }
                )
            }
            .themedNavigationChrome()
        case .statistics:
            NavigationStack {
                StatisticsView(selectedMonth: $selectedStatisticsMonth, selectedAccountID: selectedAccountID)
            }
            .themedNavigationChrome()
        case .settings:
            NavigationStack {
                SettingsView(selectedAccountID: selectedAccountID)
            }
            .themedNavigationChrome()
        }
    }

    private func consumeRoute() {
        guard let route = router.route else { return }
        switch route {
        case .quickEntry:
            if !showQuickEntry { quickEntryKind = .income }
            selectedTab = .bills
            showQuickEntry = true
        case .statistics:
            selectedStatisticsMonth = Date()
            selectedTab = .statistics
        case .widget(let widgetRoute):
            // Keep an open entry draft intact when another widget link arrives.
            guard !showQuickEntry, editingEntry == nil else { router.consume(); return }
            switch widgetRoute {
            case .overview(let accountID):
                guard accounts.contains(where: { $0.id == accountID }) else {
                    selectedTab = .bills
                    router.consume()
                    return
                }
                selectedAccountValue = accountID.uuidString
                selectedStatisticsMonth = Date()
                selectedTab = .statistics
            case .entry(let accountID, let kind):
                guard accounts.contains(where: { $0.id == accountID }) else {
                    selectedTab = .bills
                    router.consume()
                    return
                }
                selectedAccountValue = accountID.uuidString
                quickEntryKind = kind
                selectedTab = .bills
                showQuickEntry = true
            }
        }
        router.consume()
    }
}

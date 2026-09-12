import SwiftUI
import WatchKit

@main
struct MiniBillWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchBackgroundDelegate.self) private var backgroundDelegate
    @StateObject private var store = WatchLedgerStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(store)
                .environment(\.locale, store.language.locale)
                .tint(.green)
                .task { store.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refresh() }
                }
        }
    }
}

private struct WatchHomeView: View {
    @EnvironmentObject private var store: WatchLedgerStore
    @State private var isAddingEntry = false
    private var strings: WatchStrings { WatchStrings(language: store.language) }

    var body: some View {
        NavigationStack {
            List {
                if store.hasSnapshot {
                    if let account = store.accounts.first(where: { $0.id == store.selectedAccountID }) {
                        Text(strings.accountName(account)).font(.headline).foregroundStyle(.secondary)
                    }
                    Button { isAddingEntry = true } label: {
                        Label(strings("Add Entry"), systemImage: "plus.circle.fill")
                    }
                    .listItemTint(.green)
                    NavigationLink { WatchBillsView() } label: {
                        Label(strings("Bills"), systemImage: "list.bullet.rectangle")
                    }
                    NavigationLink { WatchReportsView() } label: {
                        Label(strings("Statistics"), systemImage: "chart.bar.xaxis")
                    }
                    NavigationLink { WatchAccountsView() } label: {
                        Label(strings("Accounts"), systemImage: "wallet.pass")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "iphone.and.arrow.forward").font(.title2)
                        Text(strings("Open MiniBill on your iPhone to start.")).font(.headline)
                        Text(strings("Your accounts and entries will appear here after the first sync."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                NavigationLink { WatchSyncView() } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(strings("Sync"), systemImage: "arrow.triangle.2.circlepath")
                        Text(syncSubtitle).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("MiniBill")
            .sheet(isPresented: $isAddingEntry) {
                NavigationStack {
                    WatchEntryEditor(accountID: store.selectedAccountID, language: store.language)
                }
            }
            .alert(strings("MiniBill"), isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button(strings("OK"), role: .cancel) { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }

    private var syncSubtitle: String {
        if !store.failedChanges.isEmpty { return strings("Changes need attention") }
        if store.pendingCount > 0 {
            return String(format: strings("%lld pending changes"), locale: store.language.locale, Int64(store.pendingCount))
        }
        return strings(store.isReachable ? "iPhone connected" : "iPhone offline")
    }
}

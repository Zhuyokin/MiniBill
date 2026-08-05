import SwiftUI
import SwiftData

@main
struct MiniBillApp: App {
    @StateObject private var launch = LaunchCoordinator()
    @StateObject private var router = NotificationRouter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            LaunchHostView(launch: launch, router: router)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, launch.container != nil else { return }
            Task { await ReminderService.shared.reconcileFromPreferences() }
        }
    }
}

private struct LaunchHostView: View {
    @ObservedObject var launch: LaunchCoordinator
    @ObservedObject var router: NotificationRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            Group {
                if let container = launch.container {
                    AppRootView()
                        .modelContainer(container)
                        .environmentObject(router)
                        .task { await ReminderService.shared.reconcileFromPreferences() }
                } else {
                    LaunchFailureView(onRetry: launch.openPersistentLedger)
                }
            }

            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            if reduceMotion {
                isShowingSplash = false
            } else {
                withAnimation(.easeOut(duration: 0.22)) { isShowingSplash = false }
            }
        }
    }
}

@MainActor
final class LaunchCoordinator: ObservableObject {
    @Published private(set) var container: ModelContainer?

    init() {
        openPersistentLedger()
    }

    func openPersistentLedger() {
        do {
            let schema = Schema([LedgerEntry.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            container = nil
        }
    }
}

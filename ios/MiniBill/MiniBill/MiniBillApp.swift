import SwiftUI
import SwiftData
import OSLog
import UIKit

private let reminderLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "MiniBill",
    category: "Reminders"
)

#if DEBUG
private let demoDataLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "MiniBill",
    category: "DebugDemoData"
)
#endif

private func reconcileReminderPreferences(reason: String) async {
    do {
        try await ReminderService.shared.reconcileFromPreferences()
    } catch {
        reminderLogger.error(
            "Reminder reconciliation failed after \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
    }
}

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
            Task { await reconcileReminderPreferences(reason: "scene activation") }
        }
    }
}

private struct LaunchHostView: View {
    @ObservedObject var launch: LaunchCoordinator
    @ObservedObject var router: NotificationRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.simplifiedChinese.rawValue
    @State private var isShowingSplash = true

    private var language: AppLanguage {
        AppLanguage(storedCode: languageCode)
    }

    var body: some View {
        ZStack {
            Group {
                if let container = launch.container {
                    AppRootView()
                        .modelContainer(container)
                        .environmentObject(router)
                        .task { await reconcileReminderPreferences(reason: "app launch") }
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            guard launch.container != nil else { return }
            Task { await reconcileReminderPreferences(reason: "significant time change") }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            guard launch.container != nil else { return }
            Task { await reconcileReminderPreferences(reason: "system time-zone change") }
        }
        .onChange(of: languageCode) { _, _ in
            guard launch.container != nil else { return }
            Task { await reconcileReminderPreferences(reason: "app language change") }
        }
        .environment(\.locale, language.locale)
        .environment(\.appLanguage, language)
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
            let schema = Schema([LedgerEntry.self, LedgerAccount.self])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
            let openedContainer = try ModelContainer(for: schema, configurations: [configuration])
            try LedgerAccountStore.ensureDefaultAccount(in: openedContainer)
#if DEBUG
            do {
                try DebugDemoDataSeeder.seedIfNeeded(in: openedContainer)
            } catch {
                demoDataLogger.error("Could not seed Debug demo data: \(error.localizedDescription, privacy: .public)")
            }
#endif
            container = openedContainer
        } catch {
            container = nil
        }
    }
}

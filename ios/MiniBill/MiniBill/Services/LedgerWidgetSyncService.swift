import Foundation
import SwiftData
import WidgetKit
import OSLog

@MainActor
final class LedgerWidgetSyncService {
    static let shared = LedgerWidgetSyncService()
    private let logger = Logger(subsystem: "com.masdey.minibill", category: "WidgetSync")
    private var container: ModelContainer?
    private var saveObserver: NSObjectProtocol?
    private var lastSnapshot: LedgerWidgetSnapshot?

    func start(container: ModelContainer) {
        self.container = container
        lastSnapshot = LedgerWidgetStore.load()
        if saveObserver == nil {
            saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
        refresh()
    }

    func refresh(forceReload: Bool = false) {
        guard let container else { return }
        do {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let records = try context.fetch(FetchDescriptor<LedgerEntry>()).map(LedgerEntryMapper.record)
            let accounts = try context.fetch(FetchDescriptor<LedgerAccount>()).map(LedgerAccountMapper.record)
            let selectedID = UserDefaults.standard.string(forKey: LedgerAccountDefaults.selectionStorageKey)
                .flatMap(UUID.init(uuidString:)) ?? LedgerAccountDefaults.id
            let snapshot = LedgerWidgetSnapshot(
                records: records, accounts: accounts, selectedAccountID: selectedID,
                languageCode: AppLanguage.current.rawValue
            )
            let hasChanges = snapshot != lastSnapshot
            if hasChanges {
                try LedgerWidgetStore.save(snapshot)
                lastSnapshot = snapshot
            }
            if hasChanges || forceReload {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            logger.error("Could not update widgets: \(error.localizedDescription, privacy: .public)")
        }
    }
}

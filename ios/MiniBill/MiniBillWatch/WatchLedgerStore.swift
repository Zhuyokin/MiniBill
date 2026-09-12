import Foundation
import SwiftUI
import WatchConnectivity
import WatchKit

@MainActor
final class WatchLedgerStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchLedgerStore()
    @Published private var state = WatchLedgerState()
    @Published var selectedAccountID = LedgerAccountDefaults.id {
        didSet { UserDefaults.standard.set(selectedAccountID.uuidString, forKey: LedgerAccountDefaults.selectionStorageKey) }
    }
    @Published var errorMessage: String?
    @Published private(set) var isReachable = false
    private var canPersist = true
    private var started = false
    private var inFlightMessage: UUID?
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0
    private let directory: URL
    private var cacheURL: URL { directory.appendingPathComponent("ledger.json") }

    var accounts: [LedgerAccountRecord] {
        state.accounts.sorted { $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt < $1.createdAt }
    }
    var records: [LedgerRecord] { state.records }
    var selectedRecords: [LedgerRecord] { LedgerRecordFilter.records(forAccountID: selectedAccountID, from: records) }
    var language: AppLanguage { AppLanguage(storedCode: state.snapshot?.languageCode) }
    var pendingCount: Int { state.pending.count }
    var hasSnapshot: Bool { state.snapshot != nil }
    var lastSync: Date? { state.snapshot?.generatedAt }
    var failedChanges: [WatchSyncFailure] { state.failedChanges }

    override init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WatchLedger", isDirectory: true)
        super.init()
        if let stored = UserDefaults.standard.string(forKey: LedgerAccountDefaults.selectionStorageKey), let id = UUID(uuidString: stored) {
            selectedAccountID = id
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                state = try JSONDecoder().decode(WatchLedgerState.self, from: Data(contentsOf: cacheURL))
            }
            repairSelection()
        } catch {
            canPersist = false
            errorMessage = message("Could not read saved data. Try opening MiniBill again.")
        }
    }

    func start() {
        guard WCSession.isSupported() else { return }
        if !started {
            started = true
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        refresh()
    }

    func refresh() {
        guard started, WCSession.default.activationState == .activated else { return }
        let session = WCSession.default
        isReachable = session.isReachable
        receive(session.receivedApplicationContext)
        sendPending()
        if session.isReachable {
            session.sendMessage([WatchLedgerTransport.requestKey: true], replyHandler: { [weak self] payload in
                Task { @MainActor in self?.receive(payload) }
            }, errorHandler: { _ in })
        } else if !session.outstandingUserInfoTransfers.contains(where: { $0.userInfo[WatchLedgerTransport.requestKey] as? Bool == true }) {
            session.transferUserInfo([WatchLedgerTransport.requestKey: true])
        }
    }

    func saveEntry(_ record: LedgerRecord, replacing base: LedgerRecord?) throws {
        try enqueue(.init(ledgerID: try currentLedgerID(), kind: .saveEntry, record: record, baseRecord: base))
    }

    func deleteEntry(_ record: LedgerRecord) throws {
        try enqueue(.init(ledgerID: try currentLedgerID(), kind: .deleteEntry, record: record, baseRecord: record))
    }

    func saveAccount(_ account: LedgerAccountRecord, replacing base: LedgerAccountRecord?) throws {
        try enqueue(.init(ledgerID: try currentLedgerID(), kind: .saveAccount, account: account, baseAccount: base))
        if base == nil { selectedAccountID = account.id }
    }

    func deleteAccount(_ account: LedgerAccountRecord) throws {
        try enqueue(.init(ledgerID: try currentLedgerID(), kind: .deleteAccount, account: account, baseAccount: account,
                          accountEntries: records.filter { $0.accountID == account.id }))
    }

    func discardFailure(_ id: UUID) throws {
        var next = state
        next.discardFailure(id)
        try commit(next)
    }

    /// Called only after the user confirms applying their retained draft to the current ledger.
    func retryFailure(_ id: UUID) throws {
        guard let failure = state.failedChanges.first(where: { $0.id == id }) else { return }
        let previous = failure.mutation
        let ledgerID = try currentLedgerID()
        let mutation: WatchLedgerMutation
        switch previous.kind {
        case .saveEntry:
            guard var record = previous.record else { return }
            let base = records.first { $0.id == record.id }
            record.createdAt = base?.createdAt ?? record.createdAt
            record.updatedAt = Date()
            mutation = .init(ledgerID: ledgerID, kind: .saveEntry, record: record, baseRecord: base)
        case .deleteEntry:
            guard let record = records.first(where: { $0.id == previous.record?.id }) else {
                try discardFailure(id)
                return
            }
            mutation = .init(ledgerID: ledgerID, kind: .deleteEntry, record: record, baseRecord: record)
        case .saveAccount:
            guard var account = previous.account else { return }
            let base = accounts.first { $0.id == account.id }
            account.createdAt = base?.createdAt ?? account.createdAt
            account.updatedAt = Date()
            mutation = .init(ledgerID: ledgerID, kind: .saveAccount, account: account, baseAccount: base)
        case .deleteAccount:
            guard let account = accounts.first(where: { $0.id == previous.account?.id }) else {
                try discardFailure(id)
                return
            }
            mutation = .init(ledgerID: ledgerID, kind: .deleteAccount, account: account, baseAccount: account,
                             accountEntries: records.filter { $0.accountID == account.id })
        }
        var next = state
        do { try next.enqueue(mutation) }
        catch { throw localized(error) }
        next.discardFailure(id)
        try commit(next)
        sendPending()
    }

    private func currentLedgerID() throws -> UUID {
        guard let id = state.snapshot?.ledgerID else {
            throw StoreError(message: message("Open MiniBill on iPhone to sync your accounts."))
        }
        return id
    }

    private func enqueue(_ mutation: WatchLedgerMutation) throws {
        var next = state
        do { try next.enqueue(mutation) }
        catch { throw localized(error) }
        try commit(next)
        sendPending()
    }

    private func commit(_ next: WatchLedgerState) throws {
        guard canPersist else { throw StoreError(message: message("Could not read saved data. Try opening MiniBill again.")) }
        do {
            try JSONEncoder().encode(next).write(to: cacheURL, options: .atomic)
        } catch {
            throw StoreError(message: message("Could not save on Apple Watch. Your changes are still on screen."))
        }
        state = next
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        repairSelection()
    }

    private func repairSelection() {
        if !accounts.contains(where: { $0.id == selectedAccountID }), let first = accounts.first {
            selectedAccountID = first.id
        }
    }

    private func receive(_ payload: [String: Any]) {
        if payload[WatchLedgerTransport.errorKey] as? Bool == true {
            errorMessage = message("Sync will retry when iPhone is available.")
            return
        }
        guard let data = payload[WatchLedgerTransport.snapshotKey] as? Data else { return }
        do {
            let snapshot = try JSONDecoder().decode(WatchLedgerSnapshot.self, from: data)
            guard snapshot.schemaVersion == 1 else {
                errorMessage = message("The sync data could not be read. Update MiniBill on both devices.")
                return
            }
            var next = state
            next.receive(snapshot)
            guard next != state else { return }
            try commit(next)
            retryAttempt = 0
            retryTask?.cancel()
            retryTask = nil
            cancelAcknowledgedTransfers()
            sendPending()
        } catch {
            errorMessage = (error as? StoreError)?.message ?? message("The sync data could not be read. Update MiniBill on both devices.")
        }
    }

    private func sendPending() {
        let session = WCSession.default
        guard canPersist, session.activationState == .activated, let mutation = state.pending.first else { return }
        do {
            let data = try JSONEncoder().encode(mutation)
            let identifier = mutation.id.uuidString
            if data.count <= WatchLedgerTransport.inlineLimit {
                let payload: [String: Any] = [WatchLedgerTransport.mutationKey: data, "mutationID": identifier]
                if !session.outstandingUserInfoTransfers.contains(where: { $0.userInfo["mutationID"] as? String == identifier }) {
                    session.transferUserInfo(payload)
                }
                if session.isReachable, inFlightMessage != mutation.id {
                    inFlightMessage = mutation.id
                    session.sendMessage(payload, replyHandler: { [weak self] reply in
                        Task { @MainActor in
                            self?.inFlightMessage = nil
                            self?.receive(reply)
                        }
                    }, errorHandler: { [weak self] _ in
                        Task { @MainActor in self?.inFlightMessage = nil }
                    })
                }
            } else if !session.outstandingFileTransfers.contains(where: { $0.file.metadata?["mutationID"] as? String == identifier }) {
                let url = directory.appendingPathComponent(identifier).appendingPathExtension("transfer")
                try data.write(to: url, options: .atomic)
                session.transferFile(url, metadata: [WatchLedgerTransport.mutationKey: true, "mutationID": identifier])
            }
        } catch {
            errorMessage = message("Sync will retry when iPhone is available.")
            scheduleRetry()
        }
    }

    private func scheduleRetry() {
        guard retryTask == nil else { return }
        retryAttempt = min(retryAttempt + 1, 5)
        let delay = UInt64(1 << retryAttempt) * 1_000_000_000
        retryTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: delay) }
            catch { return }
            guard let self else { return }
            self.retryTask = nil
            if WCSession.default.activationState == .notActivated { WCSession.default.activate() }
            else { self.refresh() }
        }
    }

    private func retryFailedTransfer() {
        // Requeue once while background runtime is available; WCSession owns this durable retry.
        if retryAttempt == 0, WCSession.default.activationState == .activated {
            retryAttempt = 1
            refresh()
        } else {
            scheduleRetry()
        }
    }

    private func cancelAcknowledgedTransfers() {
        let pending = Set(state.pending.map { $0.id.uuidString })
        for transfer in WCSession.default.outstandingUserInfoTransfers {
            if let id = transfer.userInfo["mutationID"] as? String, !pending.contains(id) { transfer.cancel() }
        }
        for transfer in WCSession.default.outstandingFileTransfers {
            if let id = transfer.file.metadata?["mutationID"] as? String, !pending.contains(id) { transfer.cancel() }
        }
    }

    private func localized(_ error: Error) -> StoreError {
        let key: String
        switch error as? WatchSyncRejection {
        case .conflict: key = "This item changed on iPhone. Review the latest version."
        case .accountMissing: key = "This account no longer exists."
        case .lastAccount: key = "Keep at least one account."
        default: key = "Check the amount, project and account name."
        }
        return StoreError(message: message(key))
    }

    private func message(_ key: String) -> String {
        let bundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        return bundle.localizedString(forKey: key, value: key, table: "WatchLocalizable")
    }

    private struct StoreError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if error != nil { self.scheduleRetry() }
            else { self.refresh() }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receiveInBackground(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        receiveInBackground(userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?[WatchLedgerTransport.snapshotKey] as? Bool == true,
              let data = try? Data(contentsOf: file.fileURL) else { return }
        receiveInBackground([WatchLedgerTransport.snapshotKey: data])
    }

    private nonisolated func receiveInBackground(_ payload: [String: Any]) {
        WatchReceiveActivity.shared.begin()
        Task { @MainActor in
            self.receive(payload)
            WatchReceiveActivity.shared.end()
            NotificationCenter.default.post(name: .watchLedgerReceived, object: nil)
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        if error != nil {
            let id = fileTransfer.file.metadata?["mutationID"] as? String
            Task { @MainActor in
                if self.state.pending.contains(where: { $0.id.uuidString == id }) { self.retryFailedTransfer() }
            }
        }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        if error != nil {
            let id = userInfoTransfer.userInfo["mutationID"] as? String
            let isRequest = userInfoTransfer.userInfo[WatchLedgerTransport.requestKey] as? Bool == true
            Task { @MainActor in
                if isRequest || self.state.pending.contains(where: { $0.id.uuidString == id }) { self.retryFailedTransfer() }
            }
        }
    }
}

private extension Notification.Name {
    static let watchLedgerReceived = Notification.Name("watchLedgerReceived")
}

private final class WatchReceiveActivity: @unchecked Sendable {
    static let shared = WatchReceiveActivity()
    private let lock = NSLock()
    private var count = 0
    func begin() { lock.lock(); count += 1; lock.unlock() }
    func end() { lock.lock(); count -= 1; lock.unlock() }
    var isIdle: Bool {
        lock.lock()
        defer { lock.unlock() }
        return count == 0
    }
}

@MainActor
final class WatchBackgroundDelegate: NSObject, WKApplicationDelegate {
    private var tasks: [WKWatchConnectivityRefreshBackgroundTask] = []
    private var activationObserver: NSKeyValueObservation?
    private var contentObserver: NSKeyValueObservation?
    private var receiveObserver: NSObjectProtocol?

    func applicationDidFinishLaunching() {
        WatchLedgerStore.shared.start()
        activationObserver = WCSession.default.observe(\.activationState) { [weak self] _, _ in
            Task { @MainActor in self?.completeTasks() }
        }
        contentObserver = WCSession.default.observe(\.hasContentPending) { [weak self] _, _ in
            Task { @MainActor in self?.completeTasks() }
        }
        receiveObserver = NotificationCenter.default.addObserver(forName: .watchLedgerReceived, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.completeTasks() }
        }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let connectivityTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                tasks.append(connectivityTask)
                connectivityTask.expirationHandler = { [weak self, weak connectivityTask] in
                    Task { @MainActor in
                        guard let self, let task = connectivityTask,
                              self.tasks.contains(where: { $0 === task }) else { return }
                        task.setTaskCompletedWithSnapshot(false)
                        self.tasks.removeAll { $0 === task }
                    }
                }
            } else if let snapshotTask = task as? WKSnapshotRefreshBackgroundTask {
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: .distantFuture, userInfo: nil)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
        WatchLedgerStore.shared.start()
        completeTasks()
    }

    private func completeTasks() {
        guard WCSession.default.activationState == .activated,
              !WCSession.default.hasContentPending, WatchReceiveActivity.shared.isIdle else { return }
        for task in tasks { task.setTaskCompletedWithSnapshot(false) }
        tasks.removeAll()
    }
}

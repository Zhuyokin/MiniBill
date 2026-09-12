import Foundation
import SwiftData
import WatchConnectivity
import OSLog

@MainActor
final class PhoneWatchSyncService: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchSyncService()
    private let logger = Logger(subsystem: "com.masdey.minibill", category: "WatchSync")
    private var container: ModelContainer?
    private var saveObserver: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0
    private var snapshotNeedsSending = false
    private let defaults = UserDefaults.standard

    private var ledgerID: UUID {
        let key = "watchSync.ledgerID"
        if let value = defaults.string(forKey: key), let id = UUID(uuidString: value) { return id }
        let id = UUID()
        defaults.set(id.uuidString, forKey: key)
        return id
    }

    func start(container: ModelContainer) {
        self.container = container
        guard WCSession.isSupported() else { return }
        if saveObserver == nil {
            saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.scheduleRefresh() }
            }
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        refresh()
    }

    func refresh() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        do { _ = try publishSnapshot() }
        catch {
            logger.error("Could not send ledger: \(error.localizedDescription, privacy: .public)")
            scheduleRetry()
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 250_000_000) }
            catch { return }
            self?.refresh()
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
        if retryAttempt == 0, WCSession.default.activationState == .activated {
            retryAttempt = 1
            refresh()
        } else {
            scheduleRetry()
        }
    }

    @discardableResult
    private func publishSnapshot() throws -> [String: Any] {
        guard let container else { return [WatchLedgerTransport.errorKey: true] }
        let revision = Int64(defaults.integer(forKey: "watchSync.revision")) + 1
        let snapshot = try WatchLedgerPhoneStore.snapshot(
            ledgerID: ledgerID, revision: revision, languageCode: AppLanguage.current.rawValue, in: container
        )
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(revision, forKey: "watchSync.revision")
        let session = WCSession.default
        if data.count <= WatchLedgerTransport.inlineLimit {
            let payload: [String: Any] = [WatchLedgerTransport.snapshotKey: data]
            try session.updateApplicationContext(payload)
            snapshotNeedsSending = false
            return payload
        }
        if !session.outstandingFileTransfers.isEmpty {
            snapshotNeedsSending = true
            try session.updateApplicationContext(["snapshotRevision": revision])
            return ["snapshotQueued": true]
        }
        let directory = try transferDirectory()
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        try data.write(to: url, options: .atomic)
        snapshotNeedsSending = false
        session.transferFile(url, metadata: [WatchLedgerTransport.snapshotKey: true])
        try session.updateApplicationContext(["snapshotRevision": revision])
        return ["snapshotQueued": true]
    }

    private func transferDirectory() throws -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WatchTransfers", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func receive(_ payload: [String: Any], reply: (([String: Any]) -> Void)? = nil) {
        guard let container else {
            reply?([WatchLedgerTransport.errorKey: true])
            return
        }
        do {
            if let data = payload[WatchLedgerTransport.mutationKey] as? Data {
                let mutation = try JSONDecoder().decode(WatchLedgerMutation.self, from: data)
                _ = try WatchLedgerPhoneStore.apply(mutation, ledgerID: ledgerID, in: container)
            } else if payload[WatchLedgerTransport.requestKey] as? Bool != true {
                reply?([WatchLedgerTransport.errorKey: true])
                return
            }
            let response = try publishSnapshot()
            reply?(response)
        } catch {
            logger.error("Could not apply Watch change: \(error.localizedDescription, privacy: .public)")
            scheduleRetry()
            reply?([WatchLedgerTransport.errorKey: true])
        }
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

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in self.receive(message, reply: replyHandler) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in self.receive(userInfo) }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?[WatchLedgerTransport.mutationKey] as? Bool == true,
              let data = try? Data(contentsOf: file.fileURL) else { return }
        Task { @MainActor in self.receive([WatchLedgerTransport.mutationKey: data]) }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
        Task { @MainActor in
            if error != nil { self.retryFailedTransfer() }
            else {
                self.retryAttempt = 0
                if self.snapshotNeedsSending { self.refresh() }
            }
        }
    }
}

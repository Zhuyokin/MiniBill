import Foundation

public enum WatchMutationKind: String, Codable, Sendable {
    case saveEntry, deleteEntry, saveAccount, deleteAccount
}

public enum WatchSyncRejection: String, Codable, Error, Sendable {
    case conflict, accountMissing, lastAccount, invalidData
}

public struct WatchLedgerMutation: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let ledgerID: UUID
    public let kind: WatchMutationKind
    public let record: LedgerRecord?
    public let baseRecord: LedgerRecord?
    public let account: LedgerAccountRecord?
    public let baseAccount: LedgerAccountRecord?
    public let accountEntries: [LedgerRecord]?

    public init(id: UUID = UUID(), ledgerID: UUID, kind: WatchMutationKind,
                record: LedgerRecord? = nil, baseRecord: LedgerRecord? = nil,
                account: LedgerAccountRecord? = nil, baseAccount: LedgerAccountRecord? = nil,
                accountEntries: [LedgerRecord]? = nil) {
        self.id = id
        self.ledgerID = ledgerID
        self.kind = kind
        self.record = record
        self.baseRecord = baseRecord
        self.account = account
        self.baseAccount = baseAccount
        self.accountEntries = accountEntries
    }
}

public struct WatchMutationReceipt: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let rejection: WatchSyncRejection?

    public init(id: UUID, rejection: WatchSyncRejection? = nil) {
        self.id = id
        self.rejection = rejection
    }
}

public struct WatchLedgerSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public let ledgerID: UUID
    public let revision: Int64
    public let generatedAt: Date
    public let languageCode: String
    public let accounts: [LedgerAccountRecord]
    public let records: [LedgerRecord]
    public let receipts: [WatchMutationReceipt]

    public init(ledgerID: UUID, revision: Int64, generatedAt: Date = Date(), languageCode: String,
                accounts: [LedgerAccountRecord], records: [LedgerRecord], receipts: [WatchMutationReceipt] = []) {
        self.ledgerID = ledgerID
        self.revision = revision
        self.generatedAt = generatedAt
        self.languageCode = languageCode
        self.accounts = accounts
        self.records = records
        self.receipts = receipts
    }
}

public struct WatchSyncFailure: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { mutation.id }
    public let mutation: WatchLedgerMutation
    public let reason: WatchSyncRejection
}

public enum WatchLedgerReducer {
    public static func apply(_ mutation: WatchLedgerMutation,
                             records: inout [LedgerRecord],
                             accounts: inout [LedgerAccountRecord]) -> WatchSyncRejection? {
        switch mutation.kind {
        case .saveEntry:
            guard let record = mutation.record,
                  record.occurredAt.timeIntervalSince1970.isFinite,
                  record.createdAt.timeIntervalSince1970.isFinite,
                  record.updatedAt.timeIntervalSince1970.isFinite else { return .invalidData }
            guard accounts.contains(where: { $0.id == record.accountID }) else { return .accountMissing }
            do {
                try EntryValidator.validate(amountCents: record.amountCents, projectName: record.projectName, note: record.note)
            } catch { return .invalidData }
            let existing = records.first { $0.id == record.id }
            guard existing == mutation.baseRecord else { return .conflict }
            if let base = mutation.baseRecord {
                guard base.id == record.id, base.accountID == record.accountID,
                      base.createdAt == record.createdAt else { return .invalidData }
            }
            records.removeAll { $0.id == record.id }
            records.append(record)
        case .deleteEntry:
            guard let base = mutation.baseRecord, mutation.record?.id == base.id else { return .invalidData }
            guard records.first(where: { $0.id == base.id }) == base else { return .conflict }
            records.removeAll { $0.id == base.id }
        case .saveAccount:
            guard let account = mutation.account,
                  account.createdAt.timeIntervalSince1970.isFinite,
                  account.updatedAt.timeIntervalSince1970.isFinite else { return .invalidData }
            do {
                guard try LedgerAccountName.normalized(account.name) == account.name else { return .invalidData }
            } catch { return .invalidData }
            guard accounts.first(where: { $0.id == account.id }) == mutation.baseAccount else { return .conflict }
            if let base = mutation.baseAccount {
                guard base.id == account.id, base.createdAt == account.createdAt else { return .invalidData }
            }
            accounts.removeAll { $0.id == account.id }
            accounts.append(account)
        case .deleteAccount:
            guard let base = mutation.baseAccount, mutation.account?.id == base.id,
                  let expectedEntries = mutation.accountEntries else { return .invalidData }
            guard accounts.count > 1 else { return .lastAccount }
            guard accounts.first(where: { $0.id == base.id }) == base,
                  sorted(records.filter { $0.accountID == base.id }) == sorted(expectedEntries) else { return .conflict }
            records.removeAll { $0.accountID == base.id }
            accounts.removeAll { $0.id == base.id }
        }
        return nil
    }

    private static func sorted(_ records: [LedgerRecord]) -> [LedgerRecord] {
        records.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

/// The cache and outbox are persisted together before a local change becomes visible.
public struct WatchLedgerState: Codable, Equatable, Sendable {
    public private(set) var snapshot: WatchLedgerSnapshot?
    public private(set) var pending: [WatchLedgerMutation] = []
    public private(set) var failedChanges: [WatchSyncFailure] = []
    private var retiredLedgerIDs: Set<UUID> = []

    public init() {}

    public var records: [LedgerRecord] { projected.records }
    public var accounts: [LedgerAccountRecord] { projected.accounts }

    private var projected: (records: [LedgerRecord], accounts: [LedgerAccountRecord]) {
        var records = snapshot?.records ?? []
        var accounts = snapshot?.accounts ?? []
        for mutation in pending {
            _ = WatchLedgerReducer.apply(mutation, records: &records, accounts: &accounts)
        }
        return (records, accounts)
    }

    public mutating func enqueue(_ mutation: WatchLedgerMutation) throws {
        guard let snapshot, snapshot.ledgerID == mutation.ledgerID else { throw WatchSyncRejection.conflict }
        var projection = projected
        if let rejection = WatchLedgerReducer.apply(mutation, records: &projection.records, accounts: &projection.accounts) {
            throw rejection
        }
        pending.append(mutation)
    }

    public mutating func receive(_ incoming: WatchLedgerSnapshot) {
        guard incoming.schemaVersion == 1, !incoming.accounts.isEmpty,
              !retiredLedgerIDs.contains(incoming.ledgerID) else { return }
        if let snapshot, snapshot.ledgerID == incoming.ledgerID, incoming.revision <= snapshot.revision { return }
        if let snapshot, snapshot.ledgerID != incoming.ledgerID {
            retiredLedgerIDs.insert(snapshot.ledgerID)
            failedChanges.append(contentsOf: pending.map { WatchSyncFailure(mutation: $0, reason: .conflict) })
            pending.removeAll()
        }
        let receipts = Dictionary(incoming.receipts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        pending.removeAll { mutation in
            guard let receipt = receipts[mutation.id] else { return false }
            if let rejection = receipt.rejection {
                failedChanges.append(WatchSyncFailure(mutation: mutation, reason: rejection))
            }
            return true
        }
        snapshot = incoming
    }

    public mutating func discardFailure(_ id: UUID) {
        failedChanges.removeAll { $0.id == id }
    }
}

public enum WatchLedgerTransport {
    public static let snapshotKey = "ledgerSnapshot"
    public static let mutationKey = "ledgerMutation"
    public static let requestKey = "requestLedger"
    public static let errorKey = "ledgerError"
    public static let inlineLimit = 48_000
}

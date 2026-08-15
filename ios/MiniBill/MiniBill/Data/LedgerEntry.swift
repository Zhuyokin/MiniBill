import Foundation
import SwiftData

#if SWIFT_PACKAGE
import MiniBillCore
#endif

@Model
public final class LedgerEntry {
    @Attribute(.unique) public var id: UUID
    /// Optional only so existing v1 stores can migrate without a destructive schema change.
    /// New entries always receive an account identifier; nil legacy rows resolve to Default.
    public var accountID: UUID?
    public var kindRawValue: String
    public var amountCents: Int64
    public var projectName: String
    public var note: String?
    public var occurredAt: Date
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        accountID: UUID = LedgerAccountDefaults.id,
        kindRawValue: String,
        amountCents: Int64,
        projectName: String,
        note: String? = nil,
        occurredAt: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.accountID = accountID
        self.kindRawValue = kindRawValue
        self.amountCents = amountCents
        self.projectName = projectName
        self.note = note
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var kind: LedgerKind {
        get { LedgerKind(rawValue: kindRawValue) ?? .expense }
        set { kindRawValue = newValue.rawValue }
    }

    public var resolvedAccountID: UUID {
        accountID ?? LedgerAccountDefaults.id
    }
}

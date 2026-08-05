import Foundation
import SwiftData

#if SWIFT_PACKAGE
import MiniBillCore
#endif

@Model
public final class LedgerEntry {
    @Attribute(.unique) public var id: UUID
    public var kindRawValue: String
    public var amountCents: Int64
    public var projectName: String
    public var note: String?
    public var occurredAt: Date
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        kindRawValue: String,
        amountCents: Int64,
        projectName: String,
        note: String? = nil,
        occurredAt: Date,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
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
}

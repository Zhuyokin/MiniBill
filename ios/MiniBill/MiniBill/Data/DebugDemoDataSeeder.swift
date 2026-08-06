#if DEBUG
import Foundation
import SwiftData

#if SWIFT_PACKAGE
import MiniBillCore
#endif

public enum DebugDemoDataSeeder {
    @MainActor
    public static func seedIfNeeded(
        in container: ModelContainer,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        let context = container.mainContext
        let existing = try context.fetch(FetchDescriptor<LedgerEntry>())
        let demoEntries = existing.filter { DebugDemoDataFactory.isDemoID($0.id) }
        let records = DebugDemoDataFactory.records(referenceDate: referenceDate, calendar: calendar)

        guard demoEntries.count == records.count else {
            for entry in demoEntries {
                context.delete(entry)
            }
            for record in records {
                context.insert(LedgerEntryMapper.entry(from: record))
            }
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
            return
        }
    }
}
#endif

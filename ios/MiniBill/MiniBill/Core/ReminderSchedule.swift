import Foundation

public enum ReminderSchedule {
    public static func monthEnds(startingAt start: Date, count: Int, calendar: Calendar) -> [Date] {
        guard count > 0 else { return [] }
        let startComponents = calendar.dateComponents([.year, .month], from: start)
        guard let firstMonth = calendar.date(from: startComponents) else { return [] }

        return (0..<count).compactMap { offset in
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: firstMonth),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                return nil
            }
            return calendar.date(byAdding: .day, value: -1, to: nextMonth)
        }
    }
}

/// Replaces one logical reminder channel as a unit. If any request cannot be
/// added, the channel is cleared again so callers never leave a partial batch.
public enum ReminderBatchScheduler {
    public static func replace<Item>(
        items: [Item],
        removeExisting: () async -> Void,
        add: (Item) async throws -> Void
    ) async throws {
        await removeExisting()

        do {
            for item in items {
                try await add(item)
            }
        } catch {
            await removeExisting()
            throw error
        }
    }
}

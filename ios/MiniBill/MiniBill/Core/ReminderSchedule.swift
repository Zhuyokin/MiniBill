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

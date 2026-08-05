import Foundation

public enum LedgerAnalytics {
    public static func summary(records: [LedgerRecord], month: Date, calendar: Calendar) -> MonthlySummary {
        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            return MonthlySummary(month: month, incomeCents: 0, expenseCents: 0, netCents: 0, recordCount: 0, dailyNet: [], incomeProjects: [], expenseProjects: [])
        }

        let selected = records.filter {
            interval.start <= $0.occurredAt
                && $0.occurredAt < interval.end
                && $0.amountCents > 0
        }
        var income: Int64 = 0
        var expense: Int64 = 0
        var days: [Date: DayAccumulator] = [:]

        for record in selected {
            let day = calendar.startOfDay(for: record.occurredAt)
            switch record.kind {
            case .income:
                income = addingClamped(income, record.amountCents)
                var value = days[day, default: DayAccumulator()]
                value.incomeCents = addingClamped(value.incomeCents, record.amountCents)
                days[day] = value
            case .expense:
                expense = addingClamped(expense, record.amountCents)
                var value = days[day, default: DayAccumulator()]
                value.expenseCents = addingClamped(value.expenseCents, record.amountCents)
                days[day] = value
            }
        }

        return MonthlySummary(
            month: interval.start,
            incomeCents: income,
            expenseCents: expense,
            netCents: subtractingClamped(income, expense),
            recordCount: selected.count,
            dailyNet: days.map { date, value in
                DailyTotal(
                    date: date,
                    netCents: subtractingClamped(value.incomeCents, value.expenseCents)
                )
            }
            .sorted { $0.date < $1.date },
            incomeProjects: projectTotals(records: selected.filter { $0.kind == .income }),
            expenseProjects: projectTotals(records: selected.filter { $0.kind == .expense })
        )
    }

    private struct ProjectAccumulator {
        var totalCents: Int64
        var count: Int
        var newestRecord: LedgerRecord
    }

    private struct DayAccumulator {
        var incomeCents: Int64 = 0
        var expenseCents: Int64 = 0
    }

    private static func projectTotals(records: [LedgerRecord]) -> [ProjectTotal] {
        var totals: [String: ProjectAccumulator] = [:]
        for record in records {
            let key = ProjectNameNormalizer.normalizedKey(record.projectName)
            guard !key.isEmpty else { continue }
            if var value = totals[key] {
                value.totalCents = addingClamped(value.totalCents, record.amountCents)
                value.count += 1
                if record.occurredAt > value.newestRecord.occurredAt ||
                    (record.occurredAt == value.newestRecord.occurredAt && record.id.uuidString < value.newestRecord.id.uuidString) {
                    value.newestRecord = record
                }
                totals[key] = value
            } else {
                totals[key] = ProjectAccumulator(totalCents: record.amountCents, count: 1, newestRecord: record)
            }
        }

        return totals.map { key, value in
            ProjectTotal(
                normalizedKey: key,
                displayName: value.newestRecord.projectName.trimmingCharacters(in: .whitespacesAndNewlines),
                totalCents: value.totalCents,
                recordCount: value.count
            )
        }
        .sorted {
            $0.totalCents == $1.totalCents
                ? $0.normalizedKey < $1.normalizedKey
                : $0.totalCents > $1.totalCents
        }
    }

    /// Saturates corrupt or legacy values instead of trapping the process.
    /// `Int64.min` is deliberately avoided because chart code may take abs().
    private static func addingClamped(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard overflow else { return value }
        return rhs >= 0 ? .max : -Int64.max
    }

    private static func subtractingClamped(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.subtractingReportingOverflow(rhs)
        guard overflow else { return value }
        return rhs >= 0 ? -Int64.max : .max
    }
}

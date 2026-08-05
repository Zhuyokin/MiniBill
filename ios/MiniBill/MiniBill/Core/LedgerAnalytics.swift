import Foundation

public enum LedgerAnalytics {
    public static func summary(records: [LedgerRecord], month: Date, calendar: Calendar) -> MonthlySummary {
        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            return MonthlySummary(month: month, incomeCents: 0, expenseCents: 0, netCents: 0, recordCount: 0, dailyNet: [], incomeProjects: [], expenseProjects: [])
        }

        let selected = records.filter { interval.contains($0.occurredAt) }
        var income: Int64 = 0
        var expense: Int64 = 0
        var days: [Date: Int64] = [:]

        for record in selected {
            let day = calendar.startOfDay(for: record.occurredAt)
            switch record.kind {
            case .income:
                income += record.amountCents
                days[day, default: 0] += record.amountCents
            case .expense:
                expense += record.amountCents
                days[day, default: 0] -= record.amountCents
            }
        }

        return MonthlySummary(
            month: interval.start,
            incomeCents: income,
            expenseCents: expense,
            netCents: income - expense,
            recordCount: selected.count,
            dailyNet: days.map(DailyTotal.init).sorted { $0.date < $1.date },
            incomeProjects: projectTotals(records: selected.filter { $0.kind == .income }),
            expenseProjects: projectTotals(records: selected.filter { $0.kind == .expense })
        )
    }

    private struct ProjectAccumulator {
        var totalCents: Int64
        var count: Int
        var newestRecord: LedgerRecord
    }

    private static func projectTotals(records: [LedgerRecord]) -> [ProjectTotal] {
        var totals: [String: ProjectAccumulator] = [:]
        for record in records {
            let key = ProjectNameNormalizer.normalizedKey(record.projectName)
            guard !key.isEmpty else { continue }
            if var value = totals[key] {
                value.totalCents += record.amountCents
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
}

#if DEBUG
import Foundation

public enum DebugDemoDataFactory {
    public static let dayCount = 365
    private static let demoUUIDPrefix = "4D42494C-4C44-4D00-8000-"

    public static func records(
        referenceDate: Date,
        calendar: Calendar
    ) -> [LedgerRecord] {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: referenceDate)),
              let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: yesterday) else {
            return []
        }

        var records: [LedgerRecord] = []
        records.reserveCapacity(dayCount * 2)
        var ordinal = 1

        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: day)

            append(
                to: &records,
                ordinal: &ordinal,
                day: day,
                hour: 9,
                minute: 10,
                kind: .expense,
                amountCents: amount(day: offset, slot: 0, range: 18...180),
                projectName: expenseProjects[offset % expenseProjects.count],
                note: offset % 17 == 0 ? "演示数据 · 日常经营" : nil,
                calendar: calendar
            )

            if weekday != 1 {
                append(
                    to: &records,
                    ordinal: &ordinal,
                    day: day,
                    hour: 18,
                    minute: 30,
                    kind: .income,
                    amountCents: amount(day: offset, slot: 1, range: 90...780),
                    projectName: incomeProjects[(offset / 3) % incomeProjects.count],
                    note: offset % 11 == 0 ? "演示数据 · 当日结算" : nil,
                    calendar: calendar
                )
            }

            if offset % 3 == 0 {
                append(
                    to: &records,
                    ordinal: &ordinal,
                    day: day,
                    hour: 13,
                    minute: 20,
                    kind: .expense,
                    amountCents: amount(day: offset, slot: 2, range: 30...260),
                    projectName: expenseProjects[(offset + 2) % expenseProjects.count],
                    note: nil,
                    calendar: calendar
                )
            }

            if weekday == 2 {
                append(
                    to: &records,
                    ordinal: &ordinal,
                    day: day,
                    hour: 8,
                    minute: 40,
                    kind: .expense,
                    amountCents: amount(day: offset, slot: 3, range: 350...650),
                    projectName: "摊位租金",
                    note: "演示数据 · 每周固定支出",
                    calendar: calendar
                )
            }

            if offset % 10 == 0 {
                append(
                    to: &records,
                    ordinal: &ordinal,
                    day: day,
                    hour: 20,
                    minute: 5,
                    kind: .income,
                    amountCents: amount(day: offset, slot: 4, range: 200...1_100),
                    projectName: incomeProjects[(offset + 1) % incomeProjects.count],
                    note: "演示数据 · 额外订单",
                    calendar: calendar
                )
            }
        }

        return records
    }

    public static func isDemoID(_ id: UUID) -> Bool {
        id.uuidString.hasPrefix(demoUUIDPrefix)
    }

    private static let incomeProjects = [
        "门店销售", "线上订单", "跑腿服务", "手工作品", "咨询服务"
    ]

    private static let expenseProjects = [
        "原料采购", "包装耗材", "交通配送", "平台服务费", "设备维护", "营销推广"
    ]

    private static func append(
        to records: inout [LedgerRecord],
        ordinal: inout Int,
        day: Date,
        hour: Int,
        minute: Int,
        kind: LedgerKind,
        amountCents: Int64,
        projectName: String,
        note: String?,
        calendar: Calendar
    ) {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        guard let occurredAt = calendar.date(from: components),
              let id = UUID(uuidString: String(format: "%@%012llX", demoUUIDPrefix, UInt64(ordinal))) else {
            return
        }

        records.append(
            LedgerRecord(
                id: id,
                kind: kind,
                amountCents: amountCents,
                projectName: projectName,
                note: note,
                occurredAt: occurredAt,
                createdAt: occurredAt,
                updatedAt: occurredAt
            )
        )
        ordinal += 1
    }

    private static func amount(day: Int, slot: Int, range: ClosedRange<Int64>) -> Int64 {
        var value = UInt64(day + 1) &* 1_103_515_245
        value = value &+ UInt64(slot + 17) &* 12_345_679
        let whole = range.lowerBound + Int64(value % UInt64(range.upperBound - range.lowerBound + 1))
        let fraction = [0, 20, 50, 80][Int((value >> 8) % 4)]
        return whole * 100 + Int64(fraction)
    }
}
#endif

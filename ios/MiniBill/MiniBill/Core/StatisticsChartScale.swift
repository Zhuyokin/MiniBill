import Foundation

public enum StatisticsChartScale {
    public static func monthInterval(containing month: Date, calendar: Calendar) -> DateInterval? {
        calendar.dateInterval(of: .month, for: month)
    }

    public static func symmetricYDomain(
        values: [Int64],
        minimumMagnitude: Double = 100
    ) -> ClosedRange<Double> {
        let largest = values.reduce(0.0) { maximum, value in
            max(maximum, magnitude(of: value))
        }
        let padded = max(minimumMagnitude, largest * 1.12)
        return -padded...padded
    }

    private static func magnitude(of value: Int64) -> Double {
        if value == .min {
            return Double(Int64.max) + 1
        }
        return Double(abs(value))
    }
}

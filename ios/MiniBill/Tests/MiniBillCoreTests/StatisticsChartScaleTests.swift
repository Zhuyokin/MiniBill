import XCTest
@testable import MiniBillCore

final class StatisticsChartScaleTests: XCTestCase {
    func testMonthIntervalCoversTheWholeSelectedMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = ISO8601DateFormatter().date(from: "2026-02-14T10:00:00Z")!

        let interval = try XCTUnwrap(StatisticsChartScale.monthInterval(containing: date, calendar: calendar))
        XCTAssertEqual(calendar.component(.day, from: interval.start), 1)
        XCTAssertEqual(calendar.component(.month, from: interval.start), 2)
        XCTAssertEqual(calendar.component(.day, from: interval.end), 1)
        XCTAssertEqual(calendar.component(.month, from: interval.end), 3)
    }

    func testYDomainIsSymmetricForSparsePositiveNegativeAndZeroValues() {
        let positive = StatisticsChartScale.symmetricYDomain(values: [450])
        let negative = StatisticsChartScale.symmetricYDomain(values: [-900])
        let mixed = StatisticsChartScale.symmetricYDomain(values: [-300, 700])
        let zero = StatisticsChartScale.symmetricYDomain(values: [0])

        XCTAssertEqual(positive.lowerBound, -positive.upperBound)
        XCTAssertEqual(negative.lowerBound, -negative.upperBound)
        XCTAssertEqual(mixed.lowerBound, -mixed.upperBound)
        XCTAssertEqual(zero, -100...100)
        XCTAssertGreaterThan(positive.upperBound, 450)
        XCTAssertGreaterThan(negative.upperBound, 900)
        XCTAssertGreaterThan(mixed.upperBound, 700)
    }

    func testYDomainHandlesExtremeInt64WithoutOverflow() {
        let domain = StatisticsChartScale.symmetricYDomain(values: [.min, .max])
        XCTAssertTrue(domain.lowerBound.isFinite)
        XCTAssertTrue(domain.upperBound.isFinite)
        XCTAssertEqual(domain.lowerBound, -domain.upperBound)
    }
}

import XCTest
@testable import Fast

final class FastTests: XCTestCase {
    func testTargetHoursValidation() throws {
        XCTAssertNoThrow(try FastValidator.validateTargetHours(1))
        XCTAssertNoThrow(try FastValidator.validateTargetHours(24))
        XCTAssertNoThrow(try FastValidator.validateTargetHours(240))
        XCTAssertThrowsError(try FastValidator.validateTargetHours(0))
        XCTAssertThrowsError(try FastValidator.validateTargetHours(241))
    }

    func testSingleActiveFastConstraint() throws {
        let now = Date()
        let active = FastEntry(start: now.addingTimeInterval(-3600), end: nil, targetHours: 24)
        XCTAssertThrowsError(
            try FastValidator.validateFast(
                start: now,
                end: nil,
                targetHours: 24,
                editingID: nil,
                existingFasts: [active],
                now: now
            )
        )
        // Editing the same active fast is allowed
        XCTAssertNoThrow(
            try FastValidator.validateFast(
                start: now.addingTimeInterval(-7200),
                end: nil,
                targetHours: 36,
                editingID: active.id,
                existingFasts: [active],
                now: now
            )
        )
    }

    func testMealValidation() throws {
        XCTAssertThrowsError(
            try FastValidator.validateMeal(
                description: "   ",
                calories: 200,
                proteinG: 20,
                carbsG: 10,
                fatG: 5
            )
        )
        XCTAssertThrowsError(
            try FastValidator.validateMeal(
                description: String(repeating: "a", count: 501),
                calories: 200,
                proteinG: 20,
                carbsG: 10,
                fatG: 5
            )
        )
        XCTAssertThrowsError(
            try FastValidator.validateMeal(
                description: "Eggs",
                calories: -10,
                proteinG: 20,
                carbsG: nil,
                fatG: nil
            )
        )
        let clean = try FastValidator.validateMeal(
            description: "  3 eggs  ",
            calories: 210,
            proteinG: 18,
            carbsG: 1,
            fatG: 15
        )
        XCTAssertEqual(clean, "3 eggs")
    }

    func testFastingZones() {
        XCTAssertEqual(FastingZone.zone(at: 0).name, "Blood sugar settling")
        XCTAssertEqual(FastingZone.zone(at: 12).name, "Glycogen depleting")
        XCTAssertEqual(FastingZone.zone(at: 24).name, "Autophagy")
        XCTAssertEqual(FastingZone.zone(at: 75).name, "Prolonged fast")
    }

    func testFormatters() {
        XCTAssertEqual(Formatters.hms(3661), "01:01:01")
        XCTAssertEqual(Formatters.duration(5400), "1h 30m")
        XCTAssertEqual(Formatters.hoursLabel(24), "24h")
        XCTAssertEqual(Formatters.hoursLabel(24.5), "24.5h")
    }
}

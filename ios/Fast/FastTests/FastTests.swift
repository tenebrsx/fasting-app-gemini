import SwiftData
import XCTest
@testable import Fast

final class FastTests: XCTestCase {
    func testTargetHoursValidation() throws {
        XCTAssertNoThrow(try FastValidator.validateTargetHours(1))
        XCTAssertNoThrow(try FastValidator.validateTargetHours(24))
        XCTAssertNoThrow(try FastValidator.validateTargetHours(240))
        XCTAssertThrowsError(try FastValidator.validateTargetHours(0))
        XCTAssertThrowsError(try FastValidator.validateTargetHours(241))
        XCTAssertThrowsError(try FastValidator.validateTargetHours(.nan))
    }

    func testFastValidationConstraints() throws {
        let now = Date()
        let active = FastEntry(start: now.addingTimeInterval(-3600), end: nil, targetHours: 24)

        // Cannot start a second active fast
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

        // End must be after start
        XCTAssertThrowsError(
            try FastValidator.validateFast(
                start: now,
                end: now.addingTimeInterval(-60),
                targetHours: 24,
                editingID: active.id,
                existingFasts: [active],
                now: now
            )
        )

        // End cannot be in the future (> 60s grace)
        XCTAssertThrowsError(
            try FastValidator.validateFast(
                start: now.addingTimeInterval(-3600),
                end: now.addingTimeInterval(300),
                targetHours: 24,
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
        XCTAssertThrowsError(
            try FastValidator.validateMeal(
                description: "Eggs",
                calories: 200,
                proteinG: -1,
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

    @MainActor
    func testSwiftDataPersistenceAndSettingsDeduplication() throws {
        let store = DataStore(inMemory: true)
        let context = store.container.mainContext

        // Insert duplicate settings and verify ensureSettings keeps the newest and deduplicates
        let older = UserSettings(proteinTarget: 100, defaultFastHours: 16, updatedAt: Date(timeIntervalSince1970: 100))
        let newer = UserSettings(proteinTarget: 140, defaultFastHours: 36, updatedAt: Date(timeIntervalSince1970: 200))
        context.insert(older)
        context.insert(newer)
        try context.save()

        let resolved = store.ensureSettings(in: context)
        XCTAssertEqual(resolved.proteinTarget, 140)
        XCTAssertEqual(resolved.defaultFastHours, 36)
        let remainingSettings = try context.fetch(FetchDescriptor<UserSettings>())
        XCTAssertEqual(remainingSettings.count, 1)

        // FastEntry goal check
        let start = Date(timeIntervalSince1970: 1000)
        let fast = FastEntry(start: start, end: start.addingTimeInterval(25 * 3600), targetHours: 24)
        context.insert(fast)
        XCTAssertTrue(fast.didHitGoal)
        XCTAssertFalse(fast.isActive)

        // MealEntry macro helpers
        let meal = MealEntry(mealDescription: "Steak & eggs", calories: 650, proteinG: 52, carbsG: 2, fatG: 46)
        context.insert(meal)
        try context.save()
        XCTAssertEqual(meal.value(for: .protein), 52)
        XCTAssertEqual(meal.value(for: .calories), 650)
        XCTAssertEqual(meal.value(for: .carbs), 2)
        XCTAssertEqual(meal.value(for: .fat), 46)
    }
}

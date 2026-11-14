import Foundation

enum ValidationError: LocalizedError {
    case invalidTargetHours
    case startInFuture
    case endBeforeStart
    case endInFuture
    case anotherFastActive
    case emptyMealDescription
    case mealDescriptionTooLong
    case negativeMacro(String)

    var errorDescription: String? {
        switch self {
        case .invalidTargetHours:
            "Pick between 1 and 240 hours."
        case .startInFuture:
            "Start time can't be in the future."
        case .endBeforeStart:
            "End time has to be after the start."
        case .endInFuture:
            "End time can't be in the future."
        case .anotherFastActive:
            "Another fast is already in progress. Add an end time."
        case .emptyMealDescription:
            "Describe the meal."
        case .mealDescriptionTooLong:
            "Meal description must be 500 characters or fewer."
        case .negativeMacro(let name):
            "\(name) can't be negative."
        }
    }
}

enum FastValidator {
    static let minTargetHours: Double = 1
    static let maxTargetHours: Double = 240
    static let maxDescriptionLength = 500

    static func validateTargetHours(_ hours: Double) throws {
        guard hours.isFinite, hours >= minTargetHours, hours <= maxTargetHours else {
            throw ValidationError.invalidTargetHours
        }
    }

    static func validateFast(
        start: Date,
        end: Date?,
        targetHours: Double,
        editingID: UUID?,
        existingFasts: [FastEntry],
        now: Date = Date()
    ) throws {
        try validateTargetHours(targetHours)

        if start > now.addingTimeInterval(60) {
            throw ValidationError.startInFuture
        }

        if let end {
            if end <= start {
                throw ValidationError.endBeforeStart
            }
            if end > now.addingTimeInterval(60) {
                throw ValidationError.endInFuture
            }
        } else {
            let hasOtherActive = existingFasts.contains { $0.end == nil && $0.id != editingID }
            if hasOtherActive {
                throw ValidationError.anotherFastActive
            }
        }
    }

    static func validateMeal(
        description: String,
        calories: Double?,
        proteinG: Double?,
        carbsG: Double?,
        fatG: Double?
    ) throws -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw ValidationError.emptyMealDescription
        }
        if trimmed.count > maxDescriptionLength {
            throw ValidationError.mealDescriptionTooLong
        }
        if let calories, calories < 0 { throw ValidationError.negativeMacro("Calories") }
        if let proteinG, proteinG < 0 { throw ValidationError.negativeMacro("Protein") }
        if let carbsG, carbsG < 0 { throw ValidationError.negativeMacro("Carbs") }
        if let fatG, fatG < 0 { throw ValidationError.negativeMacro("Fat") }
        return trimmed
    }
}

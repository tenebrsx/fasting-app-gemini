import Foundation
import SwiftData

@Model
final class UserSettings {
    var key: String = "main"
    var caloriesTarget: Double?
    var proteinTarget: Double? = 120
    var carbsTarget: Double?
    var fatTarget: Double?
    var defaultFastHours: Double = 24
    var updatedAt: Date = Date()

    init(
        key: String = "main",
        caloriesTarget: Double? = nil,
        proteinTarget: Double? = 120,
        carbsTarget: Double? = nil,
        fatTarget: Double? = nil,
        defaultFastHours: Double = 24,
        updatedAt: Date = Date()
    ) {
        self.key = key
        self.caloriesTarget = caloriesTarget
        self.proteinTarget = proteinTarget
        self.carbsTarget = carbsTarget
        self.fatTarget = fatTarget
        self.defaultFastHours = defaultFastHours
        self.updatedAt = updatedAt
    }

    func target(for macro: MacroKind) -> Double? {
        switch macro {
        case .protein: proteinTarget
        case .calories: caloriesTarget
        case .carbs: carbsTarget
        case .fat: fatTarget
        }
    }
}

import Foundation
import SwiftData

@Model
final class MealEntry {
    var id: UUID = UUID()
    var time: Date = Date()
    var mealDescription: String = ""
    var calories: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var source: String = "manual"
    var notes: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        time: Date = Date(),
        mealDescription: String = "",
        calories: Double? = nil,
        proteinG: Double? = nil,
        carbsG: Double? = nil,
        fatG: Double? = nil,
        source: String = "manual",
        notes: String = "",
        photoData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.time = time
        self.mealDescription = mealDescription
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.source = source
        self.notes = notes
        self.photoData = photoData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func value(for macro: MacroKind) -> Double {
        switch macro {
        case .protein: proteinG ?? 0
        case .calories: calories ?? 0
        case .carbs: carbsG ?? 0
        case .fat: fatG ?? 0
        }
    }
}

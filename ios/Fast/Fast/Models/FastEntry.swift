import Foundation
import SwiftData

@Model
final class FastEntry {
    var id: UUID = UUID()
    var start: Date = Date()
    var end: Date?
    var targetHours: Double = 24
    var notes: String = ""
    var source: String = "app"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        start: Date = Date(),
        end: Date? = nil,
        targetHours: Double = 24,
        notes: String = "",
        source: String = "app",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.targetHours = targetHours
        self.notes = notes
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isActive: Bool {
        end == nil
    }

    func duration(at referenceDate: Date = Date()) -> TimeInterval {
        max(0, (end ?? referenceDate).timeIntervalSince(start))
    }

    func elapsedHours(at referenceDate: Date = Date()) -> Double {
        duration(at: referenceDate) / 3600.0
    }

    var didHitGoal: Bool {
        guard let end else { return false }
        return end.timeIntervalSince(start) / 3600.0 >= targetHours
    }

    var goalDate: Date {
        start.addingTimeInterval(targetHours * 3600.0)
    }
}

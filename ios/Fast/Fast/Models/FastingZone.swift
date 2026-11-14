import SwiftUI

struct FastingZone: Identifiable, Sendable {
    let hours: Double
    let name: String
    let detail: String
    let color: Color
    let opacity: Double

    var id: Double { hours }

    static let all: [FastingZone] = [
        FastingZone(
            hours: 0,
            name: "Blood sugar settling",
            detail: "Digesting your last meal; insulin coming down.",
            color: Theme.sky,
            opacity: 1.0
        ),
        FastingZone(
            hours: 12,
            name: "Glycogen depleting",
            detail: "Liver glycogen runs low; the body leans on fat.",
            color: Theme.ember,
            opacity: 1.0
        ),
        FastingZone(
            hours: 18,
            name: "Fat burning",
            detail: "Fat becomes a main fuel and ketones start rising.",
            color: Theme.coral,
            opacity: 1.0
        ),
        FastingZone(
            hours: 24,
            name: "Autophagy",
            detail: "Cellular cleanup is thought to pick up around here.",
            color: Theme.orchid,
            opacity: 1.0
        ),
        FastingZone(
            hours: 36,
            name: "Deeper autophagy",
            detail: "Ketones keep climbing; hunger often eases.",
            color: Theme.orchid,
            opacity: 0.7
        ),
        FastingZone(
            hours: 48,
            name: "Deep ketosis",
            detail: "Growth hormone is reported to rise. Mind electrolytes.",
            color: Theme.teal,
            opacity: 1.0
        ),
        FastingZone(
            hours: 72,
            name: "Prolonged fast",
            detail: "Extended territory. Electrolytes and how you feel come first.",
            color: Theme.teal,
            opacity: 0.7
        ),
    ]

    static let presets: [Double] = [16, 18, 24, 36, 48, 72]

    static func zone(at elapsedHours: Double) -> FastingZone {
        all.last(where: { elapsedHours >= $0.hours }) ?? all[0]
    }
}

enum MacroKind: String, CaseIterable, Identifiable, Sendable {
    case protein
    case calories
    case carbs
    case fat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protein: "Protein"
        case .calories: "Calories"
        case .carbs: "Carbs"
        case .fat: "Fat"
        }
    }

    var unit: String {
        switch self {
        case .protein, .carbs, .fat: "g"
        case .calories: "kcal"
        }
    }

    var color: Color {
        switch self {
        case .protein: Theme.ember
        case .calories: Theme.coral
        case .carbs: Theme.sky
        case .fat: Theme.orchid
        }
    }

    var isMinimumTarget: Bool {
        self == .protein
    }
}

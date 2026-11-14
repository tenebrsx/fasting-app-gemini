import SwiftData
import SwiftUI
import UIKit

struct MacrosView: View {
    @Environment(ToastCenter.self) private var toastCenter

    @Query(sort: \MealEntry.time, order: .forward) private var allMeals: [MealEntry]
    @Query(sort: \UserSettings.updatedAt, order: .reverse) private var settingsList: [UserSettings]

    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var showAddMeal = false
    @State private var editingMeal: MealEntry?

    private var settings: UserSettings? {
        settingsList.first
    }

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var minDay: Date {
        Calendar.current.date(byAdding: .day, value: -119, to: today) ?? today
    }

    private var dayMeals: [MealEntry] {
        let cal = Calendar.current
        return allMeals.filter { cal.isDate($0.time, inSameDayAs: selectedDay) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dayHeader

                macroBars

                HStack {
                    Text("Meals")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button("Add meal") {
                        showAddMeal = true
                    }
                    .buttonStyle(SoftPillButtonStyle())
                }
                .padding(.top, 4)

                mealsList
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showAddMeal) {
            MealSheetView(meal: nil, defaultDay: selectedDay) { savedDay, message in
                selectedDay = Calendar.current.startOfDay(for: savedDay)
                toastCenter.show(message)
            }
        }
        .sheet(item: $editingMeal) { meal in
            MealSheetView(meal: meal, defaultDay: selectedDay) { savedDay, message in
                selectedDay = Calendar.current.startOfDay(for: savedDay)
                toastCenter.show(message)
            }
        }
    }

    private var dayHeader: some View {
        HStack {
            Button {
                if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDay) {
                    selectedDay = prev
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1))
            }
            .disabled(selectedDay <= minDay)
            .opacity(selectedDay <= minDay ? 0.35 : 1)

            Spacer()

            Text(Formatters.dayTitle(selectedDay))
                .font(.title2.bold())
                .foregroundStyle(Theme.ink)

            Spacer()

            Button {
                if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDay) {
                    selectedDay = next
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Theme.surface, in: Circle())
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1))
            }
            .disabled(selectedDay >= today)
            .opacity(selectedDay >= today ? 0.35 : 1)
        }
        .foregroundStyle(Theme.ink)
    }

    private var macroBars: some View {
        VStack(spacing: 10) {
            ForEach(MacroKind.allCases) { macro in
                let total = dayMeals.reduce(0.0) { $0 + $1.value(for: macro) }
                let rounded = Int(total.rounded())
                let target = settings?.target(for: macro)
                let fraction = (target ?? 0) > 0 ? min(1.0, total / (target ?? 1)) : 0
                let isMet = macro.isMinimumTarget && (target ?? 0) > 0 && Double(rounded) >= (target ?? 0)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(macro.title)
                            .font(macro == .protein ? .headline : .subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        HStack(spacing: 2) {
                            Text("\(rounded)")
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.ink)
                            if let target {
                                Text("/ \(Int(target.rounded())) \(macro.unit)")
                                    .foregroundStyle(Theme.mist)
                            } else {
                                Text(macro.unit)
                                    .foregroundStyle(Theme.mist)
                            }
                        }
                        .font(.subheadline.monospacedDigit())
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.surface2)
                            Capsule()
                                .fill(isMet ? Theme.ok : macro.color)
                                .frame(width: max(fraction > 0 ? 6 : 0, geo.size.width * fraction))
                        }
                    }
                    .frame(height: macro == .protein ? 10 : 7)

                    Text(noteText(for: macro, value: rounded, target: target))
                        .font(.caption)
                        .foregroundStyle(isMet ? Theme.ok : Theme.mist)
                }
                .appCard(padding: macro == .protein ? 16 : 12)
            }
        }
    }

    private func noteText(for macro: MacroKind, value: Int, target: Double?) -> String {
        guard let target, target > 0 else { return "No target" }
        let t = Int(target.rounded())
        if macro.isMinimumTarget {
            return value >= t ? "Target met" : "\(t - value) \(macro.unit) to go · at least \(t)"
        }
        return value <= t ? "\(t - value) \(macro.unit) left" : "\(value - t) \(macro.unit) over"
    }

    @ViewBuilder
    private var mealsList: some View {
        if dayMeals.isEmpty {
            Text("Nothing logged \(Calendar.current.isDateInToday(selectedDay) ? "today" : "this day"). Tap Add meal to log one.")
                .font(.subheadline)
                .foregroundStyle(Theme.mist)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .appCard(padding: 20)
        } else {
            VStack(spacing: 10) {
                ForEach(dayMeals) { meal in
                    Button {
                        editingMeal = meal
                    } label: {
                        MealRowView(meal: meal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MealRowView: View {
    let meal: MealEntry

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(meal.mealDescription.isEmpty ? "Meal" : meal.mealDescription)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                metaText
                    .font(.caption)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .appCard(padding: 12)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = meal.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Text(meal.calories.map { "\(Int($0.rounded()))" } ?? "—")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.mist)
                .frame(width: 48, height: 48)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var metaText: Text {
        let time = Formatters.timeOnly(meal.time)
        let protein = "\(Int((meal.proteinG ?? 0).rounded()))g protein"
        let cal = meal.calories.map { "\(Int($0.rounded())) kcal" } ?? "— kcal"
        let carbs = meal.carbsG.map { "C \(Int($0.rounded()))" } ?? "C —"
        let fat = meal.fatG.map { "F \(Int($0.rounded()))" } ?? "F —"
        let photoTag = meal.source == "photo" ? " · from photo" : ""

        return Text("\(time) · ")
            .foregroundStyle(Theme.mist)
        + Text(protein)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.ink)
        + Text(" · \(cal) · \(carbs) · \(fat)\(photoTag)")
            .foregroundStyle(Theme.mist)
    }
}

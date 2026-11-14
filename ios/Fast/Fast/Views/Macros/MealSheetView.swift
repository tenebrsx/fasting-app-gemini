import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct MealSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let meal: MealEntry?
    let defaultDay: Date
    let onComplete: (Date, String) -> Void

    @State private var descriptionText: String
    @State private var mealTime: Date
    @State private var proteinText: String
    @State private var caloriesText: String
    @State private var carbsText: String
    @State private var fatText: String
    @State private var notesText: String
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?

    @State private var confirmDelete = false
    @State private var errorMessage: String?

    init(meal: MealEntry?, defaultDay: Date, onComplete: @escaping (Date, String) -> Void) {
        self.meal = meal
        self.defaultDay = defaultDay
        self.onComplete = onComplete

        let now = Date()
        let cal = Calendar.current
        let fallbackTime = cal.isDate(defaultDay, inSameDayAs: now)
            ? now
            : (cal.date(byAdding: .hour, value: 12, to: cal.startOfDay(for: defaultDay)) ?? now)

        _descriptionText = State(initialValue: meal?.mealDescription ?? "")
        _mealTime = State(initialValue: meal?.time ?? fallbackTime)
        _proteinText = State(initialValue: Self.numString(meal?.proteinG))
        _caloriesText = State(initialValue: Self.numString(meal?.calories))
        _carbsText = State(initialValue: Self.numString(meal?.carbsG))
        _fatText = State(initialValue: Self.numString(meal?.fatG))
        _notesText = State(initialValue: meal?.notes ?? "")
        _photoData = State(initialValue: meal?.photoData)
    }

    private static func numString(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.rounded() == value ? "\(Int(value))" : "\(value)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("e.g. 3 eggs, avocado, toast", text: $descriptionText)
                        .accessibilityIdentifier("meal-description")
                    DatePicker("Time", selection: $mealTime, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Macros") {
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("0", text: $proteinText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .accessibilityIdentifier("meal-protein")
                    }
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $caloriesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .accessibilityIdentifier("meal-calories")
                    }
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("0", text: $carbsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .accessibilityIdentifier("meal-carbs")
                    }
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("0", text: $fatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .accessibilityIdentifier("meal-fat")
                    }
                }

                Section("Photo") {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        HStack(spacing: 12) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text("Change photo")
                            }

                            Spacer()

                            Button("Remove", role: .destructive) {
                                self.photoData = nil
                                self.selectedPhotoItem = nil
                            }
                        }
                    } else {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Add photo", systemImage: "photo")
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notesText, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.danger)
                            .font(.footnote)
                    }
                }

                if meal != nil {
                    Section {
                        Button(role: .destructive) {
                            if confirmDelete {
                                deleteMeal()
                            } else {
                                confirmDelete = true
                            }
                        } label: {
                            Text(confirmDelete ? "Tap again to delete" : "Delete meal")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(meal == nil ? "Add meal" : "Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(meal == nil ? "Add" : "Save") { saveMeal() }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let raw = try? await newItem.loadTransferable(type: Data.self),
                       let compressed = ImageCompressor.compress(raw) {
                        photoData = compressed
                    } else {
                        errorMessage = "Couldn't read that photo."
                    }
                }
            }
        }
    }

    private func parseOptional(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private func saveMeal() {
        let calories = parseOptional(caloriesText)
        let protein = parseOptional(proteinText)
        let carbs = parseOptional(carbsText)
        let fat = parseOptional(fatText)

        do {
            let cleanDesc = try FastValidator.validateMeal(
                description: descriptionText,
                calories: calories,
                proteinG: protein,
                carbsG: carbs,
                fatG: fat
            )

            if let meal {
                meal.mealDescription = cleanDesc
                meal.time = mealTime
                meal.calories = calories
                meal.proteinG = protein
                meal.carbsG = carbs
                meal.fatG = fat
                meal.notes = notesText
                meal.photoData = photoData
                meal.updatedAt = Date()
            } else {
                let entry = MealEntry(
                    time: mealTime,
                    mealDescription: cleanDesc,
                    calories: calories,
                    proteinG: protein,
                    carbsG: carbs,
                    fatG: fat,
                    source: photoData != nil ? "photo" : "manual",
                    notes: notesText,
                    photoData: photoData
                )
                modelContext.insert(entry)
            }

            try modelContext.save()
            onComplete(mealTime, meal == nil ? "Meal added" : "Meal saved")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteMeal() {
        guard let meal else { return }
        modelContext.delete(meal)
        try? modelContext.save()
        onComplete(defaultDay, "Meal deleted")
        dismiss()
    }
}

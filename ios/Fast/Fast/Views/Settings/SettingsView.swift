import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DataStore.self) private var dataStore
    @Environment(ToastCenter.self) private var toastCenter

    @Query(sort: \UserSettings.updatedAt, order: .reverse) private var settingsList: [UserSettings]

    @State private var caloriesText = ""
    @State private var proteinText = "120"
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var defaultHoursText = "24"
    @State private var didLoadInitial = false

    private var settings: UserSettings {
        settingsList.first ?? dataStore.ensureSettings(in: modelContext)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text("Settings")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Daily targets")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)

                    Text("Leave a field empty to track it without a target.")
                        .font(.caption)
                        .foregroundStyle(Theme.mist)

                    numberField("Calories", placeholder: "No target", text: $caloriesText)
                    numberField("Protein, at least (g)", placeholder: "120", text: $proteinText)
                    numberField("Carbs (g)", placeholder: "No target", text: $carbsText)
                    numberField("Fat (g)", placeholder: "No target", text: $fatText)

                    Divider()
                        .overlay(Theme.line)

                    Text("Fasting")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)

                    numberField("Default fast length (hours)", placeholder: "24", text: $defaultHoursText)

                    Button("Save settings") {
                        saveSettings()
                    }
                    .buttonStyle(PrimaryPillButtonStyle(isLarge: true))
                    .padding(.top, 4)
                }
                .appCard(padding: 16)

                HStack(spacing: 12) {
                    SyncStatusDot(syncState: dataStore.syncState)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud Sync")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(dataStore.syncState.label)
                            .font(.caption)
                            .foregroundStyle(Theme.mist)
                    }
                    Spacer()
                    Button("Refresh") {
                        Task {
                            await dataStore.refreshCloudStatus()
                        }
                    }
                    .buttonStyle(SoftPillButtonStyle())
                }
                .appCard(padding: 16)

                Text("Your fasts, meals, and targets are stored privately in SwiftData and synced across your Apple devices via iCloud.")
                    .font(.footnote)
                    .foregroundStyle(Theme.mist)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear {
            loadIfNeeded()
        }
    }

    private func numberField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.mist)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.radiusSM, style: .continuous))
                .foregroundStyle(Theme.ink)
        }
    }

    private func loadIfNeeded() {
        guard !didLoadInitial else { return }
        didLoadInitial = true
        let s = settings
        caloriesText = formatNum(s.caloriesTarget)
        proteinText = formatNum(s.proteinTarget)
        carbsText = formatNum(s.carbsTarget)
        fatText = formatNum(s.fatTarget)
        defaultHoursText = formatNum(s.defaultFastHours)
    }

    private func formatNum(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.rounded() == value ? "\(Int(value))" : "\(value)"
    }

    private func parseOptional(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private func saveSettings() {
        let defaultHours = parseOptional(defaultHoursText) ?? 24
        do {
            try FastValidator.validateTargetHours(defaultHours)
            let s = settings
            s.caloriesTarget = parseOptional(caloriesText)
            s.proteinTarget = parseOptional(proteinText)
            s.carbsTarget = parseOptional(carbsText)
            s.fatTarget = parseOptional(fatText)
            s.defaultFastHours = defaultHours
            s.updatedAt = Date()
            try modelContext.save()
            toastCenter.show("Settings saved")
        } catch {
            toastCenter.show(error.localizedDescription)
        }
    }
}

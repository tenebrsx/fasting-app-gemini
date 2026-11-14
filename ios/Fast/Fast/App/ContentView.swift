import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case timer
    case macros
    case history
    case settings
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DataStore.self) private var dataStore
    @Environment(ToastCenter.self) private var toastCenter

    @State private var selectedTab: AppTab = .timer

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Timer", systemImage: "timer", value: AppTab.timer) {
                TimerView()
            }

            Tab("Macros", systemImage: "chart.bar.fill", value: AppTab.macros) {
                MacrosView()
            }

            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                HistoryView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(Theme.ember)
        .toastOverlay(toastCenter)
        .onAppear {
            _ = dataStore.ensureSettings(in: modelContext)
        }
    }
}

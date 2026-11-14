import SwiftData
import SwiftUI

@main
struct FastApp: App {
    @State private var dataStore = DataStore()
    @State private var toastCenter = ToastCenter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dataStore)
                .environment(toastCenter)
                .modelContainer(dataStore.container)
                .task {
                    await dataStore.refreshCloudStatus()
                }
        }
    }
}

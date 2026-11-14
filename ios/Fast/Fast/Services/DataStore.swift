import CloudKit
import Foundation
import Observation
import SwiftData

enum CloudSyncState: Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case unavailable(String)

    var label: String {
        switch self {
        case .checking: "Checking iCloud..."
        case .available: "iCloud Sync Active"
        case .noAccount: "Not signed in to iCloud (local only)"
        case .restricted: "iCloud Restricted (local only)"
        case .unavailable(let reason): "iCloud Unavailable: \(reason)"
        }
    }

    var isSynced: Bool {
        self == .available
    }
}

@MainActor
@Observable
final class DataStore {
    let container: ModelContainer
    let isInMemory: Bool
    var syncState: CloudSyncState = .checking

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || CommandLine.arguments.contains("-inMemory")
    }

    init(inMemory: Bool = DataStore.isRunningTests) {
        self.isInMemory = inMemory
        let schema = Schema([
            FastEntry.self,
            MealEntry.self,
            UserSettings.self,
        ])

        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                self.container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create in-memory ModelContainer: \(error)")
            }
            self.syncState = .unavailable("Test store")
            return
        }

        var canUseCloudKit = false
        do {
            try ObjCExceptionCatcher.perform {
                _ = CKContainer.default()
                canUseCloudKit = true
            }
        } catch {
            canUseCloudKit = false
        }

        if canUseCloudKit {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            var createdCloudContainer: ModelContainer?
            try? ObjCExceptionCatcher.perform {
                createdCloudContainer = try? ModelContainer(for: schema, configurations: [cloudConfig])
            }
            if let createdCloudContainer {
                self.container = createdCloudContainer
                return
            }
        }

        // Local-only fallback when unsigned or CloudKit entitlements are unavailable
        let localConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            self.container = try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func ensureSettings(in context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        if let existing = try? context.fetch(descriptor), let first = existing.first {
            // Deduplicate if CloudKit synced multiple settings records from separate devices
            if existing.count > 1 {
                for duplicate in existing.dropFirst() {
                    context.delete(duplicate)
                }
                try? context.save()
            }
            return first
        }

        let created = UserSettings()
        context.insert(created)
        try? context.save()
        return created
    }

    func refreshCloudStatus() async {
        guard !isInMemory, !Self.isRunningTests else {
            syncState = .unavailable("Test store")
            return
        }

        var container: CKContainer?
        do {
            try ObjCExceptionCatcher.perform {
                container = CKContainer.default()
            }
        } catch {
            syncState = .unavailable("iCloud entitlement missing")
            return
        }

        guard let container else {
            syncState = .unavailable("Could not initialize container")
            return
        }

        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                syncState = .available
            case .noAccount:
                syncState = .noAccount
            case .restricted:
                syncState = .restricted
            case .couldNotDetermine:
                syncState = .unavailable("Could not determine")
            case .temporarilyUnavailable:
                syncState = .unavailable("Temporarily unavailable")
            @unknown default:
                syncState = .unavailable("Unknown status")
            }
        } catch {
            syncState = .unavailable(error.localizedDescription)
        }
    }
}

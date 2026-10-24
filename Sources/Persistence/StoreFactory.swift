import Foundation
import OSLog
import SwiftData

/// Which kind of store the app ended up with.
enum StoreMode: Equatable, Sendable {
    /// Mirrored to the user's private CloudKit database.
    case cloudKit
    /// CloudKit setup failed; same data model, local only. `reason` is the logged error.
    case localFallback(reason: String)
    /// Nothing persisted. Tests, previews, screenshots.
    case inMemory

    var isSyncing: Bool { self == .cloudKit }
}

struct StoreBootstrap {
    let container: ModelContainer
    let mode: StoreMode
}

enum StoreFactory {
    /// PLACEHOLDER: must match `com.apple.developer.icloud-container-identifiers` in project.yml.
    static let defaultCloudKitContainerID = "iCloud.com.example.localfirststarter"

    static let schema = Schema([Checklist.self, ChecklistItem.self])

    private static let logger = Logger(subsystem: "com.example.localfirststarter", category: "storage")

    /// Tries CloudKit first, falls back to a local-only store (logging why), never returns a store
    /// that could silently sync. Throws only if even the local store cannot be created.
    /// The builders are injectable so the fallback path is unit-testable without iCloud.
    static func makeLive(
        cloudKitEnabled: Bool = true,
        cloudKitContainerID: String = defaultCloudKitContainerID,
        buildCloudKit: (String) throws -> ModelContainer = cloudKitContainer,
        buildLocal: () throws -> ModelContainer = localContainer,
        log: (String) -> Void = { logger.error("\($0, privacy: .public)") }
    ) throws -> StoreBootstrap {
        // A missing iCloud entitlement (e.g. an unsigned simulator build) does NOT throw: CoreData traps
        // asynchronously inside its CloudKit setup and the process dies. So the caller must be able to opt
        // out up front (launch flag `--local-only`); `catch` below only covers errors that are thrown.
        guard cloudKitEnabled else {
            let reason = "CloudKit disabled by caller"
            log("Using local-only store: \(reason)")
            return StoreBootstrap(container: try buildLocal(), mode: .localFallback(reason: reason))
        }
        do {
            return StoreBootstrap(container: try buildCloudKit(cloudKitContainerID), mode: .cloudKit)
        } catch {
            let reason = String(describing: error)
            log("iCloud store unavailable, using local only: \(reason)")
            return StoreBootstrap(container: try buildLocal(), mode: .localFallback(reason: reason))
        }
    }

    /// In-memory and explicitly NOT CloudKit, so sample/test data can never reach a user's iCloud.
    static func makeInMemory() throws -> StoreBootstrap {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return StoreBootstrap(container: try ModelContainer(for: schema, configurations: [config]), mode: .inMemory)
    }

    static func cloudKitContainer(id: String) throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .private(id))
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func localContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

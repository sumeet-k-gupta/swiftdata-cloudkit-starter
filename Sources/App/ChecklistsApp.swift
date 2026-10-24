import SwiftData
import SwiftUI

@main
struct ChecklistsApp: App {
    private let container: ModelContainer
    private let mode: StoreMode
    @State private var refresher: SyncRefresher

    init() {
        let bootstrap: StoreBootstrap
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--sample-data") {
            // In-memory (cloudKitDatabase .none): sample data never reaches anyone's iCloud.
            bootstrap = Self.sampleBootstrap()
        } else {
            bootstrap = Self.liveBootstrap()
        }
        #else
        bootstrap = Self.liveBootstrap()
        #endif
        let refresher = SyncRefresher(context: bootstrap.container.mainContext)
        refresher.start()
        refresher.refresh() // once at launch, before any view appears
        self.container = bootstrap.container
        self.mode = bootstrap.mode
        _refresher = State(initialValue: refresher)
    }

    private static func liveBootstrap() -> StoreBootstrap {
        // Unsigned builds (no iCloud entitlement) would crash inside CoreData's CloudKit setup, and unit
        // tests hosted in the app don't need sync: both run local-only. Pass `--local-only` to opt out by hand.
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments
        let enabled = !args.contains("--local-only") && env["XCTestConfigurationFilePath"] == nil
        do { return try StoreFactory.makeLive(cloudKitEnabled: enabled) }
        catch { fatalError("Could not create any SwiftData store: \(error)") }
    }

    #if DEBUG
    private static func sampleBootstrap() -> StoreBootstrap {
        do {
            let bootstrap = try StoreFactory.makeInMemory()
            SampleData.insert(into: bootstrap.container.mainContext)
            return bootstrap
        } catch { fatalError("Could not create in-memory store: \(error)") }
    }
    #endif

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ChecklistListView(mode: mode)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresher.refresh() }
        }
    }
}

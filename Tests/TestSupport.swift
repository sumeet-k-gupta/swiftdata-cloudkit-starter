import Foundation
import SwiftData
@testable import Checklists

/// A ModelContext does not keep its ModelContainer alive; if the container is released the next
/// `insert` traps. Tests discard the container, so keep every one alive for the test process.
@MainActor private var retainedContainers: [ModelContainer] = []

@MainActor
func makeContext() throws -> (ModelContainer, ModelContext) {
    let bootstrap = try StoreFactory.makeInMemory()
    retainedContainers.append(bootstrap.container)
    return (bootstrap.container, bootstrap.container.mainContext)
}

func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_700_000_000 + seconds) }

func uuid(_ n: Int) -> UUID {
    UUID(uuidString: "00000000-0000-0000-0000-" + String(format: "%012d", n))!
}

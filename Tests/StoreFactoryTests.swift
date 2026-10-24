import Foundation
import SwiftData
import Testing
@testable import Checklists

@MainActor
struct StoreFactoryTests {
    struct Boom: Error, CustomStringConvertible { var description: String { "no iCloud account" } }

    @Test func usesCloudKitWhenBuilderSucceeds() throws {
        var requestedID: String?
        let result = try StoreFactory.makeLive(
            cloudKitContainerID: "iCloud.test.id",
            buildCloudKit: { id in requestedID = id; return try StoreFactory.makeInMemory().container },
            buildLocal: { Issue.record("local must not be built"); throw Boom() },
            log: { _ in Issue.record("nothing should be logged") })
        #expect(result.mode == .cloudKit)
        #expect(requestedID == "iCloud.test.id")
    }

    @Test func fallsBackToLocalWithLoggedReasonWhenCloudKitFails() throws {
        var logged: [String] = []
        var localBuilt = false
        let result = try StoreFactory.makeLive(
            buildCloudKit: { _ in throw Boom() },
            buildLocal: { localBuilt = true; return try StoreFactory.makeInMemory().container },
            log: { logged.append($0) })
        #expect(localBuilt)
        #expect(result.mode == .localFallback(reason: "no iCloud account"))
        #expect(logged.count == 1)
        #expect(logged[0].contains("no iCloud account"))
    }

    @Test func disabledCloudKitSkipsTheCloudKitBuilderEntirely() throws {
        let result = try StoreFactory.makeLive(
            cloudKitEnabled: false,
            buildCloudKit: { _ in Issue.record("must not touch CloudKit"); throw Boom() },
            buildLocal: { try StoreFactory.makeInMemory().container },
            log: { _ in })
        #expect(result.mode == .localFallback(reason: "CloudKit disabled by caller"))
    }

    @Test func throwsOnlyIfLocalStoreAlsoFails() {
        #expect(throws: Boom.self) {
            try StoreFactory.makeLive(buildCloudKit: { _ in throw Boom() }, buildLocal: { throw Boom() }, log: { _ in })
        }
    }

    @Test func inMemoryModeIsReported() throws {
        #expect(try StoreFactory.makeInMemory().mode == .inMemory)
        #expect(StoreMode.cloudKit.isSyncing)
        #expect(!StoreMode.inMemory.isSyncing)
    }
}

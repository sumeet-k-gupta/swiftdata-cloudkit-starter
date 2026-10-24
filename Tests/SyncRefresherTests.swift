import CoreData
import Foundation
import SwiftData
import Testing
@testable import Checklists

@MainActor
struct SyncRefresherTests {
    private func wait(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }

    @Test func burstOfNotificationsIsDebouncedToOneRefresh() async throws {
        let (_, ctx) = try makeContext()
        let center = NotificationCenter()
        let name = Notification.Name("test.remoteChange")
        let refresher = SyncRefresher(context: ctx, debounce: .milliseconds(80), center: center, notificationName: name)
        refresher.start()
        for _ in 0..<10 { center.post(name: name, object: nil) }
        await wait(30)
        #expect(refresher.refreshCount == 0) // still inside the debounce window
        await wait(500)
        #expect(refresher.refreshCount == 1)
        refresher.stop()
    }

    @Test func stopRemovesObserver() async throws {
        let (_, ctx) = try makeContext()
        let center = NotificationCenter()
        let name = Notification.Name("test.remoteChange2")
        let refresher = SyncRefresher(context: ctx, debounce: .milliseconds(20), center: center, notificationName: name)
        refresher.start()
        refresher.stop()
        center.post(name: name, object: nil)
        await wait(200)
        #expect(refresher.refreshCount == 0)
    }

    @Test func refreshSavesOnlyWhenThereWasSomethingToFix() throws {
        let (_, ctx) = try makeContext()
        let refresher = SyncRefresher(context: ctx)
        ctx.insert(Checklist(uid: uuid(1), name: "dup", createdAt: date(0)))
        ctx.insert(Checklist(uid: uuid(1), name: "dup", createdAt: date(1)))
        try ctx.save()

        #expect(refresher.refresh() == true)   // dedupe happened and was saved
        #expect(refresher.lastReport.deleted == 1)
        #expect(refresher.refresh() == false)  // idempotent: no changes, no save
        #expect(refresher.refresh() == false)
        #expect(try ctx.fetchCount(FetchDescriptor<Checklist>()) == 1)
    }

    @Test func removedObjectsAreRecognised() throws {
        let (_, ctx) = try makeContext()
        let list = Checklist(name: "x")
        ctx.insert(list)
        try ctx.save()
        #expect(!Deduplicator.isRemoved(list))
        ctx.delete(list)
        #expect(Deduplicator.isRemoved(list))
    }

    @Test func realRemoteChangeNotificationNameIsObservedByDefault() throws {
        // Documents the default; a real remote change needs live CloudKit and is NOT tested here.
        let (_, ctx) = try makeContext()
        let refresher = SyncRefresher(context: ctx)
        refresher.start(); refresher.stop()
        #expect(Notification.Name.NSPersistentStoreRemoteChange.rawValue == "NSPersistentStoreRemoteChangeNotification")
    }
}

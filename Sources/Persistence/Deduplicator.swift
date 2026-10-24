import Foundation
import SwiftData

/// CloudKit cannot enforce uniqueness, so two devices can create "the same" record and both survive sync.
/// This merges them deterministically so every device converges on the same survivor.
enum Deduplicator {
    struct Report: Equatable, Sendable {
        var groupsMerged = 0
        var deleted = 0
        var reparented = 0
        var isEmpty: Bool { groupsMerged == 0 && deleted == 0 && reparented == 0 }
        static func + (l: Report, r: Report) -> Report {
            Report(groupsMerged: l.groupsMerged + r.groupsMerged,
                   deleted: l.deleted + r.deleted,
                   reparented: l.reparented + r.reparented)
        }
    }

    /// True if the object was deleted (or detached) and must not be touched.
    static func isRemoved(_ model: some PersistentModel) -> Bool {
        model.isDeleted || model.modelContext == nil
    }

    /// Groups `objects` by `key`. In each group the keeper is the earliest `createdAt`, ties broken by
    /// smallest `uid` (string order). Input order does not matter. `absorb(keeper, duplicate)` moves
    /// children onto the keeper and returns how many it moved; the duplicate is then deleted.
    /// Does not save: the caller decides (see `SyncRefresher`). Running it again finds nothing to do.
    /// Limitation: objects identical in key, createdAt AND uid are interchangeable; either may win.
    @discardableResult
    static func merge<T: PersistentModel, K: Hashable>(
        _ objects: [T],
        key: (T) -> K,
        createdAt: (T) -> Date,
        uid: (T) -> UUID,
        absorb: (_ keeper: T, _ duplicate: T) -> Int = { _, _ in 0 },
        in context: ModelContext
    ) -> Report {
        let ordered = objects.filter { !isRemoved($0) }.sorted { a, b in
            let (ca, cb) = (createdAt(a), createdAt(b))
            if ca != cb { return ca < cb }
            return uid(a).uuidString < uid(b).uuidString
        }
        var groups: [K: [T]] = [:]
        for object in ordered { groups[key(object), default: []].append(object) }

        var report = Report()
        for (_, group) in groups where group.count > 1 {
            let keeper = group[0]
            for duplicate in group.dropFirst() {
                report.reparented += absorb(keeper, duplicate)
                context.delete(duplicate)
                report.deleted += 1
            }
            report.groupsMerged += 1
        }
        return report
    }

    /// App-level pass: checklists sharing a `uid` are merged (items move to the keeper), then items
    /// sharing a `uid` are merged. Call `context.save()` afterwards if `hasChanges`.
    @discardableResult
    static func run(in context: ModelContext) throws -> Report {
        let lists = try context.fetch(FetchDescriptor<Checklist>())
        let listReport = merge(
            lists, key: { $0.uid }, createdAt: { $0.createdAt }, uid: { $0.uid },
            absorb: { moveItems(from: $0, duplicate: $1) }, in: context)

        let items = try context.fetch(FetchDescriptor<ChecklistItem>())
        let itemReport = merge(
            items.filter { !isRemoved($0) }, key: { $0.uid }, createdAt: { $0.createdAt }, uid: { $0.uid },
            in: context)
        return listReport + itemReport
    }

    /// Re-parents the duplicate's items onto the keeper (must happen before the duplicate is deleted,
    /// otherwise the cascade rule would delete them too).
    static func moveItems(from keeper: Checklist, duplicate: Checklist) -> Int {
        let moving = duplicate.items ?? []
        for item in moving { item.checklist = keeper }
        return moving.count
    }
}

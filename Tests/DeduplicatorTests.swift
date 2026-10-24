import Foundation
import SwiftData
import Testing
@testable import Checklists

@MainActor
struct DeduplicatorTests {
    @Test func noDuplicatesMeansNoChanges() throws {
        let (_, ctx) = try makeContext()
        let a = Checklist(uid: uuid(1), name: "A", createdAt: date(0))
        let b = Checklist(uid: uuid(2), name: "B", createdAt: date(1))
        ctx.insert(a); ctx.insert(b)
        ctx.insert(ChecklistItem(uid: uuid(10), title: "x", checklist: a))
        try ctx.save()

        let report = try Deduplicator.run(in: ctx)
        #expect(report.isEmpty)
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetchCount(FetchDescriptor<Checklist>()) == 2)
        #expect(try ctx.fetchCount(FetchDescriptor<ChecklistItem>()) == 1)
    }

    /// Three checklists share the key "shopping". Keeper = earliest createdAt; the two with the same
    /// createdAt are separated by smallest uid. Result must not depend on array order.
    @Test(arguments: [[0, 1, 2], [2, 1, 0], [1, 2, 0], [1, 0, 2]])
    func mergesDeterministicallyRegardlessOfInputOrder(order: [Int]) throws {
        let (_, ctx) = try makeContext()
        // index: 0 = later date, 1 = earliest date but larger uid, 2 = earliest date and smallest uid
        let specs: [(UUID, Date)] = [(uuid(1), date(50)), (uuid(9), date(0)), (uuid(5), date(0))]
        let lists = specs.map { Checklist(uid: $0.0, name: "shopping", createdAt: $0.1) }
        for l in lists { ctx.insert(l) }
        try ctx.save()

        let ordered = order.map { lists[$0] }
        let report = Deduplicator.merge(
            ordered, key: { $0.name }, createdAt: { $0.createdAt }, uid: { $0.uid },
            absorb: { Deduplicator.moveItems(from: $0, duplicate: $1) }, in: ctx)
        try ctx.save()

        #expect(report.deleted == 2)
        #expect(report.groupsMerged == 1)
        let left = try ctx.fetch(FetchDescriptor<Checklist>())
        #expect(left.count == 1)
        #expect(left.first?.uid == uuid(5))
    }

    @Test func childrenAreReparentedOntoKeeper() throws {
        let (_, ctx) = try makeContext()
        let keeper = Checklist(uid: uuid(1), name: "dup", createdAt: date(0))
        let dup = Checklist(uid: uuid(1), name: "dup", createdAt: date(5))
        ctx.insert(keeper); ctx.insert(dup)
        ctx.insert(ChecklistItem(uid: uuid(10), title: "on keeper", checklist: keeper))
        ctx.insert(ChecklistItem(uid: uuid(11), title: "on dup 1", checklist: dup))
        ctx.insert(ChecklistItem(uid: uuid(12), title: "on dup 2", checklist: dup))
        try ctx.save()

        let report = try Deduplicator.run(in: ctx)
        try ctx.save()

        #expect(report.deleted == 1)
        #expect(report.reparented == 2)
        let lists = try ctx.fetch(FetchDescriptor<Checklist>())
        #expect(lists.count == 1)
        #expect(lists.first?.createdAt == date(0))
        #expect(Set(lists[0].items?.map(\.title) ?? []) == ["on keeper", "on dup 1", "on dup 2"])
        // Items were not lost to the cascade rule.
        #expect(try ctx.fetchCount(FetchDescriptor<ChecklistItem>()) == 3)
    }

    @Test func duplicateItemsWithSameUIDAreMerged() throws {
        let (_, ctx) = try makeContext()
        let list = Checklist(uid: uuid(1), name: "L")
        ctx.insert(list)
        ctx.insert(ChecklistItem(uid: uuid(10), title: "late", createdAt: date(9), checklist: list))
        ctx.insert(ChecklistItem(uid: uuid(10), title: "early", createdAt: date(1), checklist: list))
        try ctx.save()
        try Deduplicator.run(in: ctx)
        try ctx.save()
        let items = try ctx.fetch(FetchDescriptor<ChecklistItem>())
        #expect(items.map(\.title) == ["early"])
    }

    @Test func secondRunIsIdempotent() throws {
        let (_, ctx) = try makeContext()
        let a = Checklist(uid: uuid(1), name: "dup", createdAt: date(0))
        let b = Checklist(uid: uuid(1), name: "dup", createdAt: date(3))
        ctx.insert(a); ctx.insert(b)
        ctx.insert(ChecklistItem(uid: uuid(10), title: "i", checklist: b))
        try ctx.save()

        let first = try Deduplicator.run(in: ctx)
        try ctx.save()
        #expect(!first.isEmpty)

        let second = try Deduplicator.run(in: ctx)
        #expect(second.isEmpty)
        #expect(!ctx.hasChanges)
    }
}

import Foundation
import SwiftData
import Testing
@testable import Checklists

/// Static lint of a SwiftData schema against CloudKit's rules, using only the public `Schema` API:
/// attribute `isUnique`, entity `uniquenessConstraints`, attribute `isOptional` + `defaultValue`,
/// relationship `isOptional` / `inverseName` / `deleteRule`.
/// Observed on Xcode 27.1: `defaultValue` IS populated for Swift property initial values (`var x = 0`)
/// and nil for properties without one. If a future SDK stops populating it, `appSchemaExposesDefaults`
/// will fail loudly instead of the lint silently passing.
/// LIMITS: this checks the model definitions only. It does not check enum raw-type storage, and it
/// does NOT replace initializing and deploying the schema against real CloudKit.
enum CloudKitSchemaLint {
    static func violations(in schema: Schema) -> [String] {
        var out: [String] = []
        for entity in schema.entities {
            if !entity.uniquenessConstraints.isEmpty {
                out.append("\(entity.name): has uniqueness constraints")
            }
            for attr in entity.attributes {
                if !attr.isOptional && attr.defaultValue == nil {
                    out.append("\(entity.name).\(attr.name): non-optional without default")
                }
                if attr.isUnique { out.append("\(entity.name).\(attr.name): unique attribute") }
            }
            for rel in entity.relationships {
                if !rel.isOptional { out.append("\(entity.name).\(rel.name): relationship not optional") }
                if rel.inverseName == nil { out.append("\(entity.name).\(rel.name): no inverse") }
                if rel.deleteRule == .deny { out.append("\(entity.name).\(rel.name): .deny delete rule unsupported") }
            }
        }
        return out
    }
}

@Model final class BadUnique { @Attribute(.unique) var key: String = ""; init() {} }
@Model final class BadRelationship {
    var other: BadUnique2 = BadUnique2()
    init() {}
}
@Model final class BadNoDefault { var title: String; init(title: String) { self.title = title } }
@Model final class BadUnique2 { var x: Int = 0; init() {} }

struct SchemaLintTests {
    @Test func appSchemaPassesCloudKitRules() {
        #expect(CloudKitSchemaLint.violations(in: StoreFactory.schema) == [])
    }

    @Test func schemaContainsExpectedEntities() {
        let names = Set(StoreFactory.schema.entities.map(\.name))
        #expect(names == ["Checklist", "ChecklistItem"])
    }

    @Test func relationshipsAreOptionalWithInverses() throws {
        let checklist = try #require(StoreFactory.schema.entities.first { $0.name == "Checklist" })
        let items = try #require(checklist.relationshipsByName["items"])
        #expect(items.isOptional)
        #expect(items.inverseName == "checklist")
        #expect(items.deleteRule == .cascade)
        let item = try #require(StoreFactory.schema.entities.first { $0.name == "ChecklistItem" })
        let parent = try #require(item.relationshipsByName["checklist"])
        #expect(parent.isOptional)
    }

    @Test func lintActuallyDetectsViolations() {
        let uniqueSchema = Schema([BadUnique.self])
        #expect(!CloudKitSchemaLint.violations(in: uniqueSchema).isEmpty)
        let relSchema = Schema([BadRelationship.self, BadUnique2.self])
        #expect(CloudKitSchemaLint.violations(in: relSchema).contains { $0.contains("not optional") })
    }

    @Test func appSchemaExposesDefaults() {
        let nonOptional = StoreFactory.schema.entities.flatMap { $0.attributes }.filter { !$0.isOptional }
        #expect(nonOptional.count == 8)
        #expect(nonOptional.allSatisfy { $0.defaultValue != nil })
    }

    @Test func lintDetectsMissingDefault() {
        let v = CloudKitSchemaLint.violations(in: Schema([BadNoDefault.self]))
        #expect(v.contains { $0.contains("without default") })
    }
}

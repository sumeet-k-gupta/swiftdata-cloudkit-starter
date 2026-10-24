import Foundation
import SwiftData

/// CloudKit-ready model. Rules (see README "CloudKit gotchas"):
/// every stored property has a default or is optional, no `@Attribute(.unique)`,
/// the to-many relationship is an optional array with an explicit inverse.
@Model
final class Checklist {
    var uid: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.checklist)
    var items: [ChecklistItem]?

    init(uid: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.uid = uid
        self.name = name
        self.createdAt = createdAt
    }

    /// Items in display order (CloudKit gives no ordering guarantee for relationships).
    var sortedItems: [ChecklistItem] {
        (items ?? []).sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return $0.createdAt < $1.createdAt
        }
    }
}

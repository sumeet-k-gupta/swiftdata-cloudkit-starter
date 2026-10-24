import Foundation
import SwiftData

@Model
final class ChecklistItem {
    var uid: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    var checklist: Checklist?

    init(uid: UUID = UUID(), title: String, isDone: Bool = false,
         createdAt: Date = Date(), sortIndex: Int = 0, checklist: Checklist? = nil) {
        self.uid = uid
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.checklist = checklist
    }
}

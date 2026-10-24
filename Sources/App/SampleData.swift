import Foundation
import SwiftData

enum SampleData {
    @MainActor
    static func insert(into context: ModelContext) {
        let packing = Checklist(name: "Weekend trip")
        let groceries = Checklist(name: "Groceries", createdAt: Date().addingTimeInterval(60))
        context.insert(packing)
        context.insert(groceries)
        let packingItems = [("Passport", true), ("Charger", true), ("Sunscreen", false), ("Book", false)]
        for (i, (title, done)) in packingItems.enumerated() {
            context.insert(ChecklistItem(title: title, isDone: done, sortIndex: i, checklist: packing))
        }
        for (i, title) in ["Oat milk", "Coffee", "Lemons"].enumerated() {
            context.insert(ChecklistItem(title: title, sortIndex: i, checklist: groceries))
        }
        try? context.save()
    }
}

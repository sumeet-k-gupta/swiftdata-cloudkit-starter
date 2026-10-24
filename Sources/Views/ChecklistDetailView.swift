import SwiftData
import SwiftUI

struct ChecklistDetailView: View {
    @Bindable var checklist: Checklist
    @Environment(\.modelContext) private var context
    @State private var newTitle = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add an item", text: $newTitle)
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addItem)
                    Button("Add", action: addItem)
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section {
                if checklist.sortedItems.isEmpty {
                    Text("No items yet").foregroundStyle(.secondary)
                }
                ForEach(checklist.sortedItems) { item in
                    Button {
                        item.isDone.toggle()
                        try? context.save()
                    } label: {
                        Label {
                            Text(item.title)
                                .strikethrough(item.isDone)
                                .foregroundStyle(item.isDone ? .secondary : .primary)
                        } icon: {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isDone ? Color.accentColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    let items = checklist.sortedItems
                    for i in offsets { context.delete(items[i]) }
                    try? context.save()
                }
            }
        }
        .navigationTitle(checklist.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addItem() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let next = (checklist.items ?? []).map(\.sortIndex).max().map { $0 + 1 } ?? 0
        context.insert(ChecklistItem(title: title, sortIndex: next, checklist: checklist))
        try? context.save()
        newTitle = ""
    }
}

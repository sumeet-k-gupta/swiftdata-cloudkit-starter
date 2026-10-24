import SwiftData
import SwiftUI

struct ChecklistListView: View {
    let mode: StoreMode
    @Environment(\.modelContext) private var context
    @Query(sort: \Checklist.createdAt) private var lists: [Checklist]
    @State private var showingNew = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty {
                    ContentUnavailableView {
                        Label("No checklists yet", systemImage: "checklist")
                    } description: {
                        Text("Tap + to create your first one.")
                    }
                } else {
                    List {
                        Section {
                            ForEach(lists) { list in
                                NavigationLink(value: list) {
                                    HStack {
                                        Text(list.name)
                                        Spacer()
                                        Text(progress(list)).foregroundStyle(.secondary).monospacedDigit()
                                    }
                                }
                            }
                            .onDelete { offsets in
                                for i in offsets { context.delete(lists[i]) }
                                try? context.save()
                            }
                        } footer: {
                            Text(storageDescription)
                        }
                    }
                }
            }
            .navigationTitle("Checklists")
            .navigationDestination(for: Checklist.self) { ChecklistDetailView(checklist: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Checklist", systemImage: "plus") { newName = ""; showingNew = true }
                }
            }
            .alert("New Checklist", isPresented: $showingNew) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Add") {
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    context.insert(Checklist(name: name))
                    try? context.save()
                }
            }
        }
    }

    private func progress(_ list: Checklist) -> String {
        let items = list.items ?? []
        return "\(items.filter(\.isDone).count)/\(items.count)"
    }

    private var storageDescription: String {
        switch mode {
        case .cloudKit: "Syncing with your private iCloud database."
        case .localFallback: "Stored on this device only (iCloud store unavailable)."
        case .inMemory: "Sample data, not saved."
        }
    }
}

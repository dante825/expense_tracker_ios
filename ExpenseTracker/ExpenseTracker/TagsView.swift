import SwiftUI
import CoreData

struct TagsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)])
    private var tags: FetchedResults<Tag>

    @State private var showingAdd = false
    @State private var newTagName = ""

    @State private var tagToRename: Tag?
    @State private var renameText = ""
    @State private var showingRename = false

    @State private var tagToDelete: Tag?
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    if tags.isEmpty {
                        Text("No tags yet.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    ForEach(tags) { tag in
                        NavigationLink {
                            TagExpensesView(tag: tag)
                        } label: {
                            TagRow(tag: tag)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                tagToRename = tag
                                renameText = tag.name ?? ""
                                showingRename = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                tagToDelete = tag
                                showingDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .padding(18)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 8)
            }
            .navigationTitle("Tags")
            .alert("New Tag", isPresented: $showingAdd) {
                TextField("Tag name", text: $newTagName)
                Button("Cancel", role: .cancel) { newTagName = "" }
                Button("Add") { addTag() }
            } message: {
                Text("Enter a name for the new tag.")
            }
            .alert("Rename Tag", isPresented: $showingRename) {
                TextField("Tag name", text: $renameText)
                Button("Cancel", role: .cancel) { tagToRename = nil }
                Button("Save") { saveRename() }
            } message: {
                if let name = tagToRename?.name {
                    Text("Rename \"\(name)\" to:")
                }
            }
            .confirmationDialog(
                deleteConfirmTitle,
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let tag = tagToDelete {
                        viewContext.delete(tag)
                        try? viewContext.save()
                    }
                    tagToDelete = nil
                }
                Button("Cancel", role: .cancel) { tagToDelete = nil }
            }
        }
    }

    private var deleteConfirmTitle: String {
        guard let tag = tagToDelete else { return "Delete Tag?" }
        let count = (tag.expenses as? Set<Expense>)?.count ?? 0
        let tagName = tag.name ?? "this tag"
        if count == 0 {
            return "Delete \"\(tagName)\"?"
        }
        return "Delete \"\(tagName)\"? It is attached to \(count) expense\(count == 1 ? "" : "s")."
    }

    private func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        newTagName = ""
        guard !trimmed.isEmpty else { return }
        let isDuplicate = tags.contains { ($0.name ?? "").caseInsensitiveCompare(trimmed) == .orderedSame }
        guard !isDuplicate else { return }
        let tag = Tag(context: viewContext)
        tag.name = trimmed
        try? viewContext.save()
    }

    private func saveRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        defer { tagToRename = nil }
        guard !trimmed.isEmpty, let tag = tagToRename else { return }
        let isDuplicate = tags.contains { $0 != tag && ($0.name ?? "").caseInsensitiveCompare(trimmed) == .orderedSame }
        guard !isDuplicate else { return }
        tag.name = trimmed
        try? viewContext.save()
    }
}

struct TagRow: View {
    @ObservedObject var tag: Tag

    private var expenses: [Expense] {
        ((tag.expenses as? Set<Expense>) ?? []).sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }

    private var totalSpend: Double {
        expenses.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name ?? "").font(.body)
                Text("\(expenses.count) expense\(expenses.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if totalSpend > 0 {
                Text(totalSpend, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
            }
        }
    }
}

struct TagExpensesView: View {
    @ObservedObject var tag: Tag

    private var sortedExpenses: [Expense] {
        ((tag.expenses as? Set<Expense>) ?? [])
            .sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }

    var body: some View {
        List {
            if sortedExpenses.isEmpty {
                Text("No expenses for this tag.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            ForEach(sortedExpenses) { expense in
                ExpenseRow(expense: expense)
            }
        }
        .navigationTitle(tag.name ?? "")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    TagsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

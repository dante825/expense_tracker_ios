import SwiftUI
import CoreData

struct TagsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)])
    private var tags: FetchedResults<Tag>

    var body: some View {
        NavigationStack {
            List {
                if tags.isEmpty {
                    Text("No tags yet. Add tags when creating or editing an expense.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                ForEach(tags) { tag in
                    NavigationLink {
                        TagExpensesView(tag: tag)
                    } label: {
                        TagRow(tag: tag)
                    }
                }
                .onDelete(perform: deleteTags)
            }
            .navigationTitle("Tags")
        }
    }

    private func deleteTags(offsets: IndexSet) {
        offsets.map { tags[$0] }.forEach(viewContext.delete)
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

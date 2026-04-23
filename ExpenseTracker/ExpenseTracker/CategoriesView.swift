import SwiftUI

struct CategoriesView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)])
    private var categories: FetchedResults<Category>

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { cat in
                    CategoryRow(category: cat)
                }
                .onDelete(perform: deleteCategories)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddCategorySheet(isPresented: $showingAdd)
            }
            .onAppear {
                DataSeeder.seedDefaultCategories(context: viewContext)
            }
        }
    }

    private func deleteCategories(offsets: IndexSet) {
        for index in offsets {
            let cat = categories[index]
            guard (cat.expenses as? Set<Expense>)?.isEmpty != false else { continue }
            viewContext.delete(cat)
        }
        try? viewContext.save()
    }
}

struct CategoryRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var category: Category
    @State private var editingBudget = false
    @State private var budgetText = ""

    private var expenseCount: Int {
        (category.expenses as? Set<Expense>)?.count ?? 0
    }

    private var monthSpent: Double {
        let monthStart = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        return (category.expenses as? Set<Expense>)?
            .filter { !$0.isIncome && ($0.date ?? Date()) >= monthStart }
            .reduce(0) { $0 + $1.amount } ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(category.name ?? "").font(.body)
                Spacer()
                Text("\(expenseCount) expense\(expenseCount == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if category.budgetLimit > 0 {
                let pct = min(1.0, monthSpent / category.budgetLimit)
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: pct)
                        .tint(pct >= 1 ? .red : pct >= 0.8 ? .orange : .blue)
                    HStack {
                        Text("Spent: \(monthSpent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                        Spacer()
                        Text("of \(category.budgetLimit, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if editingBudget {
                HStack {
                    TextField("Budget limit", text: $budgetText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    Button("Set") {
                        category.budgetLimit = Double(budgetText) ?? 0
                        try? viewContext.save()
                        editingBudget = false
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Cancel") { editingBudget = false }
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    budgetText = category.budgetLimit > 0 ? String(category.budgetLimit) : ""
                    editingBudget = true
                } label: {
                    Text(category.budgetLimit > 0 ? "Edit budget" : "Set budget limit")
                        .font(.caption).foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddCategorySheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var budgetLimit = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Category name", text: $name)
                TextField("Budget limit (optional)", text: $budgetLimit)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: addCategory)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addCategory() {
        let cat = Category(context: viewContext)
        cat.name = name.trimmingCharacters(in: .whitespaces)
        if let limit = Double(budgetLimit), limit > 0 {
            cat.budgetLimit = limit
        }
        try? viewContext.save()
        isPresented = false
    }
}

#Preview {
    CategoriesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

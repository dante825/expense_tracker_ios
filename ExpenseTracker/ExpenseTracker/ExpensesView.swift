import SwiftUI

struct ExpensesView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)])
    private var allExpenses: FetchedResults<Expense>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)])
    private var categories: FetchedResults<Category>

    @State private var search = ""
    @State private var selectedCategory: Category? = nil
    @State private var entryType = "all"
    @State private var showingAdd = false

    private var filtered: [Expense] {
        allExpenses.filter { e in
            let matchSearch = search.isEmpty || (e.desc ?? "").localizedCaseInsensitiveContains(search)
            let matchCat = selectedCategory == nil || e.category == selectedCategory
            let matchType = entryType == "all"
                || (entryType == "income" && e.isIncome)
                || (entryType == "expense" && !e.isIncome)
            return matchSearch && matchCat && matchType
        }
    }

    private var filteredIncome: Double { filtered.filter { $0.isIncome }.reduce(0) { $0 + $1.amount } }
    private var filteredSpent: Double { filtered.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            List {
                Picker("Type", selection: $entryType) {
                    Text("All").tag("all")
                    Text("Expenses").tag("expense")
                    Text("Income").tag("income")
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))

                Picker("Category", selection: $selectedCategory) {
                    Text("All Categories").tag(Optional<Category>(nil))
                    ForEach(categories) { cat in
                        Text(cat.name ?? "").tag(Optional(cat))
                    }
                }

                if !filtered.isEmpty {
                    Section {
                        HStack {
                            Label("Income: \(filteredIncome, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))", systemImage: "arrow.down")
                                .foregroundStyle(.green).font(.caption)
                            Spacer()
                            Label("Spent: \(filteredSpent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))", systemImage: "arrow.up")
                                .foregroundStyle(.red).font(.caption)
                        }
                    }
                }

                Section {
                    ForEach(filtered) { expense in
                        NavigationLink {
                            AddEditExpenseView(expense: expense)
                        } label: {
                            ExpenseRow(expense: expense)
                        }
                    }
                    .onDelete(perform: deleteExpenses)
                }
            }
            .searchable(text: $search, prompt: "Search expenses")
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditExpenseView()
            }
        }
    }

    private func deleteExpenses(offsets: IndexSet) {
        offsets.map { filtered[$0] }.forEach(viewContext.delete)
        try? viewContext.save()
    }
}

#Preview {
    ExpensesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

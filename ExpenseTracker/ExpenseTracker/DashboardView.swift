import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)])
    private var expenses: FetchedResults<Expense>

    private var monthStart: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    }

    private var monthExpenses: [Expense] {
        expenses.filter { ($0.date ?? Date()) >= monthStart }
    }

    private var monthIncome: Double {
        monthExpenses.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    private var monthSpent: Double {
        monthExpenses.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    private var monthNet: Double { monthIncome - monthSpent }

    private var categoryTotals: [(name: String, total: Double)] {
        var dict: [String: Double] = [:]
        for e in expenses where !e.isIncome {
            let name = e.category?.name ?? "Other"
            dict[name, default: 0] += e.amount
        }
        return dict.map { (name: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("This Month") {
                    HStack(spacing: 0) {
                        SummaryCard(title: "Income", amount: monthIncome, color: .green)
                        SummaryCard(title: "Spent", amount: monthSpent, color: .red)
                        SummaryCard(title: "Net", amount: monthNet, color: monthNet >= 0 ? .blue : .orange)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }

                if !categoryTotals.isEmpty {
                    Section("Spending by Category") {
                        Chart(categoryTotals, id: \.name) { item in
                            SectorMark(angle: .value("Amount", item.total), innerRadius: .ratio(0.5))
                                .foregroundStyle(by: .value("Category", item.name))
                        }
                        .frame(height: 200)
                        .padding(.vertical, 8)
                    }
                }

                Section("Recent Entries") {
                    let recent = Array(expenses.prefix(20))
                    if recent.isEmpty {
                        Text("No expenses yet. Tap Expenses to add one.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(recent) { expense in
                            ExpenseRow(expense: expense)
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .onAppear {
                DataSeeder.seedDefaultCategories(context: viewContext)
                DataSeeder.generateRecurring(context: viewContext)
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 4)
    }
}

struct ExpenseRow: View {
    @ObservedObject var expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.desc ?? "").font(.body)
                Text(expense.category?.name ?? "").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .foregroundStyle(expense.isIncome ? .green : .primary)
                    .fontWeight(.medium)
                if let date = expense.date {
                    Text(date, style: .date).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

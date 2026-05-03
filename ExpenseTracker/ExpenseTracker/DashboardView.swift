import SwiftUI
import Charts
import CoreData

enum TimePeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case allTime = "All"

    var startDate: Date? {
        let cal = Calendar.current
        switch self {
        case .week:    return cal.date(byAdding: .weekOfYear, value: -1, to: Date())
        case .month:   return cal.date(from: cal.dateComponents([.year, .month], from: Date()))
        case .year:    return cal.date(from: cal.dateComponents([.year], from: Date()))
        case .allTime: return nil
        }
    }
}

struct ChartBar: Identifiable {
    let id = UUID()
    let date: Date
    let spent: Double
    let income: Double
}

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Expense.date, ascending: false)])
    private var expenses: FetchedResults<Expense>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)])
    private var tags: FetchedResults<Tag>

    @State private var selectedPeriod: TimePeriod = .month
    @State private var selectedTag: Tag? = nil

    // MARK: - Filtered subsets

    private var periodExpenses: [Expense] {
        guard let start = selectedPeriod.startDate else { return Array(expenses) }
        return expenses.filter { ($0.date ?? Date()) >= start }
    }

    private var filteredExpenses: [Expense] {
        guard let tag = selectedTag else { return periodExpenses }
        return periodExpenses.filter { (($0.tags as? Set<Tag>) ?? []).contains(tag) }
    }

    // MARK: - Summary numbers

    private var totalIncome: Double { filteredExpenses.filter { $0.isIncome }.reduce(0) { $0 + $1.amount } }
    private var totalSpent: Double  { filteredExpenses.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }
    private var netAmount: Double   { totalIncome - totalSpent }

    private var transactionCount: Int { filteredExpenses.count }

    private var avgPerEntry: Double {
        let spends = filteredExpenses.filter { !$0.isIncome }
        guard !spends.isEmpty else { return 0 }
        return spends.reduce(0) { $0 + $1.amount } / Double(spends.count)
    }

    private var savingsRate: Double? {
        guard totalIncome > 0 else { return nil }
        return (netAmount / totalIncome) * 100
    }

    private var topCategory: String? {
        var dict: [String: Double] = [:]
        for e in filteredExpenses where !e.isIncome {
            dict[e.category?.name ?? "Other", default: 0] += e.amount
        }
        return dict.max { $0.value < $1.value }?.key
    }

    // MARK: - Category totals (pie)

    private var categoryTotals: [(name: String, total: Double)] {
        var dict: [String: Double] = [:]
        for e in filteredExpenses where !e.isIncome {
            dict[e.category?.name ?? "Other", default: 0] += e.amount
        }
        return dict.map { (name: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
    }

    // MARK: - Adaptive bar chart data

    private var chartBars: [ChartBar] {
        let cal = Calendar.current
        let now = Date()
        var intervals: [(start: Date, end: Date)] = []

        switch selectedPeriod {
        case .week:
            // 7 daily bars: 6 days ago → today
            let todayStart = cal.startOfDay(for: now)
            intervals = (0..<7).reversed().compactMap { offset in
                guard let s = cal.date(byAdding: .day, value: -offset, to: todayStart),
                      let e = cal.date(byAdding: .day, value: 1, to: s) else { return nil }
                return (s, e)
            }

        case .month:
            // Daily bars from the 1st of this month up to and including today
            guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
                  let daysInMonth = cal.range(of: .day, in: .month, for: now)?.count else { break }
            let today = cal.startOfDay(for: now)
            intervals = (0..<daysInMonth).compactMap { d in
                guard let s = cal.date(byAdding: .day, value: d, to: monthStart),
                      s <= today,
                      let e = cal.date(byAdding: .day, value: 1, to: s) else { return nil }
                return (s, e)
            }

        case .year:
            // Monthly bars from January up to and including the current month
            guard let yearStart = cal.date(from: cal.dateComponents([.year], from: now)),
                  let currentMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) else { break }
            intervals = (0..<12).compactMap { m in
                guard let s = cal.date(byAdding: .month, value: m, to: yearStart),
                      s <= currentMonth,
                      let e = cal.date(byAdding: .month, value: 1, to: s) else { return nil }
                return (s, e)
            }

        case .allTime:
            // One bar per month from the earliest expense to now
            guard let earliest = expenses.compactMap({ $0.date }).min(),
                  let firstMonth = cal.date(from: cal.dateComponents([.year, .month], from: earliest))
            else { break }
            var cursor = firstMonth
            while cursor <= now {
                if let next = cal.date(byAdding: .month, value: 1, to: cursor) {
                    intervals.append((cursor, next))
                    cursor = next
                } else { break }
            }
        }

        return intervals.map { (start, end) in
            let slice = sliceExpenses(from: start, to: end)
            return ChartBar(
                date:   start,
                spent:  slice.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount },
                income: slice.filter {  $0.isIncome }.reduce(0) { $0 + $1.amount }
            )
        }
    }

    private func sliceExpenses(from start: Date, to end: Date) -> [Expense] {
        expenses.filter { e in
            guard let d = e.date, d >= start, d < end else { return false }
            if let tag = selectedTag { return (e.tags as? Set<Tag>)?.contains(tag) == true }
            return true
        }
    }

    private var chartCalendarUnit: Calendar.Component {
        switch selectedPeriod {
        case .week, .month: return .day
        case .year, .allTime: return .month
        }
    }

    private var chartBarWidth: CGFloat {
        switch selectedPeriod {
        case .week:    return 44
        case .month:   return 36
        case .year:    return 44
        case .allTime: return 52
        }
    }

    private var chartAxisFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .week:    return .dateTime.month(.abbreviated).day()
        case .month:   return .dateTime.day()
        case .year:    return .dateTime.month(.abbreviated)
        case .allTime: return .dateTime.month(.abbreviated).year(.twoDigits)
        }
    }

    private var chartSectionTitle: String {
        switch selectedPeriod {
        case .week:    return "Daily — Last 7 Days"
        case .month:   return "Daily — This Month"
        case .year:    return "Monthly — This Year"
        case .allTime: return "Monthly — All Time"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // ── Filters ──────────────────────────────────────
                Section {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            TagChip(name: "All", isSelected: selectedTag == nil) { selectedTag = nil }
                            ForEach(tags) { tag in
                                TagChip(name: tag.name ?? "", isSelected: selectedTag == tag) {
                                    selectedTag = selectedTag == tag ? nil : tag
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 8, trailing: 12))
                }

                // ── Overview ──────────────────────────────────────
                Section("Overview") {
                    HStack(spacing: 0) {
                        SummaryCard(title: "Income", amount: totalIncome, color: .green)
                        SummaryCard(title: "Spent",  amount: totalSpent,  color: .red)
                        SummaryCard(title: "Net",    amount: netAmount,   color: netAmount >= 0 ? .blue : .orange)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8))

                    HStack(spacing: 0) {
                        StatTile(label: "Transactions", value: "\(transactionCount)")
                        StatTile(
                            label: "Avg / entry",
                            value: avgPerEntry > 0
                                ? avgPerEntry.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
                                : "—"
                        )
                        if let rate = savingsRate {
                            StatTile(
                                label: "Savings rate",
                                value: String(format: "%.0f%%", rate),
                                color: rate >= 0 ? .green : .red
                            )
                        } else {
                            StatTile(label: "Top category", value: topCategory ?? "—")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
                }

                // ── Timeline bar chart ────────────────────────────
                Section(chartSectionTitle) {
                    let hasIncome = chartBars.contains { $0.income > 0 }
                    let chartWidth = max(320, CGFloat(chartBars.count) * chartBarWidth)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            Chart(chartBars) { bar in
                                BarMark(
                                    x: .value("Date", bar.date, unit: chartCalendarUnit),
                                    y: .value("Spent", bar.spent)
                                )
                                .foregroundStyle(.red.opacity(0.75))
                                .cornerRadius(3)

                                if hasIncome {
                                    LineMark(
                                        x: .value("Date", bar.date, unit: chartCalendarUnit),
                                        y: .value("Income", bar.income)
                                    )
                                    .foregroundStyle(.green)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                    .symbol(.circle)
                                    .symbolSize(28)
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: chartCalendarUnit)) { _ in
                                    AxisValueLabel(format: chartAxisFormat)
                                }
                            }
                            .frame(width: chartWidth, height: 200)
                            .padding(.vertical, 8)
                            .id("chart")
                        }
                        .defaultScrollAnchor(.trailing)
                        .onChange(of: selectedPeriod) {
                            withAnimation { proxy.scrollTo("chart", anchor: .trailing) }
                        }
                        .onChange(of: selectedTag) {
                            withAnimation { proxy.scrollTo("chart", anchor: .trailing) }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                }

                // ── Spending by Category (pie) ────────────────────
                if !categoryTotals.isEmpty {
                    Section("By Category") {
                        Chart(categoryTotals, id: \.name) { item in
                            SectorMark(angle: .value("Amount", item.total), innerRadius: .ratio(0.5))
                                .foregroundStyle(by: .value("Category", item.name))
                        }
                        .frame(height: 200)
                        .padding(.vertical, 8)
                    }
                }

                // ── Recent Entries ────────────────────────────────
                Section("Recent Entries") {
                    if filteredExpenses.isEmpty {
                        Text("No expenses for this selection.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(Array(filteredExpenses.prefix(20))) { expense in
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

// MARK: - Supporting views

struct TagChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 3) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
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

    private var sortedTags: [Tag] {
        ((expense.tags as? Set<Tag>) ?? []).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.desc ?? "").font(.body)
                Text(expense.category?.name ?? "").font(.caption).foregroundStyle(.secondary)
                if !sortedTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(sortedTags, id: \.self) { tag in
                            Text(tag.name ?? "")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
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

import SwiftUI
import CoreData

struct RecurringView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \RecurringExpense.nextDate, ascending: true)])
    private var recurrings: FetchedResults<RecurringExpense>

    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    if recurrings.isEmpty {
                        Text("No recurring expenses yet.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    ForEach(recurrings) { r in
                        RecurringRow(recurring: r)
                    }
                    .onDelete(perform: deleteRecurrings)
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
            .navigationTitle("Recurring")
            .sheet(isPresented: $showingAdd) {
                AddRecurringView(isPresented: $showingAdd)
            }
        }
    }

    private func deleteRecurrings(offsets: IndexSet) {
        offsets.map { recurrings[$0] }.forEach(viewContext.delete)
        try? viewContext.save()
    }
}

struct RecurringRow: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var recurring: RecurringExpense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(recurring.desc ?? "")
                    .font(.body)
                    .strikethrough(!recurring.isActive)
                Text("\(recurring.frequency?.capitalized ?? "") · \(recurring.category?.name ?? "")")
                    .font(.caption).foregroundStyle(.secondary)
                if let next = recurring.nextDate {
                    Text("Next: \(next, style: .date)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(recurring.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .fontWeight(.medium)
                Button(recurring.isActive ? "Pause" : "Resume") {
                    recurring.isActive.toggle()
                    try? viewContext.save()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(recurring.isActive ? .orange : .green)
            }
        }
        .padding(.vertical, 2)
        .opacity(recurring.isActive ? 1 : 0.55)
    }
}

struct AddRecurringView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)])
    private var categories: FetchedResults<Category>

    @State private var amount = ""
    @State private var desc = ""
    @State private var frequency = "monthly"
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var selectedCategory: Category? = nil

    let frequencies = ["daily", "weekly", "monthly"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Amount", text: $amount).keyboardType(.decimalPad)
                    TextField("Description", text: $desc)
                    Picker("Frequency", selection: $frequency) {
                        ForEach(frequencies, id: \.self) { Text($0.capitalized) }
                    }
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    Toggle("Has end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select a category").tag(Optional<Category>(nil))
                        ForEach(categories) { cat in
                            Text(cat.name ?? "").tag(Optional(cat))
                        }
                    }
                }
            }
            .navigationTitle("New Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .disabled(Double(amount) == nil || selectedCategory == nil)
                }
            }
        }
    }

    private func save() {
        guard let amountValue = Double(amount), let category = selectedCategory else { return }
        let r = RecurringExpense(context: viewContext)
        r.amount = amountValue
        r.desc = desc
        r.frequency = frequency
        r.nextDate = startDate
        r.endDate = hasEndDate ? endDate : nil
        r.isActive = true
        r.category = category
        try? viewContext.save()
        isPresented = false
    }
}

#Preview {
    RecurringView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

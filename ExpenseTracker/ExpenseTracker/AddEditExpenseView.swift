import SwiftUI
import PhotosUI
import CoreData

struct AddEditExpenseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var expense: Expense? = nil

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)])
    private var categories: FetchedResults<Category>

    @State private var amount = ""
    @State private var desc = ""
    @State private var date = Date()
    @State private var isIncome = false
    @State private var selectedCategory: Category? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var receiptData: Data? = nil
    @State private var showingReceiptPreview = false

    var isEditing: Bool { expense != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Description", text: $desc)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("This is income", isOn: $isIncome)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select a category").tag(Optional<Category>(nil))
                        ForEach(categories) { cat in
                            Text(cat.name ?? "").tag(Optional(cat))
                        }
                    }
                }

                Section("Receipt") {
                    if let data = receiptData, let uiImage = UIImage(data: data) {
                        Button { showingReceiptPreview = true } label: {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 160)
                                .cornerRadius(8)
                        }
                        Button("Remove Receipt", role: .destructive) {
                            receiptData = nil
                            photoItem = nil
                        }
                    } else {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Attach Receipt Photo", systemImage: "camera")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Entry" : "New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(Double(amount) == nil || selectedCategory == nil)
                }
            }
            .onAppear(perform: loadExpense)
            .onChange(of: photoItem) { _, item in
                Task {
                    receiptData = try? await item?.loadTransferable(type: Data.self)
                }
            }
            .sheet(isPresented: $showingReceiptPreview) {
                if let data = receiptData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            }
        }
    }

    private func loadExpense() {
        guard let e = expense else { return }
        amount = String(e.amount)
        desc = e.desc ?? ""
        date = e.date ?? Date()
        isIncome = e.isIncome
        selectedCategory = e.category
        receiptData = e.receiptData
    }

    private func save() {
        guard let amountValue = Double(amount), let category = selectedCategory else { return }
        let entry = expense ?? Expense(context: viewContext)
        entry.amount = amountValue
        entry.desc = desc
        entry.date = date
        entry.isIncome = isIncome
        entry.category = category
        entry.receiptData = receiptData
        if expense == nil { entry.createdAt = Date() }
        try? viewContext.save()
        dismiss()
    }
}

#Preview {
    AddEditExpenseView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

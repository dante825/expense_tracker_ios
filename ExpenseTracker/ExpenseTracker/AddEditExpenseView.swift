import SwiftUI
import PhotosUI
import CoreData

struct AddEditExpenseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var expense: Expense? = nil

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)])
    private var categories: FetchedResults<Category>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)])
    private var allTags: FetchedResults<Tag>

    @State private var amount = ""
    @State private var desc = ""
    @State private var date = Date()
    @State private var isIncome = false
    @State private var selectedCategory: Category? = nil
    @State private var selectedTags: Set<Tag> = []
    @State private var newTagName = ""
    @State private var showingNewTagAlert = false
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var receiptData: Data? = nil
    @State private var showingReceiptPreview = false

    var isEditing: Bool { expense != nil }

    private var unselectedTags: [Tag] {
        allTags.filter { !selectedTags.contains($0) }
    }

    private var sortedSelectedTags: [Tag] {
        selectedTags.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

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

                Section("Tags") {
                    if !sortedSelectedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(sortedSelectedTags, id: \.self) { tag in
                                    HStack(spacing: 4) {
                                        Text(tag.name ?? "").font(.caption)
                                        Button {
                                            selectedTags.remove(tag)
                                        } label: {
                                            Image(systemName: "xmark").font(.caption2)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }

                    Menu {
                        ForEach(unselectedTags) { tag in
                            Button(tag.name ?? "") { selectedTags.insert(tag) }
                        }
                        if !unselectedTags.isEmpty { Divider() }
                        Button { showingNewTagAlert = true } label: {
                            Label("New Tag…", systemImage: "plus")
                        }
                    } label: {
                        Label("Add Tag", systemImage: "tag")
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
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
            .alert("New Tag", isPresented: $showingNewTagAlert) {
                TextField("e.g. japan trip", text: $newTagName)
                Button("Add") { addTag() }
                Button("Cancel", role: .cancel) { newTagName = "" }
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
        selectedTags = (e.tags as? Set<Tag>) ?? []
    }

    private func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let existing = allTags.first(where: { $0.name?.lowercased() == trimmed.lowercased() }) {
            selectedTags.insert(existing)
        } else {
            let tag = Tag(context: viewContext)
            tag.name = trimmed
            selectedTags.insert(tag)
        }
        newTagName = ""
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
        entry.tags = selectedTags as NSSet
        if expense == nil { entry.createdAt = Date() }
        try? viewContext.save()
        dismiss()
    }
}

#Preview {
    AddEditExpenseView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

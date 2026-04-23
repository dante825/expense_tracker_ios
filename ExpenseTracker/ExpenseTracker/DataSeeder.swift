import CoreData

struct DataSeeder {
    static let defaultCategories = [
        "Food & Dining", "Transportation", "Groceries", "Utilities",
        "Entertainment", "Shopping", "Healthcare", "Housing",
        "Education", "Travel", "Other"
    ]

    static func seedDefaultCategories(context: NSManagedObjectContext) {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return }
        for name in defaultCategories {
            let cat = Category(context: context)
            cat.name = name
        }
        try? context.save()
    }

    static func generateRecurring(context: NSManagedObjectContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        let recurrings = (try? context.fetch(request)) ?? []
        var didChange = false
        for r in recurrings {
            guard var next = r.nextDate else { continue }
            while next <= today {
                if let end = r.endDate, next > end {
                    r.isActive = false
                    break
                }
                let expense = Expense(context: context)
                expense.amount = r.amount
                expense.desc = r.desc ?? ""
                expense.date = next
                expense.createdAt = Date()
                expense.isIncome = false
                expense.category = r.category
                didChange = true
                switch r.frequency {
                case "daily":
                    next = Calendar.current.date(byAdding: .day, value: 1, to: next) ?? next
                case "weekly":
                    next = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: next) ?? next
                default:
                    next = Calendar.current.date(byAdding: .month, value: 1, to: next) ?? next
                }
                r.nextDate = next
            }
        }
        if didChange { try? context.save() }
    }
}

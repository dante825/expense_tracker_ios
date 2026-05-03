import XCTest
import CoreData
@testable import ExpenseTracker

private typealias AppCategory = ExpenseTracker.Category

final class ExpenseTrackerTests: XCTestCase {

    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        context = PersistenceController(inMemory: true).container.viewContext
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    // MARK: - Seeding

    func testSeedCreatesExpectedCategoryCount() throws {
        DataSeeder.seedDefaultCategories(context: context)
        let count = try context.count(for: AppCategory.fetchRequest())
        XCTAssertEqual(count, DataSeeder.defaultCategories.count)
    }

    func testSeedIsIdempotent() throws {
        DataSeeder.seedDefaultCategories(context: context)
        DataSeeder.seedDefaultCategories(context: context)
        let count = try context.count(for: AppCategory.fetchRequest())
        XCTAssertEqual(count, DataSeeder.defaultCategories.count)
    }

    // MARK: - Recurring generation

    func testGenerateRecurringCreatesExpenseAndAdvancesNextDate() throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let r = makeRecurring(frequency: "daily", nextDate: today)
        try context.save()

        DataSeeder.generateRecurring(context: context)

        XCTAssertEqual(try context.count(for: Expense.fetchRequest()), 1)
        XCTAssertEqual(r.nextDate, cal.date(byAdding: .day, value: 1, to: today))
    }

    func testGenerateRecurringSkipsInactiveEntries() throws {
        let today = Calendar.current.startOfDay(for: Date())
        makeRecurring(frequency: "daily", nextDate: today, isActive: false)
        try context.save()

        DataSeeder.generateRecurring(context: context)

        XCTAssertEqual(try context.count(for: Expense.fetchRequest()), 0)
    }

    // MARK: - Expense persistence

    func testCreateExpensePersistsAllFields() throws {
        let cat = makeCategory(name: "Food")
        let entry = Expense(context: context)
        entry.amount = 12.50
        entry.desc = "Noodles"
        entry.date = Date()
        entry.isIncome = false
        entry.category = cat
        entry.createdAt = Date()
        try context.save()

        let saved = try XCTUnwrap(context.fetch(Expense.fetchRequest()).first)
        XCTAssertEqual(saved.amount, 12.50)
        XCTAssertEqual(saved.desc, "Noodles")
        XCTAssertEqual(saved.category?.name, "Food")
    }

    // MARK: - Helpers

    @discardableResult
    private func makeRecurring(
        frequency: String,
        nextDate: Date,
        isActive: Bool = true,
        amount: Double = 10
    ) -> RecurringExpense {
        let r = RecurringExpense(context: context)
        r.amount = amount
        r.desc = "Test recurring"
        r.frequency = frequency
        r.isActive = isActive
        r.nextDate = nextDate
        return r
    }

    @discardableResult
    private func makeCategory(name: String) -> AppCategory {
        let cat = AppCategory(context: context)
        cat.name = name
        return cat
    }
}

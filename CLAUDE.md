# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an Xcode project. Open `ExpenseTracker/ExpenseTracker.xcodeproj` in Xcode to build and run.

From the CLI:
```bash
# Build
xcodebuild -project ExpenseTracker/ExpenseTracker.xcodeproj -scheme ExpenseTracker -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run unit tests
xcodebuild -project ExpenseTracker/ExpenseTracker.xcodeproj -scheme ExpenseTrackerTests -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test class
xcodebuild -project ExpenseTracker/ExpenseTracker.xcodeproj -scheme ExpenseTrackerTests -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ExpenseTrackerTests/ExpenseTrackerTests test
```

## Architecture

**Stack:** SwiftUI + CoreData, iOS only, no third-party dependencies.

**No ViewModel layer.** Views hold all logic directly via `@FetchRequest` and `@Environment(\.managedObjectContext)`. Keep new features in this flat style.

**Navigation root:** `ContentView` is a `TabView` with four tabs — Dashboard, Expenses, Categories, Recurring — each backed by its own top-level view file.

**CoreData entities (`ExpenseTracker.xcdatamodeld`):**
- `Category` — name + optional `budgetLimit`. Has cascade-delete to `Expense` and nullify to `RecurringExpense`.
- `Expense` — amount, desc, date, isIncome, createdAt, optional `receiptData` (Binary, external storage). Belongs to one `Category`.
- `RecurringExpense` — amount, desc, frequency (daily/weekly/monthly), nextDate, endDate, isActive. Belongs to one `Category`.

**`PersistenceController`** is a singleton (`shared`) with an in-memory `preview` variant used in all `#Preview` blocks. Always pass `PersistenceController.preview.container.viewContext` to previews.

**`DataSeeder`** handles two jobs called on `DashboardView.onAppear`:
1. `seedDefaultCategories` — seeds 11 default categories if none exist (idempotent).
2. `generateRecurring` — walks all active `RecurringExpense` records and materialises overdue entries as `Expense` objects, advancing `nextDate` forward. This is the only place recurring expenses become real transactions.

**`AddEditExpenseView`** serves both create (no argument) and edit (pass an `Expense`) modes via `var expense: Expense? = nil`. The `isEditing` computed property drives the navigation title.

**Receipt photos** are picked with `PhotosPicker` (PhotosUI), loaded as `Data` asynchronously, and stored in `Expense.receiptData`. CoreData handles external storage automatically for large blobs.

**Currency formatting** uses `Locale.current.currency?.identifier ?? "USD"` throughout — do not hardcode a currency code.

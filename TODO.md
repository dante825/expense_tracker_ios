# Expense Tracker — Deployment To-Do

## Blockers (required before App Store submission)

- [x] **Add app icon** — `kang-01-currency-1024.png` (1024×1024) copied to `ExpenseTracker/ExpenseTracker/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.

- [ ] **Set up App Store distribution signing** — In Xcode → Signing & Capabilities, switch the Release build configuration from `Apple Development` to `Apple Distribution` and attach an App Store provisioning profile.

## Quality (ship without, but recommended)

- [ ] **Unit tests for `DataSeeder`** — Add tests in `ExpenseTrackerTests/ExpenseTrackerTests.swift` covering:
  - `seedDefaultCategories` idempotency: calling twice must not create duplicate categories.
  - `generateRecurring`: overdue recurring expenses must materialise as `Expense` objects and `nextDate` must advance correctly.
  - Use `PersistenceController(inMemory: true)` for an isolated store per test.

- [ ] **Unit tests for `AddEditExpenseView` logic** — Cover the `isEditing` computed property and verify that saving persists the correct fields to CoreData. Use `PersistenceController.preview` for the in-memory store.

## App Store metadata (required for review)

- [ ] **Set up App Store Connect listing** — Required items:
  - App screenshots: 6.5" (iPhone 14 Pro Max) and 5.5" (iPhone 8 Plus) at minimum.
  - App description and keywords.
  - Privacy policy URL — required even though all data is stored on-device via CoreData.

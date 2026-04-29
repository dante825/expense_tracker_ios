# Expense Tracker — Deployment To-Do

## Blockers (required before App Store submission)

- [x] **Add app icon** — `kang-01-currency-1024.png` (1024×1024) copied to `ExpenseTracker/ExpenseTracker/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.

- [x] **Set up signing for personal device** — App Store distribution signing is not needed. For personal use, connect your iPhone via USB, sign into Xcode with your Apple ID (free account is sufficient), and Xcode will auto-create a Personal Team provisioning profile. Re-build from Xcode every 7 days as free profiles expire weekly (a paid $99/yr Apple Developer account extends this to 1 year).

## Tag Improvements

- [ ] **Refine tag creation and removal** — Polish the tag experience:
  - Allow renaming an existing tag from `TagsView` (tap tag name to edit inline).
  - Confirm before deleting a tag that is attached to expenses — show count of affected expenses in the alert.
  - Prevent saving a new tag with a blank or whitespace-only name (already guarded in code, but surface a clear error message to the user).

- [ ] **Tag add/remove from expense list** — Allow tagging without opening the full edit form:
  - Long-press an `ExpenseRow` → context menu with "Add Tag" and "Remove Tag" options.
  - "Add Tag" shows the same `Menu` dropdown used in `AddEditExpenseView`.
  - "Remove Tag" lists only the tags currently on that expense.

- [ ] **Dashboard tagged/untagged toggle** — Replace the fixed "Tagged" / "Untagged" split sections with a single "Recent Entries" section and a segmented control (`All` | `Tagged` | `Untagged`) so the user can switch views without scrolling past both lists.

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

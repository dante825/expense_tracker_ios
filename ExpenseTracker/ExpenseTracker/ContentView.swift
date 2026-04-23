import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.pie.fill") }
            ExpensesView()
                .tabItem { Label("Expenses", systemImage: "list.bullet") }
            CategoriesView()
                .tabItem { Label("Categories", systemImage: "folder.fill") }
            RecurringView()
                .tabItem { Label("Recurring", systemImage: "repeat") }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

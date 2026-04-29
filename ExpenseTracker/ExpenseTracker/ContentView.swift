import SwiftUI
import CoreData

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
            TagsView()
                .tabItem { Label("Tags", systemImage: "tag.fill") }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

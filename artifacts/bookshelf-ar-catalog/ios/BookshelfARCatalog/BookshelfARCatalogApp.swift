import SwiftUI

@main
struct BookshelfARCatalogApp: App {
    @StateObject private var store = LibraryStore()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(router)
                .tint(Brand.primary)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            TabView(selection: $router.selectedTab) {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(0)
                CatalogView()
                    .tabItem { Label("Catalog", systemImage: "books.vertical") }
                    .tag(1)
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .addBook:
                    AddBookView()
                case .assignBook(let id):
                    AssignBookView(bookID: id)
                case .bookDetail(let id):
                    BookDetailView(bookID: id)
                case .shelfSetup(let id):
                    ShelfSetupView(shelfID: id)
                case .locateBook(let id, let placing):
                    LocateBookView(bookID: id, placing: placing)
                }
            }
        }
    }
}

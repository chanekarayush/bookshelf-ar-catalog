import SwiftUI

enum AppRoute: Hashable {
    case addBook
    case assignBook(String)
    case bookDetail(String)
    case shelfSetup(String)
    case locateBook(String, placing: Bool)
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab = 0
    @Published var path = NavigationPath()

    func go(_ route: AppRoute) {
        path.append(route)
    }

    func resetTo(_ route: AppRoute) {
        path = NavigationPath()
        path.append(route)
    }
}

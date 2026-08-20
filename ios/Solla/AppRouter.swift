import SwiftUI

/// The app's navigation routes. New training modes add cases here.
enum Route: Hashable {
    case scaleDegreeGame
}

struct AppRouter: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .scaleDegreeGame:
                        GameView()
                    }
                }
        }
    }
}

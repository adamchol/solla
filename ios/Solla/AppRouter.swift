import SwiftUI

/// The app's navigation routes. New training modes add cases here.
enum Route: Hashable {
    case scaleDegreeSetup
    case scaleDegreeGame(ScaleDegreeOptions)
    case settings
}

struct AppRouter: View {
    @State private var path = NavigationPath()
    @State private var packStore = SoundPackStore()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .scaleDegreeSetup:
                        ScaleDegreeSetupView()
                    case .scaleDegreeGame(let options):
                        GameView(options: options)
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .environment(packStore)
        #if DEBUG
            .task {
                // Test hook: kick off a pack download at launch so automated
                // runs can verify the install flow without driving the UI.
                if let id = ProcessInfo.processInfo.environment["SOLLA_AUTO_DOWNLOAD"],
                    let entry = SoundPackCatalog.entry(forID: id)
                {
                    packStore.download(entry)
                }
                // Test hook: navigate at launch so automated runs can
                // screenshot the new screens without driving the UI.
                switch ProcessInfo.processInfo.environment["SOLLA_AUTO_ROUTE"] {
                case "setup":
                    path.append(Route.scaleDegreeSetup)
                case "game":
                    path.append(Route.scaleDegreeSetup)
                    path.append(
                        Route.scaleDegreeGame(
                            ScaleDegreeOptions(
                                tonic: 3, isMinor: true, randomOctaves: false,
                                enabledDegrees: Array(0...11), roundCount: 5,
                                cadenceBpm: 80, noteBpm: 60, autoPlayResolution: true)))
                default:
                    break
                }
            }
        #endif
    }
}

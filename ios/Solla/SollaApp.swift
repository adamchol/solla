import AVFoundation
import SwiftUI

@main
struct SollaApp: App {
    init() {
        // Music playback: respect the ringer switch being irrelevant,
        // duck nothing, just play.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            AppRouter()
        }
    }
}

import Foundation
import Playback

enum SettingsKeys {
    static let activePackID = "activeSoundPackID"
    static let scaleDegreeOptions = "scaleDegreeOptions"
}

/// The app's default player: the user's selected sample pack when usable,
/// the bundled pack otherwise, synthesized tones as a last resort.
enum DefaultAudioPlayer {
    static func make() -> any AudioPlaying {
        let activeID =
            UserDefaults.standard.string(forKey: SettingsKeys.activePackID)
            ?? SoundPackCatalog.bundledID
        if let directory = SoundPackLocator.directory(forPackID: activeID),
            let player = SampleAudioPlayer(packDirectory: directory)
        {
            return player
        }
        if let directory = SoundPackLocator.bundledDirectory,
            let player = SampleAudioPlayer(packDirectory: directory)
        {
            return player
        }
        return SynthAudioPlayer()
    }
}

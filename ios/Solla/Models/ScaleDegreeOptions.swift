import Foundation
import MusicTheory
import SollaEngine

/// User-facing setup for a Scale Degrees session. Codable for persistence,
/// Hashable so it can ride a navigation Route value.
struct ScaleDegreeOptions: Hashable, Codable {
    /// Tonic pitch-class value 0...11, or nil for a random key each round.
    var tonic: Int?
    var isMinor: Bool
    /// When true, the mystery note lands in a random octave each round.
    var randomOctaves: Bool
    /// Semitones 0...11 the mystery note is drawn from (min 2).
    var enabledDegrees: [Int]
    var roundCount: Int
    var cadenceBpm: Double
    var noteBpm: Double
    var autoPlayResolution: Bool

    static let `default` = ScaleDegreeOptions(
        tonic: nil,
        isMinor: false,
        randomOctaves: false,
        enabledDegrees: Mode.major.intervals,
        roundCount: 20,
        cadenceBpm: 80,
        noteBpm: 60,
        autoPlayResolution: true
    )

    var mode: Mode { isMinor ? .minor : .major }

    func makeConfig() -> BenbassatDegreeExercise.Config {
        .make(
            roundCount: roundCount,
            mode: mode,
            fixedTonic: tonic.map(PitchClass.init),
            randomOctaves: randomOctaves,
            enabledDegrees: enabledDegrees.count >= 2
                ? enabledDegrees.map(ChromaticDegree.init) : nil,
            cadenceBpm: cadenceBpm,
            noteBpm: noteBpm
        )
    }

    static func loadLastUsed() -> ScaleDegreeOptions {
        guard let data = UserDefaults.standard.data(forKey: SettingsKeys.scaleDegreeOptions),
            let options = try? JSONDecoder().decode(ScaleDegreeOptions.self, from: data)
        else { return .default }
        return options
    }

    func saveAsLastUsed() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: SettingsKeys.scaleDegreeOptions)
        }
    }
}

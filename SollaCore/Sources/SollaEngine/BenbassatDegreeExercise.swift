import MusicTheory
import Playback

/// The Benbassat scale-degree game: each round establishes a fresh random key
/// with a cadence, then plays one diatonic note; the user names its degree.
public struct BenbassatDegreeExercise: Exercise {
    public typealias Answer = ScaleDegree

    public struct Config: Sendable {
        public var roundCount: Int
        public var mode: Mode
        public var cadence: Cadence
        /// Sounding time of each non-final cadence chord, seconds.
        public var chordDuration: Double
        /// Silence between cadence chords.
        public var chordGap: Double
        /// The final (resolving) chord rings longer.
        public var finalChordDuration: Double
        /// Breath between the cadence and the mystery note.
        public var gapBeforeTarget: Double
        /// Sounding time of the mystery note.
        public var targetDuration: Double
        /// The round's tonic lands in [tonicMidiBase, tonicMidiBase+12).
        public var tonicMidiBase: Int

        public init(
            roundCount: Int = 20,
            mode: Mode = .major,
            cadence: Cadence = .authentic,
            chordDuration: Double = 0.8,
            chordGap: Double = 0.1,
            finalChordDuration: Double = 1.2,
            gapBeforeTarget: Double = 0.6,
            targetDuration: Double = 1.5,
            tonicMidiBase: Int = 48
        ) {
            self.roundCount = roundCount
            self.mode = mode
            self.cadence = cadence
            self.chordDuration = chordDuration
            self.chordGap = chordGap
            self.finalChordDuration = finalChordDuration
            self.gapBeforeTarget = gapBeforeTarget
            self.targetDuration = targetDuration
            self.tonicMidiBase = tonicMidiBase
        }
    }

    public let config: Config
    private let voicer = ChordVoicer()

    public init(config: Config = Config()) {
        self.config = config
    }

    public var roundCount: Int { config.roundCount }

    public func makeRound<R: RandomNumberGenerator>(
        index: Int, rng: inout R
    ) -> ExerciseRound<ScaleDegree> {
        let key = Key(tonic: PitchClass(Int.random(in: 0..<12, using: &rng)), mode: config.mode)
        let degree = ScaleDegree.allCases.randomElement(using: &rng)!
        let tonicMidi = config.tonicMidiBase + key.tonic.value

        let chords = config.cadence.chords
        let cadenceEvents = chords.enumerated().map { position, chord in
            let isLast = position == chords.count - 1
            return PlaybackEvent(
                pitches: voicer.voice(chord, in: key),
                duration: isLast ? config.finalChordDuration : config.chordDuration,
                gapAfter: isLast ? config.gapBeforeTarget : config.chordGap,
                gain: 0.85
            )
        }

        // One octave above the tonic anchor keeps the note above the cadence's
        // upper voicing register (single-octave range for the MVP).
        let targetPitch = key.pitch(of: degree, tonicMidi: tonicMidi + 12)
        let targetEvent = PlaybackEvent(
            pitches: [targetPitch],
            duration: config.targetDuration,
            gain: 0.9
        )

        return ExerciseRound(
            segments: [
                StimulusSegment(id: .cadence, events: cadenceEvents),
                StimulusSegment(id: .target, events: [targetEvent]),
            ],
            expected: degree,
            options: ScaleDegree.allCases
        )
    }
}

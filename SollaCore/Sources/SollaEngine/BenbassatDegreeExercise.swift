import MusicTheory
import Playback

/// The Benbassat scale-degree game: each round establishes a key with a
/// cadence, then plays one note from the configured degree pool (diatonic by
/// default, optionally chromatic); the user names its degree.
public struct BenbassatDegreeExercise: Exercise {
    public typealias Answer = ChromaticDegree

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
        /// Fixed tonic for every round; nil = random per round.
        public var fixedTonic: PitchClass?
        /// When true, the mystery note (and its resolution walk) lands in a
        /// random octave each round — one below, at, or above the usual
        /// register. The cadence stays anchored.
        public var randomOctaves: Bool
        /// The degrees the mystery note is drawn from (also the answer
        /// options). Nil or empty = the mode's seven diatonic degrees.
        public var enabledDegrees: [ChromaticDegree]?
        /// Sounding time of each non-final resolution-walk note.
        public var resolutionNoteDuration: Double
        /// Silence between resolution-walk notes.
        public var resolutionNoteGap: Double
        /// The arrival tonic rings longer.
        public var resolutionFinalDuration: Double

        public init(
            roundCount: Int = 20,
            mode: Mode = .major,
            cadence: Cadence = .authentic,
            chordDuration: Double = 0.8,
            chordGap: Double = 0.1,
            finalChordDuration: Double = 1.2,
            gapBeforeTarget: Double = 0.6,
            targetDuration: Double = 1.5,
            tonicMidiBase: Int = 48,
            fixedTonic: PitchClass? = nil,
            randomOctaves: Bool = false,
            enabledDegrees: [ChromaticDegree]? = nil,
            resolutionNoteDuration: Double = 0.75,
            resolutionNoteGap: Double = 0.05,
            resolutionFinalDuration: Double = 1.5
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
            self.fixedTonic = fixedTonic
            self.randomOctaves = randomOctaves
            self.enabledDegrees = enabledDegrees
            self.resolutionNoteDuration = resolutionNoteDuration
            self.resolutionNoteGap = resolutionNoteGap
            self.resolutionFinalDuration = resolutionFinalDuration
        }

        /// Maps musician-facing tempi to event durations.
        ///
        /// Cadence: one chord per beat (beat = 60/cadenceBpm); chords sound
        /// for 90% of the beat with a 10% gap, the final chord rings 1.5
        /// beats, and the breath before the target is 0.75 beats. The target
        /// rings one "note beat" (= 60/noteBpm); resolution-walk notes are
        /// half a note beat with a fixed 0.05 s gap, and the arriving tonic
        /// rings a full note beat. The defaults match the original feel.
        public static func make(
            roundCount: Int = 20,
            mode: Mode = .major,
            fixedTonic: PitchClass? = nil,
            randomOctaves: Bool = false,
            enabledDegrees: [ChromaticDegree]? = nil,
            cadenceBpm: Double = 66,
            noteBpm: Double = 40
        ) -> Config {
            let beat = 60.0 / cadenceBpm
            let noteBeat = 60.0 / noteBpm
            return Config(
                roundCount: roundCount,
                mode: mode,
                chordDuration: 0.9 * beat,
                chordGap: 0.1 * beat,
                finalChordDuration: 1.5 * beat,
                gapBeforeTarget: 0.75 * beat,
                targetDuration: noteBeat,
                fixedTonic: fixedTonic,
                randomOctaves: randomOctaves,
                enabledDegrees: enabledDegrees,
                resolutionNoteDuration: 0.5 * noteBeat,
                resolutionNoteGap: 0.05,
                resolutionFinalDuration: noteBeat
            )
        }
    }

    public let config: Config
    private let voicer = ChordVoicer()

    public init(config: Config = Config()) {
        self.config = config
    }

    public var roundCount: Int { config.roundCount }

    /// The degrees a round draws from: the configured pool, sorted and
    /// deduplicated, or the mode's diatonic degrees when unset.
    public var answerPool: [ChromaticDegree] {
        guard let enabled = config.enabledDegrees, !enabled.isEmpty else {
            return ChromaticDegree.diatonic(in: config.mode)
        }
        return Array(Set(enabled)).sorted()
    }

    public func makeRound<R: RandomNumberGenerator>(
        index: Int, rng: inout R
    ) -> ExerciseRound<ChromaticDegree> {
        let tonicPC = config.fixedTonic ?? PitchClass(Int.random(in: 0..<12, using: &rng))
        let key = Key(tonic: tonicPC, mode: config.mode)
        let pool = answerPool
        let degree = pool.randomElement(using: &rng)!
        let tonicMidi = config.tonicMidiBase + key.tonic.value

        let chords = config.cadence.chords
        let cadenceEvents = chords.enumerated().map { position, chord in
            let isLast = position == chords.count - 1
            return PlaybackEvent(
                pitches: cadencePitches(for: chord, in: key),
                duration: isLast ? config.finalChordDuration : config.chordDuration,
                gapAfter: isLast ? config.gapBeforeTarget : config.chordGap,
                gain: 0.85
            )
        }

        // One octave above the tonic anchor keeps the note above the cadence's
        // upper voicing register; with random octaves the note may land an
        // octave below or above that.
        let octaveShift = config.randomOctaves ? Int.random(in: -1...1, using: &rng) * 12 : 0
        let targetAnchor = tonicMidi + 12 + octaveShift
        let targetPitch = Pitch(midi: targetAnchor + degree.semitone)
        let targetEvent = PlaybackEvent(
            pitches: [targetPitch],
            duration: config.targetDuration,
            gain: 0.9
        )

        return ExerciseRound(
            segments: [
                StimulusSegment(id: .cadence, events: cadenceEvents),
                StimulusSegment(id: .target, events: [targetEvent], acceptsEarlyAnswer: true),
                StimulusSegment(
                    id: .resolution,
                    events: resolutionEvents(degree: degree, key: key, anchor: targetAnchor),
                    replayable: false,
                    playsInStimulus: false
                ),
            ],
            expected: degree,
            options: pool,
            key: key
        )
    }

    /// Voices a cadence chord. In minor the dominant gets a raised leading
    /// tone (harmonic minor) so the cadence establishes the key decisively;
    /// the scale degrees the user identifies stay natural minor.
    private func cadencePitches(for chord: DiatonicChord, in key: Key) -> [Pitch] {
        let pitches = voicer.voice(chord, in: key)
        guard key.mode == .minor, chord.root == .five else { return pitches }
        let subtonic = key.pitchClass(of: .seven)
        return pitches.map { pitch in
            pitch.pitchClass == subtonic ? Pitch(midi: pitch.midi + 1) : pitch
        }
    }

    /// The walk from the correct target note to the nearest tonic: the note
    /// itself, then diatonic steps in the resolving direction. The tonic is
    /// the note alone; lower degrees (≤ Fa) step down to the tonic below,
    /// upper degrees (Fi and up) step up to the tonic above. `anchor` is the
    /// tonic of the register the target note sounded in.
    private func resolutionEvents(degree: ChromaticDegree, key: Key, anchor: Int)
        -> [PlaybackEvent]
    {
        let semitone = degree.semitone
        let intervals = key.mode.intervals
        let offsets: [Int]
        if semitone == 0 {
            offsets = [0]
        } else if semitone <= 5 {
            offsets = [semitone] + intervals.filter { $0 < semitone }.sorted(by: >)
        } else {
            offsets = [semitone] + intervals.filter { $0 > semitone }.sorted() + [12]
        }
        let pitches = offsets.map { Pitch(midi: anchor + $0) }
        return pitches.enumerated().map { index, pitch in
            let isLast = index == pitches.count - 1
            return PlaybackEvent(
                pitches: [pitch],
                duration: isLast ? config.resolutionFinalDuration : config.resolutionNoteDuration,
                gapAfter: isLast ? 0 : config.resolutionNoteGap,
                gain: 0.9
            )
        }
    }
}

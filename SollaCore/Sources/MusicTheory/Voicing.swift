/// Turns abstract chords into concrete pitches.
///
/// Strategy: close-position upper voicing near middle C plus a bass note.
/// Each chord-tone pitch class is folded into the window [60, 72) (C4..B4)
/// and sorted ascending; the root is folded into [41, 53) (F2..E3) as the bass.
/// Deterministic and register-stable across all 12 keys — no voice-leading
/// logic yet (that refinement lives entirely inside this type).
public struct ChordVoicer: Sendable {
    public let upperWindowStart: Int
    public let bassWindowStart: Int

    public init(upperWindowStart: Int = 60, bassWindowStart: Int = 41) {
        self.upperWindowStart = upperWindowStart
        self.bassWindowStart = bassWindowStart
    }

    /// Voice a chord in a key: bass note first, then the close-position triad.
    public func voice(_ chord: DiatonicChord, in key: Key) -> [Pitch] {
        let classes = chord.pitchClasses(in: key)
        let upper =
            classes
            .map { fold($0, intoWindowStartingAt: upperWindowStart) }
            .sorted()
        let bass = fold(classes[0], intoWindowStartingAt: bassWindowStart)
        return [bass] + upper
    }

    /// The lowest pitch of `pitchClass` at or above `start` (always within [start, start+12)).
    private func fold(_ pitchClass: PitchClass, intoWindowStartingAt start: Int) -> Pitch {
        let offset = ((pitchClass.value - start) % 12 + 12) % 12
        return Pitch(midi: start + offset)
    }
}

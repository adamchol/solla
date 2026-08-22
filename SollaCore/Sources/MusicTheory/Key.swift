/// A scale mode.
public enum Mode: Hashable, CaseIterable, Sendable {
    case major
    /// Natural minor; harmonic colouring (the raised leading tone in the
    /// dominant chord) is applied where cadences are built, not here.
    case minor

    /// Semitone offsets of the seven diatonic degrees above the tonic.
    public var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        }
    }

    /// Semitone offset of a degree above the tonic.
    public func interval(of degree: ScaleDegree) -> Int {
        intervals[degree.rawValue - 1]
    }

    /// Human-readable mode name ("Major" / "Minor").
    public var displayName: String {
        switch self {
        case .major: return "Major"
        case .minor: return "Minor"
        }
    }

    /// Conventional tonic spelling for keys of this mode (C♯ minor rather
    /// than D♭ minor, E♭ major rather than D♯ major, ...).
    public func tonicName(_ tonic: PitchClass) -> String {
        switch self {
        case .major:
            return tonic.name
        case .minor:
            return ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "G♯", "A", "B♭", "B"][tonic.value]
        }
    }
}

/// A key: a tonic pitch class plus a mode.
public struct Key: Hashable, Sendable {
    public let tonic: PitchClass
    public let mode: Mode

    public init(tonic: PitchClass, mode: Mode) {
        self.tonic = tonic
        self.mode = mode
    }

    /// The pitch class of a scale degree in this key.
    public func pitchClass(of degree: ScaleDegree) -> PitchClass {
        PitchClass(tonic.value + mode.interval(of: degree))
    }

    /// The concrete pitch of a degree, relative to a tonic placed at `tonicMidi`.
    public func pitch(of degree: ScaleDegree, tonicMidi: Int) -> Pitch {
        Pitch(midi: tonicMidi + mode.interval(of: degree))
    }

    /// Whether a pitch belongs to this key's diatonic scale.
    public func contains(_ pitch: Pitch) -> Bool {
        let offset = PitchClass(pitch.midi - tonic.value).value
        return mode.intervals.contains(offset)
    }

    /// Human-readable key name, e.g. "E♭ Major" or "C♯ Minor".
    public var displayName: String {
        "\(mode.tonicName(tonic)) \(mode.displayName)"
    }
}

/// A scale mode. Major only for now; adding `.minor` (and others) is additive.
public enum Mode: Hashable, CaseIterable, Sendable {
    case major

    /// Semitone offsets of the seven diatonic degrees above the tonic.
    public var intervals: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        }
    }

    /// Semitone offset of a degree above the tonic.
    public func interval(of degree: ScaleDegree) -> Int {
        intervals[degree.rawValue - 1]
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
}

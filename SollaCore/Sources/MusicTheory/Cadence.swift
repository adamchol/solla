/// A diatonic triad built on a scale degree: root, third, fifth stacked within the mode.
public struct DiatonicChord: Hashable, Sendable {
    public let root: ScaleDegree

    public init(root: ScaleDegree) {
        self.root = root
    }

    /// The three chord-tone degrees: root, root+2 steps, root+4 steps.
    public var degrees: [ScaleDegree] {
        [root, root.advanced(by: 2), root.advanced(by: 4)]
    }

    /// Chord-tone pitch classes in a key, root first.
    public func pitchClasses(in key: Key) -> [PitchClass] {
        degrees.map { key.pitchClass(of: $0) }
    }
}

/// An ordered chord progression used to establish tonality.
public struct Cadence: Hashable, Sendable {
    public let chords: [DiatonicChord]

    public init(chords: [DiatonicChord]) {
        self.chords = chords
    }

    /// I–IV–V–I, the classic tonality-establishing progression.
    public static let authentic = Cadence(chords: [
        DiatonicChord(root: .one),
        DiatonicChord(root: .four),
        DiatonicChord(root: .five),
        DiatonicChord(root: .one),
    ])
}

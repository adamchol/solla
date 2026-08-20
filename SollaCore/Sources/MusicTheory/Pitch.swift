#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

/// A pitch class: one of the 12 chroma, independent of octave. C = 0 ... B = 11.
public struct PitchClass: Hashable, Sendable {
    public let value: Int

    public init(_ value: Int) {
        // Normalize any integer (including negatives) into 0...11.
        self.value = ((value % 12) + 12) % 12
    }

    public static let all: [PitchClass] = (0..<12).map(PitchClass.init)
}

/// A concrete pitch identified by its MIDI note number (A4 = 69, C4 = 60).
public struct Pitch: Hashable, Comparable, Sendable {
    public let midi: Int

    public init(midi: Int) {
        self.midi = midi
    }

    public var pitchClass: PitchClass { PitchClass(midi) }

    /// Equal-tempered frequency in Hz, A4 = 440.
    public var frequency: Double {
        440.0 * exp2(Double(midi - 69) / 12.0)
    }

    public static func < (lhs: Pitch, rhs: Pitch) -> Bool {
        lhs.midi < rhs.midi
    }
}

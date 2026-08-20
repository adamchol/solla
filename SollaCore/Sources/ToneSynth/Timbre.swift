/// Relative amplitudes of a tone's harmonics (fundamental first).
/// Normalized at render time so the summed partials never exceed 1.
public struct Timbre: Hashable, Sendable {
    public var harmonics: [Double]

    public init(harmonics: [Double]) {
        self.harmonics = harmonics
    }

    /// A soft electric-piano-ish tone: strong fundamental, fast-falling partials.
    public static let ePiano = Timbre(harmonics: [1.0, 0.5, 0.28, 0.15, 0.08])

    /// Sum of harmonic amplitudes; the normalization divisor.
    public var totalAmplitude: Double {
        harmonics.reduce(0, +)
    }
}

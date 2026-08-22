/// A chromatic scale degree: a semitone offset 0...11 above the tonic.
/// Spans the seven diatonic degrees of a mode plus the five chromatic notes
/// between them, so exercises can quiz any note against a key context.
public struct ChromaticDegree: Hashable, Comparable, Sendable, Codable {
    /// Semitones above the tonic, normalized into 0...11.
    public let semitone: Int

    public init(_ semitone: Int) {
        self.semitone = ((semitone % 12) + 12) % 12
    }

    public static func < (lhs: ChromaticDegree, rhs: ChromaticDegree) -> Bool {
        lhs.semitone < rhs.semitone
    }

    /// Whether this degree belongs to the mode's diatonic scale.
    public func isDiatonic(in mode: Mode) -> Bool {
        mode.intervals.contains(semitone)
    }

    /// Movable-do solfège syllable, chromatic notes spelled with their
    /// conventional raised/lowered syllables (do-based minor).
    public func solfege(in mode: Mode) -> String {
        switch mode {
        case .major:
            return ["Do", "Di", "Re", "Ri", "Mi", "Fa", "Fi", "Sol", "Si", "La", "Li", "Ti"][
                semitone]
        case .minor:
            return ["Do", "Di", "Re", "Me", "Mi", "Fa", "Fi", "Sol", "Le", "La", "Te", "Ti"][
                semitone]
        }
    }

    /// All twelve degrees in ascending order.
    public static let all: [ChromaticDegree] = (0..<12).map(ChromaticDegree.init)

    /// The seven diatonic degrees of a mode, ascending.
    public static func diatonic(in mode: Mode) -> [ChromaticDegree] {
        mode.intervals.map(ChromaticDegree.init)
    }
}

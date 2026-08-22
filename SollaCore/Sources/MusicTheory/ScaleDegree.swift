/// A diatonic scale degree, 1 (tonic) through 7 (leading tone).
public enum ScaleDegree: Int, CaseIterable, Hashable, Sendable {
    case one = 1
    case two
    case three
    case four
    case five
    case six
    case seven

    /// Movable-do solfège syllable for the degree (major-mode spelling).
    public var solfege: String {
        switch self {
        case .one: return "Do"
        case .two: return "Re"
        case .three: return "Mi"
        case .four: return "Fa"
        case .five: return "Sol"
        case .six: return "La"
        case .seven: return "Ti"
        }
    }

    /// Movable-do solfège syllable in a mode: do-based minor lowers the
    /// third, sixth and seventh to Me, Le and Te.
    public func solfege(in mode: Mode) -> String {
        switch (mode, self) {
        case (.minor, .three): return "Me"
        case (.minor, .six): return "Le"
        case (.minor, .seven): return "Te"
        default: return solfege
        }
    }

    /// Roman numeral for the degree (uppercase; quality context comes from the mode).
    public var romanNumeral: String {
        switch self {
        case .one: return "I"
        case .two: return "II"
        case .three: return "III"
        case .four: return "IV"
        case .five: return "V"
        case .six: return "VI"
        case .seven: return "VII"
        }
    }

    /// The degree `steps` diatonic steps above this one, wrapping within the scale.
    public func advanced(by steps: Int) -> ScaleDegree {
        let zeroBased = (rawValue - 1 + steps) % 7
        return ScaleDegree(rawValue: ((zeroBased + 7) % 7) + 1)!
    }
}

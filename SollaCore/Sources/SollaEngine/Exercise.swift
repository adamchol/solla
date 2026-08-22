import MusicTheory
import Playback

/// A training exercise: a factory of rounds for the generic `SessionEngine`.
///
/// Implementations define what a round sounds like (stimulus segments), what
/// the correct answer is, and which answer options the UI should offer.
/// The Benbassat degree game is the first implementation; future exercises
/// (melody dictation with `Answer == [ScaleDegree]`, chord-type recognition
/// with `Answer == ChordQuality`, ...) plug into the same engine.
public protocol Exercise: Sendable {
    associatedtype Answer: Hashable & Sendable

    /// Number of rounds in a session.
    var roundCount: Int { get }

    /// Build the round at `index` using the session's RNG.
    func makeRound<R: RandomNumberGenerator>(index: Int, rng: inout R) -> ExerciseRound<Answer>
}

/// One round: what to play, what's correct, and what the UI can offer.
public struct ExerciseRound<Answer: Hashable & Sendable>: Sendable {
    /// Stimulus segments, played in order when the round starts.
    public let segments: [StimulusSegment]
    public let expected: Answer
    /// Answer options in the order the UI should present them.
    public let options: [Answer]
    /// The round's key, when the exercise is keyed. Nil for unkeyed exercises.
    public let key: Key?

    public init(segments: [StimulusSegment], expected: Answer, options: [Answer], key: Key? = nil) {
        self.segments = segments
        self.expected = expected
        self.options = options
        self.key = key
    }

    public func segment(_ id: StimulusID) -> StimulusSegment? {
        segments.first { $0.id == id }
    }
}

/// The outcome of one answered round.
public struct RoundRecord<Answer: Hashable & Sendable>: Hashable, Sendable {
    public let expected: Answer
    public let given: Answer
    public var isCorrect: Bool { expected == given }

    public init(expected: Answer, given: Answer) {
        self.expected = expected
        self.given = given
    }
}

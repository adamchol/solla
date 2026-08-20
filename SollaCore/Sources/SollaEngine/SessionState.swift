import Playback

/// Where the engine currently is in the round lifecycle.
public enum SessionPhase<Answer: Hashable & Sendable>: Hashable, Sendable {
    /// Session not started yet.
    case idle
    /// A stimulus segment is sounding; answering is disabled.
    case playing(StimulusID)
    /// Stimulus done; waiting for the user's answer.
    case awaitingAnswer
    /// Answer submitted; showing correctness until `next()`.
    case feedback(RoundRecord<Answer>)
    /// All rounds done.
    case summary
}

/// An immutable snapshot of the session, suitable for driving UI.
public struct SessionState<Answer: Hashable & Sendable>: Sendable {
    public var phase: SessionPhase<Answer>
    /// Zero-based index of the current round.
    public var roundIndex: Int
    public var roundCount: Int
    public var score: Int
    public var records: [RoundRecord<Answer>]
    /// The current round, nil until the session starts.
    public var round: ExerciseRound<Answer>?

    public init(roundCount: Int) {
        self.phase = .idle
        self.roundIndex = 0
        self.roundCount = roundCount
        self.score = 0
        self.records = []
        self.round = nil
    }
}

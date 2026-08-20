import Playback

/// Drives one training session of any `Exercise` through its round lifecycle:
///
///     idle → playing(cadence) → playing(target) → awaitingAnswer
///          → feedback → (next round … ) → summary
///
/// Illegal transitions are no-ops (e.g. `submit` while a stimulus is still
/// playing is ignored). UI observes `state` snapshots via `states`.
@MainActor
public final class SessionEngine<E: Exercise> {
    public typealias State = SessionState<E.Answer>

    public private(set) var state: State {
        didSet { broadcast() }
    }

    private let exercise: E
    private let audio: any AudioPlaying
    private var rng: SplitMix64
    private var continuations: [Int: AsyncStream<State>.Continuation] = [:]
    private var nextStreamID = 0

    public init(exercise: E, audio: any AudioPlaying, seed: UInt64) {
        self.exercise = exercise
        self.audio = audio
        self.rng = SplitMix64(seed: seed)
        self.state = State(roundCount: exercise.roundCount)
    }

    /// A stream of state snapshots. Yields the current state immediately,
    /// then every subsequent change. Each call returns an independent stream.
    public var states: AsyncStream<State> {
        let id = nextStreamID
        nextStreamID += 1
        return AsyncStream { continuation in
            continuation.yield(state)
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.continuations[id] = nil
                }
            }
        }
    }

    /// Start the session: build round 0 and play its stimulus.
    public func start() async {
        guard case .idle = state.phase else { return }
        await beginRound(index: 0)
    }

    /// Submit an answer. Ignored unless the engine is awaiting one.
    public func submit(_ answer: E.Answer) {
        guard case .awaitingAnswer = state.phase, let round = state.round else { return }
        let record = RoundRecord(expected: round.expected, given: answer)
        state.records.append(record)
        if record.isCorrect {
            state.score += 1
        }
        state.phase = .feedback(record)
    }

    /// Advance past feedback: next round, or summary after the last one.
    public func next() async {
        guard case .feedback = state.phase else { return }
        let nextIndex = state.roundIndex + 1
        if nextIndex < state.roundCount {
            await beginRound(index: nextIndex)
        } else {
            state.phase = .summary
        }
    }

    /// Replay one segment of the current round. Allowed while awaiting an
    /// answer or showing feedback; restores the prior phase afterwards.
    public func replay(_ id: StimulusID) async {
        switch state.phase {
        case .awaitingAnswer, .feedback:
            break
        default:
            return
        }
        guard let segment = state.round?.segment(id), segment.replayable else { return }
        let resumePhase = state.phase
        state.phase = .playing(id)
        try? await audio.play(segment.events)
        state.phase = resumePhase
    }

    /// Stop audio and tear down (e.g. when the user leaves mid-session).
    public func cancel() async {
        await audio.stop()
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
    }

    private func beginRound(index: Int) async {
        let round = exercise.makeRound(index: index, rng: &rng)
        state.roundIndex = index
        state.round = round
        for segment in round.segments {
            state.phase = .playing(segment.id)
            try? await audio.play(segment.events)
        }
        state.phase = .awaitingAnswer
    }

    private func broadcast() {
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }
}

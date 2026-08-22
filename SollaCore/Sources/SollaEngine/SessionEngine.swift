import Playback

/// Drives one training session of any `Exercise` through its round lifecycle:
///
///     idle → playing(cadence) → playing(target) → awaitingAnswer
///          → feedback → (next round … ) → summary
///
/// A segment marked `acceptsEarlyAnswer` (the target note) lets `submit`
/// short-circuit to `.feedback` while it is still sounding; the audio keeps
/// ringing. Other illegal transitions are no-ops. UI observes `state`
/// snapshots via `states`.
@MainActor
public final class SessionEngine<E: Exercise> {
    public typealias State = SessionState<E.Answer>

    public private(set) var state: State {
        didSet { broadcast() }
    }

    private let exercise: E
    private let audio: any AudioPlaying
    private let autoPlayResolution: Bool
    private var rng: SplitMix64
    private var continuations: [Int: AsyncStream<State>.Continuation] = [:]
    private var nextStreamID = 0

    public init(exercise: E, audio: any AudioPlaying, seed: UInt64, autoPlayResolution: Bool = false)
    {
        self.exercise = exercise
        self.audio = audio
        self.autoPlayResolution = autoPlayResolution
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

    /// Submit an answer. Accepted while awaiting one, or while a segment that
    /// permits early answers (the target note) is still sounding — the audio
    /// is not interrupted; feedback appears while the note rings.
    public func submit(_ answer: E.Answer) {
        guard let round = state.round else { return }
        switch state.phase {
        case .awaitingAnswer:
            record(answer, round: round)
            if autoPlayResolution {
                Task { await self.playResolution() }
            }
        case .playing(let id) where round.segment(id)?.acceptsEarlyAnswer == true:
            // beginRound's loop resumes when the note finishes and, if
            // enabled, auto-plays the resolution then.
            record(answer, round: round)
        default:
            return
        }
    }

    /// One record per round, even if phases glitch (e.g. a replay in flight).
    private func record(_ answer: E.Answer, round: ExerciseRound<E.Answer>) {
        guard state.records.count == state.roundIndex else { return }
        let record = RoundRecord(expected: round.expected, given: answer)
        state.records.append(record)
        if record.isCorrect {
            state.score += 1
        }
        state.phase = .feedback(record)
    }

    /// Play the resolution walk. Only during feedback; never overlaps itself;
    /// leaves `phase` at `.feedback` so the verdict stays visible.
    public func playResolution() async {
        guard case .feedback = state.phase,
            let segment = state.round?.segment(.resolution),
            !state.isPlayingResolution
        else { return }
        state.isPlayingResolution = true
        try? await audio.play(segment.events)
        state.isPlayingResolution = false
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
        for segment in round.segments where segment.playsInStimulus {
            // records.count > index ⇔ this round was answered early.
            if state.records.count > index { break }
            state.phase = .playing(segment.id)
            try? await audio.play(segment.events)
        }
        if state.records.count > index {
            // Early answer: feedback is already showing and the note has now
            // finished ringing (play returned), so resolve if enabled.
            if autoPlayResolution {
                await playResolution()
            }
        } else {
            state.phase = .awaitingAnswer
        }
    }

    private func broadcast() {
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }
}

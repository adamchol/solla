import MusicTheory
import Observation
import Playback
import SollaEngine

/// Bridges the platform-agnostic `SessionEngine` to SwiftUI: consumes the
/// engine's state stream and republishes snapshots as observable state.
@MainActor
@Observable
final class GameViewModel {
    typealias State = SessionEngine<BenbassatDegreeExercise>.State

    private(set) var state: State
    /// Semitone offset (0 = Do … 12 = high Do) currently sounding in the
    /// resolution walk, nil when no walk is playing.
    private(set) var resolutionHighlight: Int?
    /// The semitone offset of the user's answer this round (there are two Do
    /// buttons, 0 and 12, so the degree alone can't identify the tapped one).
    private(set) var lastTappedOffset: Int?

    private let engine: SessionEngine<BenbassatDegreeExercise>
    private var observationTask: Task<Void, Never>?
    private var highlightTask: Task<Void, Never>?

    init(
        options: ScaleDegreeOptions = .default,
        audio: any AudioPlaying = DefaultAudioPlayer.make()
    ) {
        let engine = SessionEngine(
            exercise: BenbassatDegreeExercise(config: options.makeConfig()),
            audio: audio,
            seed: UInt64.random(in: .min ... .max),
            autoPlayResolution: options.autoPlayResolution
        )
        self.engine = engine
        self.state = engine.state
    }

    var summary: BenbassatSummary {
        BenbassatSummary(records: state.records)
    }

    func start() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self, engine] in
            for await state in engine.states {
                self?.consume(state)
            }
        }
        Task { await engine.start() }
    }

    private func consume(_ newState: State) {
        if newState.roundIndex != state.roundIndex {
            lastTappedOffset = nil
        }
        let wasPlayingResolution = state.isPlayingResolution
        state = newState
        if newState.isPlayingResolution, !wasPlayingResolution {
            startHighlight(events: newState.round?.segment(.resolution)?.events ?? [])
        } else if !isFeedback(newState.phase) || !newState.isPlayingResolution {
            stopHighlight()
        }
    }

    private func isFeedback(_ phase: SessionPhase<ChromaticDegree>) -> Bool {
        if case .feedback = phase { return true }
        return false
    }

    /// Steps `resolutionHighlight` through the walk in time with the audio,
    /// which plays as one continuous stimulus.
    private func startHighlight(events: [PlaybackEvent]) {
        highlightTask?.cancel()
        highlightTask = Task { [weak self] in
            let offsets = ResolutionWalk.offsets(of: events)
            for (event, offset) in zip(events, offsets) {
                guard !Task.isCancelled else { break }
                self?.resolutionHighlight = offset
                try? await Task.sleep(for: .seconds(event.totalDuration))
            }
            self?.resolutionHighlight = nil
        }
    }

    private func stopHighlight() {
        highlightTask?.cancel()
        highlightTask = nil
        resolutionHighlight = nil
    }

    /// Answer with the degree at a semitone offset 0...12; both Do buttons
    /// (offsets 0 and 12) submit the tonic.
    func tapOffset(_ offset: Int) {
        lastTappedOffset = offset
        engine.submit(ChromaticDegree(offset))
    }

    func replayCadence() {
        Task { await engine.replay(.cadence) }
    }

    func replayNote() {
        Task { await engine.replay(.target) }
    }

    func playResolution() {
        Task { await engine.playResolution() }
    }

    func next() {
        Task { await engine.next() }
    }

    func tearDown() {
        observationTask?.cancel()
        observationTask = nil
        stopHighlight()
        Task { await engine.cancel() }
    }
}

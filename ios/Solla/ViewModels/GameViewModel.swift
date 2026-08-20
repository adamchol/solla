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

    private let engine: SessionEngine<BenbassatDegreeExercise>
    private var observationTask: Task<Void, Never>?

    init(audio: any AudioPlaying = SynthAudioPlayer()) {
        let engine = SessionEngine(
            exercise: BenbassatDegreeExercise(),
            audio: audio,
            seed: UInt64.random(in: .min ... .max)
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
                self?.state = state
            }
        }
        Task { await engine.start() }
    }

    func tapDegree(_ degree: ScaleDegree) {
        engine.submit(degree)
    }

    func replayCadence() {
        Task { await engine.replay(.cadence) }
    }

    func replayNote() {
        Task { await engine.replay(.target) }
    }

    func next() {
        Task { await engine.next() }
    }

    func tearDown() {
        observationTask?.cancel()
        observationTask = nil
        Task { await engine.cancel() }
    }
}

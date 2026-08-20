import MusicTheory
import Playback
import XCTest

@testable import SollaEngine

/// Captures every `play` call; can suspend until told to finish so tests can
/// observe mid-playback states.
final class RecordingAudioPlayer: AudioPlaying, @unchecked Sendable {
    private let lock = NSLock()
    private var _played: [[PlaybackEvent]] = []
    private var _stopCount = 0

    var played: [[PlaybackEvent]] {
        lock.lock()
        defer { lock.unlock() }
        return _played
    }

    var stopCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _stopCount
    }

    func play(_ events: [PlaybackEvent]) async throws {
        lock.lock()
        _played.append(events)
        lock.unlock()
        await Task.yield()
    }

    func stop() async {
        lock.lock()
        _stopCount += 1
        lock.unlock()
    }
}

@MainActor
final class SessionEngineTests: XCTestCase {
    private func makeEngine(
        rounds: Int = 20, seed: UInt64 = 42
    ) -> (SessionEngine<BenbassatDegreeExercise>, RecordingAudioPlayer) {
        let audio = RecordingAudioPlayer()
        let exercise = BenbassatDegreeExercise(config: .init(roundCount: rounds))
        let engine = SessionEngine(exercise: exercise, audio: audio, seed: seed)
        return (engine, audio)
    }

    func testInitialState() async {
        let (engine, _) = makeEngine()
        XCTAssertEqual(engine.state.phase, .idle)
        XCTAssertEqual(engine.state.roundCount, 20)
        XCTAssertEqual(engine.state.score, 0)
        XCTAssertNil(engine.state.round)
    }

    func testStartPlaysCadenceThenTargetThenAwaits() async {
        let (engine, audio) = makeEngine()
        await engine.start()

        XCTAssertEqual(engine.state.phase, .awaitingAnswer)
        XCTAssertEqual(engine.state.roundIndex, 0)
        XCTAssertEqual(audio.played.count, 2)

        let cadenceEvents = audio.played[0]
        XCTAssertEqual(cadenceEvents.count, 4)
        for chord in cadenceEvents {
            XCTAssertEqual(chord.pitches.count, 4)
        }
        let targetEvents = audio.played[1]
        XCTAssertEqual(targetEvents.count, 1)
        XCTAssertEqual(targetEvents[0].pitches.count, 1)
    }

    func testStartTwiceIsNoOp() async {
        let (engine, audio) = makeEngine()
        await engine.start()
        let playedAfterFirst = audio.played.count
        await engine.start()
        XCTAssertEqual(audio.played.count, playedAfterFirst)
    }

    func testCorrectSubmitScoresAndShowsFeedback() async {
        let (engine, _) = makeEngine()
        await engine.start()
        let expected = engine.state.round!.expected

        engine.submit(expected)

        XCTAssertEqual(engine.state.score, 1)
        XCTAssertEqual(engine.state.records.count, 1)
        guard case .feedback(let record) = engine.state.phase else {
            return XCTFail("expected feedback, got \(engine.state.phase)")
        }
        XCTAssertTrue(record.isCorrect)
    }

    func testWrongSubmitDoesNotScore() async {
        let (engine, _) = makeEngine()
        await engine.start()
        let expected = engine.state.round!.expected
        let wrong = ScaleDegree.allCases.first { $0 != expected }!

        engine.submit(wrong)

        XCTAssertEqual(engine.state.score, 0)
        guard case .feedback(let record) = engine.state.phase else {
            return XCTFail("expected feedback, got \(engine.state.phase)")
        }
        XCTAssertFalse(record.isCorrect)
        XCTAssertEqual(record.expected, expected)
        XCTAssertEqual(record.given, wrong)
    }

    func testSubmitIgnoredOutsideAwaitingAnswer() async {
        let (engine, _) = makeEngine()
        // idle
        engine.submit(.one)
        XCTAssertEqual(engine.state.phase, .idle)
        XCTAssertTrue(engine.state.records.isEmpty)

        // feedback: a second submit must not double-record
        await engine.start()
        engine.submit(engine.state.round!.expected)
        engine.submit(engine.state.round!.expected)
        XCTAssertEqual(engine.state.records.count, 1)
        XCTAssertEqual(engine.state.score, 1)
    }

    func testNextAdvancesRoundsAndEndsInSummary() async {
        let (engine, _) = makeEngine(rounds: 3)
        await engine.start()
        for round in 0..<3 {
            XCTAssertEqual(engine.state.roundIndex, round)
            XCTAssertEqual(engine.state.phase, .awaitingAnswer)
            engine.submit(engine.state.round!.expected)
            await engine.next()
        }
        XCTAssertEqual(engine.state.phase, .summary)
        XCTAssertEqual(engine.state.score, 3)
        XCTAssertEqual(engine.state.records.count, 3)
    }

    func testNextIgnoredWhileAwaitingAnswer() async {
        let (engine, _) = makeEngine()
        await engine.start()
        await engine.next()
        XCTAssertEqual(engine.state.roundIndex, 0)
        XCTAssertEqual(engine.state.phase, .awaitingAnswer)
    }

    func testReplayReplaysOnlyRequestedSegmentAndRestoresPhase() async {
        let (engine, audio) = makeEngine()
        await engine.start()
        let playedBefore = audio.played.count

        await engine.replay(.cadence)
        XCTAssertEqual(audio.played.count, playedBefore + 1)
        XCTAssertEqual(audio.played.last?.count, 4)
        XCTAssertEqual(engine.state.phase, .awaitingAnswer)

        engine.submit(engine.state.round!.expected)
        let feedbackPhase = engine.state.phase
        await engine.replay(.target)
        XCTAssertEqual(audio.played.last?.count, 1)
        XCTAssertEqual(engine.state.phase, feedbackPhase)
    }

    func testReplayIgnoredWhenIdle() async {
        let (engine, audio) = makeEngine()
        await engine.replay(.cadence)
        XCTAssertTrue(audio.played.isEmpty)
    }

    func testCancelStopsAudio() async {
        let (engine, audio) = makeEngine()
        await engine.start()
        await engine.cancel()
        XCTAssertEqual(audio.stopCount, 1)
    }

    func testStatesStreamYieldsCurrentStateImmediately() async {
        let (engine, _) = makeEngine()
        var iterator = engine.states.makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first?.phase, .idle)
    }

    func testDeterministicWithSameSeed() async {
        let (engineA, audioA) = makeEngine(rounds: 5, seed: 7)
        let (engineB, audioB) = makeEngine(rounds: 5, seed: 7)
        await engineA.start()
        await engineB.start()
        XCTAssertEqual(audioA.played, audioB.played)
        XCTAssertEqual(engineA.state.round?.expected, engineB.state.round?.expected)
    }
}

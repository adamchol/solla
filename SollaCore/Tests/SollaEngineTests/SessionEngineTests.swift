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
    private var _waiters: [CheckedContinuation<Void, Never>] = []

    /// When true, `play` suspends until `finishOne()` is called.
    /// Set before use; not intended to be toggled mid-flight.
    var gated = false

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
        let isGated = gated
        lock.unlock()
        if isGated {
            await withCheckedContinuation { continuation in
                lock.lock()
                _waiters.append(continuation)
                lock.unlock()
            }
        } else {
            await Task.yield()
        }
    }

    /// Complete the oldest in-flight gated `play` call, waiting briefly for
    /// one to arrive if the caller raced ahead of the engine.
    func finishOne() async {
        for _ in 0..<10_000 {
            lock.lock()
            let continuation = _waiters.isEmpty ? nil : _waiters.removeFirst()
            lock.unlock()
            if let continuation {
                continuation.resume()
                return
            }
            await Task.yield()
        }
        XCTFail("no gated play call arrived to finish")
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
        rounds: Int = 20, seed: UInt64 = 42, gated: Bool = false, autoPlayResolution: Bool = false
    ) -> (SessionEngine<BenbassatDegreeExercise>, RecordingAudioPlayer) {
        let audio = RecordingAudioPlayer()
        audio.gated = gated
        let exercise = BenbassatDegreeExercise(config: .init(roundCount: rounds))
        let engine = SessionEngine(
            exercise: exercise, audio: audio, seed: seed, autoPlayResolution: autoPlayResolution
        )
        return (engine, audio)
    }

    /// Cooperatively poll until `condition` holds; everything in these tests
    /// runs on the main actor, so yielding drives all pending work.
    /// Fails the test if the condition never becomes true.
    private func waitUntil(
        file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool
    ) async {
        for _ in 0..<10_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("condition never became true", file: file, line: line)
    }

    private func isPlaying(_ id: StimulusID, _ phase: SessionPhase<ChromaticDegree>) -> Bool {
        if case .playing(id) = phase { return true }
        return false
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
        let wrong = engine.state.round!.options.first { $0 != expected }!

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
        engine.submit(ChromaticDegree(0))
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

    func testSubmitDuringTargetShowsFeedbackAndDoesNotClobber() async {
        let (engine, audio) = makeEngine(gated: true)
        let startTask = Task { await engine.start() }

        await waitUntil { isPlaying(.cadence, engine.state.phase) }
        await audio.finishOne()
        await waitUntil { isPlaying(.target, engine.state.phase) }

        engine.submit(engine.state.round!.expected)

        guard case .feedback = engine.state.phase else {
            return XCTFail("expected feedback, got \(engine.state.phase)")
        }
        XCTAssertEqual(engine.state.records.count, 1)
        XCTAssertEqual(engine.state.score, 1)

        // Let the target finish ringing; feedback must survive beginRound's
        // return, and no resolution plays with auto-play off.
        await audio.finishOne()
        await startTask.value
        guard case .feedback = engine.state.phase else {
            return XCTFail("feedback clobbered, got \(engine.state.phase)")
        }
        XCTAssertEqual(audio.played.count, 2)
    }

    func testSubmitDuringCadenceIgnored() async {
        let (engine, audio) = makeEngine(gated: true)
        let startTask = Task { await engine.start() }

        await waitUntil { isPlaying(.cadence, engine.state.phase) }
        engine.submit(ChromaticDegree(0))
        XCTAssertTrue(engine.state.records.isEmpty)
        XCTAssertTrue(isPlaying(.cadence, engine.state.phase))

        await audio.finishOne()
        await audio.finishOne()
        await startTask.value
        XCTAssertEqual(engine.state.phase, .awaitingAnswer)
        XCTAssertTrue(engine.state.records.isEmpty)
    }

    func testAutoResolutionPlaysAfterNormalSubmit() async {
        let (engine, audio) = makeEngine(autoPlayResolution: true)
        await engine.start()
        let round = engine.state.round!

        engine.submit(round.expected)

        await waitUntil { audio.played.count == 3 && !engine.state.isPlayingResolution }
        XCTAssertEqual(audio.played[2], round.segment(.resolution)!.events)
        guard case .feedback = engine.state.phase else {
            return XCTFail("expected feedback, got \(engine.state.phase)")
        }
    }

    func testAutoResolutionAfterEarlySubmitWaitsForTargetToFinish() async {
        let (engine, audio) = makeEngine(gated: true, autoPlayResolution: true)
        let startTask = Task { await engine.start() }

        await waitUntil { isPlaying(.cadence, engine.state.phase) }
        await audio.finishOne()
        await waitUntil { isPlaying(.target, engine.state.phase) }

        engine.submit(engine.state.round!.expected)

        // The note is still ringing: no resolution yet.
        for _ in 0..<50 { await Task.yield() }
        XCTAssertEqual(audio.played.count, 2)

        await audio.finishOne()  // target done
        await waitUntil { audio.played.count == 3 }
        XCTAssertTrue(engine.state.isPlayingResolution)
        XCTAssertEqual(audio.played[2], engine.state.round!.segment(.resolution)!.events)

        await audio.finishOne()  // resolution done
        await startTask.value
        XCTAssertFalse(engine.state.isPlayingResolution)
        guard case .feedback = engine.state.phase else {
            return XCTFail("expected feedback, got \(engine.state.phase)")
        }
    }

    func testPlayResolutionOnlyDuringFeedbackAndNoDoublePlay() async {
        let (engine, audio) = makeEngine()
        await engine.start()

        // Not in feedback: no-op (would leak the answer).
        await engine.playResolution()
        XCTAssertEqual(audio.played.count, 2)

        engine.submit(engine.state.round!.expected)
        audio.gated = true
        let first = Task { await engine.playResolution() }
        let second = Task { await engine.playResolution() }
        await waitUntil { audio.played.count == 3 }
        await audio.finishOne()
        await first.value
        await second.value
        // The overlapping call was a no-op.
        XCTAssertEqual(audio.played.count, 3)
        XCTAssertFalse(engine.state.isPlayingResolution)
    }

    func testReplayIgnoresResolutionSegment() async {
        let (engine, audio) = makeEngine()
        await engine.start()

        await engine.replay(.resolution)
        XCTAssertEqual(audio.played.count, 2)

        engine.submit(engine.state.round!.expected)
        await engine.replay(.resolution)
        XCTAssertEqual(audio.played.count, 2)
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

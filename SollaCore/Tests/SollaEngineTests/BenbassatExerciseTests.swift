import MusicTheory
import Playback
import XCTest

@testable import SollaEngine

final class BenbassatExerciseTests: XCTestCase {
    func testRoundShape() {
        var rng = SplitMix64(seed: 1)
        let round = BenbassatDegreeExercise().makeRound(index: 0, rng: &rng)

        XCTAssertEqual(round.segments.map(\.id), [.cadence, .target])
        XCTAssertEqual(round.options, ScaleDegree.allCases)
        XCTAssertEqual(round.segment(.cadence)?.events.count, 4)
        XCTAssertEqual(round.segment(.target)?.events.count, 1)
        XCTAssertTrue(round.segments.allSatisfy(\.replayable))
    }

    func testCadenceStartsAndEndsOnTonicChordBass() {
        var rng = SplitMix64(seed: 2)
        for index in 0..<50 {
            let round = BenbassatDegreeExercise().makeRound(index: index, rng: &rng)
            let cadence = round.segment(.cadence)!.events
            // I ... I: first and last chords share their bass pitch class (the tonic).
            XCTAssertEqual(cadence.first?.pitches[0].pitchClass, cadence.last?.pitches[0].pitchClass)
        }
    }

    func testTargetIsDiatonicDegreeOfRoundKey() {
        var rng = SplitMix64(seed: 3)
        let exercise = BenbassatDegreeExercise()
        for index in 0..<100 {
            let round = exercise.makeRound(index: index, rng: &rng)
            let cadence = round.segment(.cadence)!.events
            let target = round.segment(.target)!.events[0].pitches[0]

            // Reconstruct the key from the cadence's opening tonic bass.
            let key = Key(tonic: cadence[0].pitches[0].pitchClass, mode: .major)
            XCTAssertTrue(key.contains(target), "target \(target.midi) not diatonic")
            XCTAssertEqual(key.pitchClass(of: round.expected), target.pitchClass)
        }
    }

    func testTargetSitsAboveCadenceRegister() {
        var rng = SplitMix64(seed: 4)
        let exercise = BenbassatDegreeExercise()
        for index in 0..<100 {
            let round = exercise.makeRound(index: index, rng: &rng)
            let target = round.segment(.target)!.events[0].pitches[0]
            XCTAssertTrue((60...83).contains(target.midi), "target \(target.midi) out of range")
        }
    }

    func testAllDegreesAndKeysEventuallyAppear() {
        var rng = SplitMix64(seed: 5)
        let exercise = BenbassatDegreeExercise()
        var degrees = Set<ScaleDegree>()
        var tonics = Set<PitchClass>()
        for index in 0..<500 {
            let round = exercise.makeRound(index: index, rng: &rng)
            degrees.insert(round.expected)
            tonics.insert(round.segment(.cadence)!.events[0].pitches[0].pitchClass)
        }
        XCTAssertEqual(degrees.count, 7)
        XCTAssertEqual(tonics.count, 12)
    }
}

final class BenbassatSummaryTests: XCTestCase {
    func testSummaryMath() {
        let records: [RoundRecord<ScaleDegree>] = [
            RoundRecord(expected: .one, given: .one),
            RoundRecord(expected: .one, given: .five),
            RoundRecord(expected: .three, given: .three),
            RoundRecord(expected: .five, given: .five),
        ]
        let summary = BenbassatSummary(records: records)

        XCTAssertEqual(summary.total, 4)
        XCTAssertEqual(summary.correct, 3)
        XCTAssertEqual(summary.accuracy, 0.75, accuracy: 1e-12)
        XCTAssertEqual(summary.perDegree[.one], .init(correct: 1, total: 2))
        XCTAssertEqual(summary.perDegree[.three], .init(correct: 1, total: 1))
        XCTAssertEqual(summary.perDegree[.five], .init(correct: 1, total: 1))
        XCTAssertNil(summary.perDegree[.two])
    }

    func testEmptySummary() {
        let summary = BenbassatSummary(records: [])
        XCTAssertEqual(summary.total, 0)
        XCTAssertEqual(summary.accuracy, 0)
        XCTAssertTrue(summary.perDegree.isEmpty)
    }
}

import MusicTheory
import Playback
import XCTest

@testable import SollaEngine

final class BenbassatExerciseTests: XCTestCase {
    func testRoundShape() {
        var rng = SplitMix64(seed: 1)
        let round = BenbassatDegreeExercise().makeRound(index: 0, rng: &rng)

        XCTAssertEqual(round.segments.map(\.id), [.cadence, .target, .resolution])
        XCTAssertEqual(round.options, ChromaticDegree.diatonic(in: .major))
        XCTAssertNotNil(round.key)
        XCTAssertEqual(round.segment(.cadence)?.events.count, 4)
        XCTAssertEqual(round.segment(.target)?.events.count, 1)

        let cadence = round.segment(.cadence)!
        XCTAssertTrue(cadence.replayable)
        XCTAssertFalse(cadence.acceptsEarlyAnswer)
        XCTAssertTrue(cadence.playsInStimulus)

        let target = round.segment(.target)!
        XCTAssertTrue(target.replayable)
        XCTAssertTrue(target.acceptsEarlyAnswer)
        XCTAssertTrue(target.playsInStimulus)

        let resolution = round.segment(.resolution)!
        XCTAssertFalse(resolution.replayable)
        XCTAssertFalse(resolution.acceptsEarlyAnswer)
        XCTAssertFalse(resolution.playsInStimulus)
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
            let key = round.key!
            let target = round.segment(.target)!.events[0].pitches[0]

            XCTAssertTrue(key.contains(target), "target \(target.midi) not diatonic")
            XCTAssertEqual(
                target.pitchClass,
                PitchClass(key.tonic.value + round.expected.semitone)
            )
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
        var degrees = Set<ChromaticDegree>()
        var tonics = Set<PitchClass>()
        for index in 0..<500 {
            let round = exercise.makeRound(index: index, rng: &rng)
            degrees.insert(round.expected)
            tonics.insert(round.segment(.cadence)!.events[0].pitches[0].pitchClass)
        }
        XCTAssertEqual(degrees.count, 7)
        XCTAssertEqual(tonics.count, 12)
    }

    func testRoundKeyMatchesCadence() {
        var rng = SplitMix64(seed: 8)
        let exercise = BenbassatDegreeExercise()
        for index in 0..<50 {
            let round = exercise.makeRound(index: index, rng: &rng)
            let cadence = round.segment(.cadence)!.events
            XCTAssertEqual(round.key?.tonic, cadence[0].pitches[0].pitchClass)
            XCTAssertEqual(round.key?.mode, .major)
        }
    }

    func testFixedTonicUsedEveryRound() {
        var rng = SplitMix64(seed: 9)
        let exercise = BenbassatDegreeExercise(config: .init(fixedTonic: PitchClass(7)))
        for index in 0..<50 {
            let round = exercise.makeRound(index: index, rng: &rng)
            XCTAssertEqual(round.key?.tonic, PitchClass(7))
        }
    }

    func testEnabledDegreesRestrictPool() {
        var rng = SplitMix64(seed: 15)
        let pool = [ChromaticDegree(7), ChromaticDegree(0), ChromaticDegree(4)]
        let exercise = BenbassatDegreeExercise(config: .init(enabledDegrees: pool))
        var seen = Set<ChromaticDegree>()
        for index in 0..<100 {
            let round = exercise.makeRound(index: index, rng: &rng)
            // Options are the pool, sorted ascending.
            XCTAssertEqual(round.options, [ChromaticDegree(0), ChromaticDegree(4), ChromaticDegree(7)])
            XCTAssertTrue(round.options.contains(round.expected))
            seen.insert(round.expected)
        }
        XCTAssertEqual(seen.count, 3)
    }

    /// Verifies the walk for every degree, chromatic ones included: it starts
    /// on the target, moves monotonically to the nearest tonic, and every
    /// step after the first is diatonic.
    func testResolutionWalkForAllDegrees() {
        for mode in [Mode.major, Mode.minor] {
            var rng = SplitMix64(seed: 10)
            let exercise = BenbassatDegreeExercise(
                config: .init(
                    mode: mode, fixedTonic: PitchClass(0), enabledDegrees: ChromaticDegree.all))
            var seen = Set<ChromaticDegree>()
            for index in 0..<2000 where seen.count < 12 {
                let round = exercise.makeRound(index: index, rng: &rng)
                guard seen.insert(round.expected).inserted else { continue }

                let semitone = round.expected.semitone
                let intervals = mode.intervals
                let target = round.segment(.target)!.events[0].pitches[0]
                let events = round.segment(.resolution)!.events
                let pitches = events.map { $0.pitches[0] }

                XCTAssertTrue(events.allSatisfy { $0.pitches.count == 1 })
                XCTAssertEqual(pitches.first, target, "semitone \(semitone) must start on target")
                XCTAssertEqual(
                    pitches.last?.pitchClass, round.key?.tonic,
                    "semitone \(semitone) must end on the tonic")
                XCTAssertEqual(events.last?.duration, exercise.config.resolutionFinalDuration)
                // Every note after the first is diatonic.
                for pitch in pitches.dropFirst() {
                    XCTAssertTrue(round.key!.contains(pitch), "walk left the scale")
                }

                switch semitone {
                case 0:
                    XCTAssertEqual(events.count, 1)
                case 1...5:
                    XCTAssertEqual(events.count, intervals.filter { $0 < semitone }.count + 1)
                    XCTAssertTrue(
                        zip(pitches, pitches.dropFirst()).allSatisfy { $0.midi > $1.midi },
                        "semitone \(semitone) must walk down")
                default:
                    XCTAssertEqual(events.count, intervals.filter { $0 > semitone }.count + 2)
                    XCTAssertTrue(
                        zip(pitches, pitches.dropFirst()).allSatisfy { $0.midi < $1.midi },
                        "semitone \(semitone) must walk up")
                    XCTAssertEqual(pitches.last?.midi, exercise.config.tonicMidiBase + 24)
                }
            }
            XCTAssertEqual(seen.count, 12, "mode \(mode)")
        }
    }

    /// The offsets recovered from walk audio round-trip to the offsets the
    /// walk was built from, for every degree in both modes.
    func testResolutionWalkOffsets() {
        for mode in [Mode.major, Mode.minor] {
            var rng = SplitMix64(seed: 13)
            let exercise = BenbassatDegreeExercise(
                config: .init(
                    mode: mode, fixedTonic: PitchClass(9), enabledDegrees: ChromaticDegree.all))
            var seen = Set<ChromaticDegree>()
            for index in 0..<2000 where seen.count < 12 {
                let round = exercise.makeRound(index: index, rng: &rng)
                guard seen.insert(round.expected).inserted else { continue }

                let semitone = round.expected.semitone
                let intervals = mode.intervals
                let expected: [Int]
                if semitone == 0 {
                    expected = [0]
                } else if semitone <= 5 {
                    expected = [semitone] + intervals.filter { $0 < semitone }.sorted(by: >)
                } else {
                    expected = [semitone] + intervals.filter { $0 > semitone }.sorted() + [12]
                }

                let events = round.segment(.resolution)!.events
                XCTAssertEqual(
                    ResolutionWalk.offsets(of: events), expected, "semitone \(semitone)")
            }
            XCTAssertEqual(seen.count, 12, "mode \(mode)")
        }
    }

    func testRandomOctavesMoveTargetRegister() {
        var rng = SplitMix64(seed: 14)
        let exercise = BenbassatDegreeExercise(
            config: .init(fixedTonic: PitchClass(0), randomOctaves: true))
        var anchors = Set<Int>()
        for index in 0..<200 {
            let round = exercise.makeRound(index: index, rng: &rng)
            let key = round.key!
            let target = round.segment(.target)!.events[0].pitches[0]
            let walk = round.segment(.resolution)!.events

            XCTAssertTrue(key.contains(target))
            // The walk follows the target into its register: starts on it and
            // ends on a tonic within an octave of it.
            XCTAssertEqual(walk.first?.pitches[0], target)
            XCTAssertEqual(walk.last?.pitches[0].pitchClass, key.tonic)
            XCTAssertLessThanOrEqual(abs(walk.last!.pitches[0].midi - target.midi), 12)
            XCTAssertEqual(ResolutionWalk.offsets(of: walk).count, walk.count)

            anchors.insert(target.midi - round.expected.semitone)
        }
        // All three registers (an octave down, usual, an octave up) appear.
        XCTAssertEqual(anchors, [48, 60, 72])
    }

    func testMinorRoundsUseNaturalMinorWithHarmonicDominant() {
        var rng = SplitMix64(seed: 12)
        let exercise = BenbassatDegreeExercise(config: .init(mode: .minor, fixedTonic: PitchClass(0)))
        for index in 0..<100 {
            let round = exercise.makeRound(index: index, rng: &rng)
            let key = round.key!
            XCTAssertEqual(key.mode, .minor)

            // The mystery note and the resolution walk stay natural minor.
            let target = round.segment(.target)!.events[0].pitches[0]
            XCTAssertTrue(key.contains(target), "target \(target.midi) not natural minor")
            for event in round.segment(.resolution)!.events {
                XCTAssertTrue(key.contains(event.pitches[0]))
            }

            // The dominant (third cadence chord) carries the raised leading
            // tone: B rather than B♭ in C minor.
            let cadence = round.segment(.cadence)!.events
            let dominantClasses = Set(cadence[2].pitches.map(\.pitchClass))
            XCTAssertTrue(dominantClasses.contains(PitchClass(11)), "V lacks leading tone")
            XCTAssertFalse(dominantClasses.contains(PitchClass(10)), "V still has subtonic")
            // The other chords stay purely diatonic.
            for chordIndex in [0, 1, 3] {
                for pitch in cadence[chordIndex].pitches {
                    XCTAssertTrue(key.contains(pitch))
                }
            }
        }
    }

    func testConfigTempoMapping() {
        let config = BenbassatDegreeExercise.Config.make(cadenceBpm: 60, noteBpm: 60)
        XCTAssertEqual(config.chordDuration, 0.9, accuracy: 1e-12)
        XCTAssertEqual(config.chordGap, 0.1, accuracy: 1e-12)
        XCTAssertEqual(config.finalChordDuration, 1.5, accuracy: 1e-12)
        XCTAssertEqual(config.gapBeforeTarget, 0.75, accuracy: 1e-12)
        XCTAssertEqual(config.targetDuration, 1.0, accuracy: 1e-12)
        XCTAssertEqual(config.resolutionNoteDuration, 0.5, accuracy: 1e-12)
        XCTAssertEqual(config.resolutionNoteGap, 0.05, accuracy: 1e-12)
        XCTAssertEqual(config.resolutionFinalDuration, 1.0, accuracy: 1e-12)

        // Defaults stay close to the original hand-tuned durations.
        let defaults = BenbassatDegreeExercise.Config.make()
        XCTAssertEqual(defaults.roundCount, 20)
        XCTAssertNil(defaults.fixedTonic)
        XCTAssertNil(defaults.enabledDegrees)
        XCTAssertEqual(defaults.chordDuration, 0.8, accuracy: 0.05)
        XCTAssertEqual(defaults.targetDuration, 1.5, accuracy: 1e-12)
    }
}

final class BenbassatSummaryTests: XCTestCase {
    private let doDegree = ChromaticDegree(0)
    private let mi = ChromaticDegree(4)
    private let sol = ChromaticDegree(7)

    func testSummaryMath() {
        let records: [RoundRecord<ChromaticDegree>] = [
            RoundRecord(expected: doDegree, given: doDegree),
            RoundRecord(expected: doDegree, given: sol),
            RoundRecord(expected: mi, given: mi),
            RoundRecord(expected: sol, given: sol),
        ]
        let summary = BenbassatSummary(records: records)

        XCTAssertEqual(summary.total, 4)
        XCTAssertEqual(summary.correct, 3)
        XCTAssertEqual(summary.accuracy, 0.75, accuracy: 1e-12)
        XCTAssertEqual(summary.perDegree[doDegree], .init(correct: 1, total: 2))
        XCTAssertEqual(summary.perDegree[mi], .init(correct: 1, total: 1))
        XCTAssertEqual(summary.perDegree[sol], .init(correct: 1, total: 1))
        XCTAssertNil(summary.perDegree[ChromaticDegree(2)])
    }

    func testEmptySummary() {
        let summary = BenbassatSummary(records: [])
        XCTAssertEqual(summary.total, 0)
        XCTAssertEqual(summary.accuracy, 0)
        XCTAssertTrue(summary.perDegree.isEmpty)
    }
}

// Explicit test manifest for Linux (see MusicTheoryTests/XCTestManifests.swift).
#if !canImport(ObjectiveC)
    import XCTest

    // swift-format-ignore: AlwaysUseLowerCamelCase
    public func __allTests() -> [XCTestCaseEntry] {
        return [
            testCase([
                ("testInitialState", asyncTest(SessionEngineTests.testInitialState)),
                (
                    "testStartPlaysCadenceThenTargetThenAwaits",
                    asyncTest(SessionEngineTests.testStartPlaysCadenceThenTargetThenAwaits)
                ),
                ("testStartTwiceIsNoOp", asyncTest(SessionEngineTests.testStartTwiceIsNoOp)),
                (
                    "testCorrectSubmitScoresAndShowsFeedback",
                    asyncTest(SessionEngineTests.testCorrectSubmitScoresAndShowsFeedback)
                ),
                ("testWrongSubmitDoesNotScore", asyncTest(SessionEngineTests.testWrongSubmitDoesNotScore)),
                (
                    "testSubmitIgnoredOutsideAwaitingAnswer",
                    asyncTest(SessionEngineTests.testSubmitIgnoredOutsideAwaitingAnswer)
                ),
                (
                    "testNextAdvancesRoundsAndEndsInSummary",
                    asyncTest(SessionEngineTests.testNextAdvancesRoundsAndEndsInSummary)
                ),
                (
                    "testNextIgnoredWhileAwaitingAnswer",
                    asyncTest(SessionEngineTests.testNextIgnoredWhileAwaitingAnswer)
                ),
                (
                    "testReplayReplaysOnlyRequestedSegmentAndRestoresPhase",
                    asyncTest(SessionEngineTests.testReplayReplaysOnlyRequestedSegmentAndRestoresPhase)
                ),
                ("testReplayIgnoredWhenIdle", asyncTest(SessionEngineTests.testReplayIgnoredWhenIdle)),
                ("testCancelStopsAudio", asyncTest(SessionEngineTests.testCancelStopsAudio)),
                (
                    "testStatesStreamYieldsCurrentStateImmediately",
                    asyncTest(SessionEngineTests.testStatesStreamYieldsCurrentStateImmediately)
                ),
                (
                    "testSubmitDuringTargetShowsFeedbackAndDoesNotClobber",
                    asyncTest(SessionEngineTests.testSubmitDuringTargetShowsFeedbackAndDoesNotClobber)
                ),
                (
                    "testSubmitDuringCadenceIgnored",
                    asyncTest(SessionEngineTests.testSubmitDuringCadenceIgnored)
                ),
                (
                    "testAutoResolutionPlaysAfterNormalSubmit",
                    asyncTest(SessionEngineTests.testAutoResolutionPlaysAfterNormalSubmit)
                ),
                (
                    "testAutoResolutionAfterEarlySubmitWaitsForTargetToFinish",
                    asyncTest(SessionEngineTests.testAutoResolutionAfterEarlySubmitWaitsForTargetToFinish)
                ),
                (
                    "testPlayResolutionOnlyDuringFeedbackAndNoDoublePlay",
                    asyncTest(SessionEngineTests.testPlayResolutionOnlyDuringFeedbackAndNoDoublePlay)
                ),
                (
                    "testReplayIgnoresResolutionSegment",
                    asyncTest(SessionEngineTests.testReplayIgnoresResolutionSegment)
                ),
                (
                    "testDeterministicWithSameSeed",
                    asyncTest(SessionEngineTests.testDeterministicWithSameSeed)
                ),
            ]),
            testCase([
                ("testRoundShape", BenbassatExerciseTests.testRoundShape),
                (
                    "testCadenceStartsAndEndsOnTonicChordBass",
                    BenbassatExerciseTests.testCadenceStartsAndEndsOnTonicChordBass
                ),
                (
                    "testTargetIsDiatonicDegreeOfRoundKey",
                    BenbassatExerciseTests.testTargetIsDiatonicDegreeOfRoundKey
                ),
                (
                    "testTargetSitsAboveCadenceRegister",
                    BenbassatExerciseTests.testTargetSitsAboveCadenceRegister
                ),
                (
                    "testAllDegreesAndKeysEventuallyAppear",
                    BenbassatExerciseTests.testAllDegreesAndKeysEventuallyAppear
                ),
                (
                    "testRoundKeyMatchesCadence",
                    BenbassatExerciseTests.testRoundKeyMatchesCadence
                ),
                (
                    "testFixedTonicUsedEveryRound",
                    BenbassatExerciseTests.testFixedTonicUsedEveryRound
                ),
                (
                    "testResolutionWalkForAllDegrees",
                    BenbassatExerciseTests.testResolutionWalkForAllDegrees
                ),
                (
                    "testEnabledDegreesRestrictPool",
                    BenbassatExerciseTests.testEnabledDegreesRestrictPool
                ),
                (
                    "testResolutionWalkOffsets",
                    BenbassatExerciseTests.testResolutionWalkOffsets
                ),
                (
                    "testRandomOctavesMoveTargetRegister",
                    BenbassatExerciseTests.testRandomOctavesMoveTargetRegister
                ),
                (
                    "testMinorRoundsUseNaturalMinorWithHarmonicDominant",
                    BenbassatExerciseTests.testMinorRoundsUseNaturalMinorWithHarmonicDominant
                ),
                (
                    "testConfigTempoMapping",
                    BenbassatExerciseTests.testConfigTempoMapping
                ),
            ]),
            testCase([
                ("testSummaryMath", BenbassatSummaryTests.testSummaryMath),
                ("testEmptySummary", BenbassatSummaryTests.testEmptySummary),
            ]),
        ]
    }
#endif

// Explicit test manifest for Linux (see MusicTheoryTests/XCTestManifests.swift).
#if !canImport(ObjectiveC)
    import XCTest

    // swift-format-ignore: AlwaysUseLowerCamelCase
    public func __allTests() -> [XCTestCaseEntry] {
        return [
            testCase([
                ("testEnvelopeShape", ADSRTests.testEnvelopeShape),
                ("testShortGateReleasesFromCurrentLevel", ADSRTests.testShortGateReleasesFromCurrentLevel),
            ]),
            testCase([
                ("testTotalFramesIncludesReleaseTail", ToneSequencerTests.testTotalFramesIncludesReleaseTail),
                ("testTotalFramesForSequenceWithGaps", ToneSequencerTests.testTotalFramesForSequenceWithGaps),
                ("testDominantFrequencyMatchesPitch", ToneSequencerTests.testDominantFrequencyMatchesPitch),
                ("testChordDoesNotClip", ToneSequencerTests.testChordDoesNotClip),
                ("testSilenceDuringGapAndAfterEnd", ToneSequencerTests.testSilenceDuringGapAndAfterEnd),
                ("testRenderIsDeterministic", ToneSequencerTests.testRenderIsDeterministic),
            ]),
            testCase([
                (
                    "testPicksNearestLayerThenNearestRoot",
                    SampleBankTests.testPicksNearestLayerThenNearestRoot
                ),
                ("testEmptyBankReturnsNil", SampleBankTests.testEmptyBankReturnsNil),
            ]),
            testCase([
                (
                    "testUnshiftedPlaybackKeepsFrequency",
                    SampleSequencerTests.testUnshiftedPlaybackKeepsFrequency
                ),
                ("testResamplingShiftsPitch", SampleSequencerTests.testResamplingShiftsPitch),
                (
                    "testReleaseRampEndsInSilenceWithoutClicks",
                    SampleSequencerTests.testReleaseRampEndsInSilenceWithoutClicks
                ),
                ("testChordDoesNotClip", SampleSequencerTests.testChordDoesNotClip),
                ("testShortRecordingEndsVoiceEarly", SampleSequencerTests.testShortRecordingEndsVoiceEarly),
                ("testRenderIsDeterministic", SampleSequencerTests.testRenderIsDeterministic),
            ]),
            testCase([
                ("testDecodeAndValidate", SamplePackManifestTests.testDecodeAndValidate),
                (
                    "testRejectsUnsupportedFormatVersion",
                    SamplePackManifestTests.testRejectsUnsupportedFormatVersion
                ),
                (
                    "testRejectsSampleWithUnknownLayer",
                    SamplePackManifestTests.testRejectsSampleWithUnknownLayer
                ),
            ]),
        ]
    }
#endif

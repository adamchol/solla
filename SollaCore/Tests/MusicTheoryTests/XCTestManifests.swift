// Explicit test manifest for Linux, where nixpkgs' Swift toolchain lacks
// libIndexStore.so and SwiftPM's automatic test discovery fails.
// When adding a test method, list it here too (Xcode/macOS ignores this file).
#if !canImport(ObjectiveC)
    import XCTest

    // swift-format-ignore: AlwaysUseLowerCamelCase
    public func __allTests() -> [XCTestCaseEntry] {
        return [
            testCase([
                ("testReferenceFrequencies", PitchTests.testReferenceFrequencies),
                ("testPitchClassNormalization", PitchTests.testPitchClassNormalization),
                ("testPitchClassNames", PitchTests.testPitchClassNames),
            ]),
            testCase([
                ("testMajorIntervals", KeyTests.testMajorIntervals),
                ("testMinorIntervals", KeyTests.testMinorIntervals),
                ("testMinorSolfege", KeyTests.testMinorSolfege),
                ("testSolfegeLabels", KeyTests.testSolfegeLabels),
                ("testDegreePitchesInAllKeys", KeyTests.testDegreePitchesInAllKeys),
                ("testContainsRejectsChromaticNotes", KeyTests.testContainsRejectsChromaticNotes),
                ("testDegreeAdvance", KeyTests.testDegreeAdvance),
                ("testChromaticDegreeSolfege", KeyTests.testChromaticDegreeSolfege),
                (
                    "testChromaticDegreeDiatonicMembership",
                    KeyTests.testChromaticDegreeDiatonicMembership
                ),
                ("testKeyDisplayName", KeyTests.testKeyDisplayName),
            ]),
            testCase([
                ("testTriadDegrees", ChordTests.testTriadDegrees),
                ("testCMajorTriadPitchClasses", ChordTests.testCMajorTriadPitchClasses),
                ("testAuthenticCadenceShape", ChordTests.testAuthenticCadenceShape),
            ]),
            testCase([
                (
                    "testVoicingInvariantsAcrossAllKeysAndCadenceChords",
                    VoicingTests.testVoicingInvariantsAcrossAllKeysAndCadenceChords
                ),
                ("testVoicingIsDeterministic", VoicingTests.testVoicingIsDeterministic),
            ]),
        ]
    }
#endif

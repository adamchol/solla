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
            ]),
            testCase([
                ("testMajorIntervals", KeyTests.testMajorIntervals),
                ("testSolfegeLabels", KeyTests.testSolfegeLabels),
                ("testDegreePitchesInAllKeys", KeyTests.testDegreePitchesInAllKeys),
                ("testContainsRejectsChromaticNotes", KeyTests.testContainsRejectsChromaticNotes),
                ("testDegreeAdvance", KeyTests.testDegreeAdvance),
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

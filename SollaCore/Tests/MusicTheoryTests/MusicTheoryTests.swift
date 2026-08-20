import XCTest

@testable import MusicTheory

final class PitchTests: XCTestCase {
    func testReferenceFrequencies() {
        XCTAssertEqual(Pitch(midi: 69).frequency, 440.0, accuracy: 1e-9)
        XCTAssertEqual(Pitch(midi: 60).frequency, 261.6255653, accuracy: 1e-6)
        XCTAssertEqual(Pitch(midi: 81).frequency, 880.0, accuracy: 1e-9)
    }

    func testPitchClassNormalization() {
        XCTAssertEqual(PitchClass(12).value, 0)
        XCTAssertEqual(PitchClass(-1).value, 11)
        XCTAssertEqual(PitchClass(-13).value, 11)
        XCTAssertEqual(Pitch(midi: 61).pitchClass, PitchClass(1))
    }
}

final class KeyTests: XCTestCase {
    func testMajorIntervals() {
        XCTAssertEqual(Mode.major.intervals, [0, 2, 4, 5, 7, 9, 11])
    }

    func testSolfegeLabels() {
        XCTAssertEqual(
            ScaleDegree.allCases.map(\.solfege),
            ["Do", "Re", "Mi", "Fa", "Sol", "La", "Ti"]
        )
    }

    func testDegreePitchesInAllKeys() {
        for tonic in 0..<12 {
            let key = Key(tonic: PitchClass(tonic), mode: .major)
            let tonicMidi = 48 + tonic
            for degree in ScaleDegree.allCases {
                let pitch = key.pitch(of: degree, tonicMidi: tonicMidi)
                XCTAssertEqual(pitch.midi, tonicMidi + Mode.major.interval(of: degree))
                XCTAssertTrue(key.contains(pitch), "degree \(degree) not diatonic in key \(tonic)")
            }
        }
    }

    func testContainsRejectsChromaticNotes() {
        let cMajor = Key(tonic: PitchClass(0), mode: .major)
        XCTAssertFalse(cMajor.contains(Pitch(midi: 61)))  // C#
        XCTAssertFalse(cMajor.contains(Pitch(midi: 66)))  // F#
        XCTAssertTrue(cMajor.contains(Pitch(midi: 71)))  // B
    }

    func testDegreeAdvance() {
        XCTAssertEqual(ScaleDegree.one.advanced(by: 2), .three)
        XCTAssertEqual(ScaleDegree.five.advanced(by: 4), .two)
        XCTAssertEqual(ScaleDegree.seven.advanced(by: 1), .one)
    }
}

final class ChordTests: XCTestCase {
    func testTriadDegrees() {
        XCTAssertEqual(DiatonicChord(root: .one).degrees, [.one, .three, .five])
        XCTAssertEqual(DiatonicChord(root: .five).degrees, [.five, .seven, .two])
    }

    func testCMajorTriadPitchClasses() {
        let cMajor = Key(tonic: PitchClass(0), mode: .major)
        XCTAssertEqual(
            DiatonicChord(root: .one).pitchClasses(in: cMajor),
            [PitchClass(0), PitchClass(4), PitchClass(7)]
        )
        XCTAssertEqual(
            DiatonicChord(root: .five).pitchClasses(in: cMajor),
            [PitchClass(7), PitchClass(11), PitchClass(2)]
        )
    }

    func testAuthenticCadenceShape() {
        XCTAssertEqual(Cadence.authentic.chords.map(\.root), [.one, .four, .five, .one])
    }
}

final class VoicingTests: XCTestCase {
    let voicer = ChordVoicer()

    func testVoicingInvariantsAcrossAllKeysAndCadenceChords() {
        for tonic in 0..<12 {
            let key = Key(tonic: PitchClass(tonic), mode: .major)
            for chord in Cadence.authentic.chords {
                let pitches = voicer.voice(chord, in: key)
                XCTAssertEqual(pitches.count, 4)

                let bass = pitches[0]
                let upper = Array(pitches.dropFirst())
                XCTAssertTrue((41..<53).contains(bass.midi), "bass \(bass.midi) out of range")
                XCTAssertEqual(bass.pitchClass, chord.pitchClasses(in: key)[0])

                XCTAssertEqual(upper, upper.sorted())
                for pitch in upper {
                    XCTAssertTrue((60..<72).contains(pitch.midi), "upper \(pitch.midi) out of range")
                }
                XCTAssertEqual(
                    Set(upper.map(\.pitchClass)),
                    Set(chord.pitchClasses(in: key))
                )
            }
        }
    }

    func testVoicingIsDeterministic() {
        let key = Key(tonic: PitchClass(7), mode: .major)
        let chord = DiatonicChord(root: .four)
        XCTAssertEqual(voicer.voice(chord, in: key), voicer.voice(chord, in: key))
    }
}

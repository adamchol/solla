import MusicTheory
import Playback
import XCTest

@testable import ToneSynth

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

final class ADSRTests: XCTestCase {
    let env = ADSR(attack: 0.01, decay: 0.08, sustain: 0.7, release: 0.25)

    func testEnvelopeShape() {
        XCTAssertEqual(env.amplitude(at: -0.1, gateDuration: 1), 0)
        XCTAssertEqual(env.amplitude(at: 0, gateDuration: 1), 0)
        XCTAssertEqual(env.amplitude(at: 0.005, gateDuration: 1), 0.5, accuracy: 1e-9)
        XCTAssertEqual(env.amplitude(at: 0.01, gateDuration: 1), 1.0, accuracy: 1e-9)
        XCTAssertEqual(env.amplitude(at: 0.05, gateDuration: 1), 0.85, accuracy: 1e-9)
        XCTAssertEqual(env.amplitude(at: 0.5, gateDuration: 1), 0.7, accuracy: 1e-9)
        // Halfway through release.
        XCTAssertEqual(env.amplitude(at: 1.125, gateDuration: 1), 0.35, accuracy: 1e-9)
        XCTAssertEqual(env.amplitude(at: 1.25, gateDuration: 1), 0)
        XCTAssertEqual(env.amplitude(at: 2.0, gateDuration: 1), 0)
    }

    func testShortGateReleasesFromCurrentLevel() {
        // Gate closes mid-attack: release starts from the attack-phase level.
        let level = env.amplitude(at: 0.005 + 0.125, gateDuration: 0.005)
        XCTAssertEqual(level, 0.5 * 0.5, accuracy: 1e-9)
    }
}

final class ToneSequencerTests: XCTestCase {
    let sampleRate = 44_100.0

    private func renderAll(_ sequencer: ToneSequencer, chunk: Int = 512) -> [Float] {
        var samples: [Float] = []
        var buffer = [Float](repeating: 0, count: chunk)
        while !sequencer.isFinished {
            buffer.withUnsafeMutableBufferPointer { sequencer.render(into: $0) }
            samples.append(contentsOf: buffer)
        }
        return samples
    }

    /// Signal power at `frequency` via the Goertzel algorithm.
    private func goertzelPower(_ samples: ArraySlice<Float>, frequency: Double) -> Double {
        let omega = 2.0 * Double.pi * frequency / sampleRate
        let coefficient = 2.0 * cos(omega)
        var sPrev = 0.0
        var sPrev2 = 0.0
        for sample in samples {
            let s = Double(sample) + coefficient * sPrev - sPrev2
            sPrev2 = sPrev
            sPrev = s
        }
        return sPrev * sPrev + sPrev2 * sPrev2 - coefficient * sPrev * sPrev2
    }

    func testTotalFramesIncludesReleaseTail() {
        let envelope = ADSR()
        let event = PlaybackEvent(pitches: [Pitch(midi: 69)], duration: 1.0, gapAfter: 0.0)
        let sequencer = ToneSequencer(events: [event], sampleRate: sampleRate, envelope: envelope)
        let expected = Int(((1.0 + envelope.release) * sampleRate).rounded(.up))
        XCTAssertEqual(sequencer.totalFrames, expected)
    }

    func testTotalFramesForSequenceWithGaps() {
        let events = [
            PlaybackEvent(pitches: [Pitch(midi: 60)], duration: 0.8, gapAfter: 0.1),
            PlaybackEvent(pitches: [Pitch(midi: 64)], duration: 1.2, gapAfter: 0.6),
        ]
        let envelope = ADSR()
        let sequencer = ToneSequencer(events: events, sampleRate: sampleRate, envelope: envelope)
        // Last voice starts at 0.9s and rings for 1.2s + release; the trailing
        // gap ends later than that, so the schedule length wins.
        let scheduleFrames = Int((0.9 * sampleRate).rounded()) + Int((1.8 * sampleRate).rounded())
        let lastVoiceEnd =
            Int((0.9 * sampleRate).rounded()) + Int(((1.2 + envelope.release) * sampleRate).rounded(.up))
        XCTAssertEqual(sequencer.totalFrames, max(scheduleFrames, lastVoiceEnd))
    }

    func testDominantFrequencyMatchesPitch() {
        let pitch = Pitch(midi: 69)  // A4 = 440 Hz
        let event = PlaybackEvent(pitches: [pitch], duration: 1.0)
        let sequencer = ToneSequencer(events: [event], sampleRate: sampleRate)
        let samples = renderAll(sequencer)

        // Analyze the sustain portion (skip attack/decay transients).
        let window = samples[8820..<35280]
        let atPitch = goertzelPower(window, frequency: pitch.frequency)
        // The fundamental should dominate clearly-off frequencies.
        for wrong in [pitch.frequency * 0.94, pitch.frequency * 1.06, 620.0] {
            XCTAssertGreaterThan(atPitch, goertzelPower(window, frequency: wrong) * 10)
        }
    }

    func testChordDoesNotClip() {
        let chord = PlaybackEvent(
            pitches: [41, 60, 64, 67].map { Pitch(midi: $0) },
            duration: 1.0,
            gain: 0.85
        )
        let sequencer = ToneSequencer(events: [chord], sampleRate: sampleRate)
        let samples = renderAll(sequencer)
        let peak = samples.map(abs).max() ?? 0
        XCTAssertLessThanOrEqual(peak, 1.0)
        XCTAssertGreaterThan(peak, 0.1, "chord should actually be audible")
    }

    func testSilenceDuringGapAndAfterEnd() {
        let events = [
            PlaybackEvent(pitches: [Pitch(midi: 60)], duration: 0.2, gapAfter: 1.0),
            PlaybackEvent(pitches: [Pitch(midi: 64)], duration: 0.2),
        ]
        let envelope = ADSR()
        let sequencer = ToneSequencer(events: events, sampleRate: sampleRate, envelope: envelope)
        let samples = renderAll(sequencer)

        // Well inside the gap: after the first note's release, before the second note.
        let gapStart = Int((0.2 + envelope.release + 0.05) * sampleRate)
        let gapEnd = Int(1.15 * sampleRate)
        for index in stride(from: gapStart, to: gapEnd, by: 137) {
            XCTAssertEqual(samples[index], 0, "expected silence at frame \(index)")
        }

        // Sequencer produces silence when rendered past its end.
        var buffer = [Float](repeating: 1, count: 256)
        buffer.withUnsafeMutableBufferPointer { sequencer.render(into: $0) }
        XCTAssertTrue(buffer.allSatisfy { $0 == 0 })
    }

    func testRenderIsDeterministic() {
        let event = PlaybackEvent(pitches: [Pitch(midi: 65), Pitch(midi: 72)], duration: 0.5)
        let a = renderAll(ToneSequencer(events: [event], sampleRate: sampleRate))
        let b = renderAll(ToneSequencer(events: [event], sampleRate: sampleRate), chunk: 333)
        // Chunk size must not affect sample values; lengths only differ by
        // final-chunk padding, so compare the shared prefix.
        for index in stride(from: 0, to: min(a.count, b.count), by: 997) {
            XCTAssertEqual(a[index], b[index])
        }
    }
}

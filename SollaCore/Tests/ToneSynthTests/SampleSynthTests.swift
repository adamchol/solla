import Foundation
import MusicTheory
import Playback
import XCTest

@testable import ToneSynth

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

final class SampleBankTests: XCTestCase {
    private func buffer(root: Int, nominalGain: Double) -> SampleBuffer {
        SampleBuffer(samples: [0, 0], sampleRate: 44_100, rootMidi: root, nominalGain: nominalGain)
    }

    func testPicksNearestLayerThenNearestRoot() {
        let bank = SampleBank(
            buffers: [
                buffer(root: 60, nominalGain: 0.4),
                buffer(root: 63, nominalGain: 0.4),
                buffer(root: 60, nominalGain: 0.9),
                buffer(root: 63, nominalGain: 0.9),
            ],
            release: 0.3
        )
        // Gain 0.85 → the 0.9 layer; midi 62 → root 63 is nearer.
        let chosen = bank.buffer(forMidi: 62, gain: 0.85)
        XCTAssertEqual(chosen?.nominalGain, 0.9)
        XCTAssertEqual(chosen?.rootMidi, 63)
        // Layer wins over root proximity: gain 0.35 picks the 0.4 layer even
        // for an exact 0.9-layer root match.
        let quiet = bank.buffer(forMidi: 60, gain: 0.35)
        XCTAssertEqual(quiet?.nominalGain, 0.4)
        XCTAssertEqual(quiet?.rootMidi, 60)
    }

    func testEmptyBankReturnsNil() {
        let bank = SampleBank(buffers: [], release: 0.3)
        XCTAssertNil(bank.buffer(forMidi: 60, gain: 0.8))
    }
}

final class SampleSequencerTests: XCTestCase {
    let sampleRate = 44_100.0

    /// A sine recording at `frequency`, long enough to cover the tests.
    private func sineBuffer(
        frequency: Double,
        rootMidi: Int,
        seconds: Double = 3.0,
        nominalGain: Double = 0.85,
        amplitude: Double = 0.5
    ) -> SampleBuffer {
        let count = Int(seconds * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let t = Double(index) / sampleRate
            samples[index] = Float(amplitude * sin(2.0 * Double.pi * frequency * t))
        }
        return SampleBuffer(
            samples: samples, sampleRate: sampleRate, rootMidi: rootMidi, nominalGain: nominalGain
        )
    }

    private func renderAll(_ sequencer: SampleSequencer, chunk: Int = 512) -> [Float] {
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

    func testUnshiftedPlaybackKeepsFrequency() {
        let bank = SampleBank(buffers: [sineBuffer(frequency: 440, rootMidi: 69)], release: 0.25)
        let event = PlaybackEvent(pitches: [Pitch(midi: 69)], duration: 1.0, gain: 0.85)
        let sequencer = SampleSequencer(events: [event], bank: bank, sampleRate: sampleRate)
        let samples = renderAll(sequencer)

        let window = samples[8820..<35280]
        let atPitch = goertzelPower(window, frequency: 440)
        for wrong in [440 * 0.94, 440 * 1.06, 620.0] {
            XCTAssertGreaterThan(atPitch, goertzelPower(window, frequency: wrong) * 10)
        }
    }

    func testResamplingShiftsPitch() {
        // Root is A4 = 440 Hz; requesting A5 must double the frequency.
        let bank = SampleBank(buffers: [sineBuffer(frequency: 440, rootMidi: 69)], release: 0.25)
        let event = PlaybackEvent(pitches: [Pitch(midi: 81)], duration: 1.0, gain: 0.85)
        let sequencer = SampleSequencer(events: [event], bank: bank, sampleRate: sampleRate)
        let samples = renderAll(sequencer)

        let window = samples[8820..<35280]
        let atTarget = goertzelPower(window, frequency: 880)
        for wrong in [440.0, 880 * 0.94, 880 * 1.06] {
            XCTAssertGreaterThan(atTarget, goertzelPower(window, frequency: wrong) * 10)
        }
    }

    func testReleaseRampEndsInSilenceWithoutClicks() {
        let bank = SampleBank(buffers: [sineBuffer(frequency: 220, rootMidi: 57)], release: 0.25)
        let event = PlaybackEvent(pitches: [Pitch(midi: 57)], duration: 0.5, gain: 0.85)
        let sequencer = SampleSequencer(events: [event], bank: bank, sampleRate: sampleRate)
        let samples = renderAll(sequencer)

        // Fully silent after gate + release.
        let silentFrom = Int((0.5 + 0.25) * sampleRate) + 2
        for index in stride(from: silentFrom, to: samples.count, by: 61) {
            XCTAssertEqual(samples[index], 0, "expected silence at frame \(index)")
        }
        // No click: adjacent samples never jump more than the source sine
        // could move plus a small envelope step.
        var maxJump: Float = 0
        for index in 1..<samples.count {
            maxJump = max(maxJump, abs(samples[index] - samples[index - 1]))
        }
        // 220 Hz sine at 0.5 amplitude moves ≤ 2π·220/44100·0.5 ≈ 0.016/frame.
        XCTAssertLessThan(maxJump, 0.05)
    }

    func testChordDoesNotClip() {
        // Full-scale-ish recordings on each chord tone.
        let buffers = [41, 60, 64, 67].map { midi in
            sineBuffer(
                frequency: Pitch(midi: midi).frequency,
                rootMidi: midi,
                amplitude: 0.9
            )
        }
        let bank = SampleBank(buffers: buffers, release: 0.25)
        let chord = PlaybackEvent(
            pitches: [41, 60, 64, 67].map { Pitch(midi: $0) },
            duration: 1.0,
            gain: 0.85
        )
        let sequencer = SampleSequencer(events: [chord], bank: bank, sampleRate: sampleRate)
        let samples = renderAll(sequencer)
        let peak = samples.map(abs).max() ?? 0
        XCTAssertLessThanOrEqual(peak, 1.0)
        XCTAssertGreaterThan(peak, 0.1, "chord should actually be audible")
    }

    func testShortRecordingEndsVoiceEarly() {
        // 0.3 s recording, 1 s gate: the voice must stop at the recording's
        // end without reading past the buffer.
        let bank = SampleBank(
            buffers: [sineBuffer(frequency: 440, rootMidi: 69, seconds: 0.3)],
            release: 0.25
        )
        let event = PlaybackEvent(pitches: [Pitch(midi: 69)], duration: 1.0, gain: 0.85)
        let sequencer = SampleSequencer(events: [event], bank: bank, sampleRate: sampleRate)
        let samples = renderAll(sequencer)
        let silentFrom = Int(0.3 * sampleRate) + 2
        for index in stride(from: silentFrom, to: min(samples.count, silentFrom + 8000), by: 37) {
            XCTAssertEqual(samples[index], 0, "expected silence at frame \(index)")
        }
    }

    func testRenderIsDeterministic() {
        let bank = SampleBank(
            buffers: [sineBuffer(frequency: 330, rootMidi: 64)],
            release: 0.25
        )
        let event = PlaybackEvent(pitches: [Pitch(midi: 65), Pitch(midi: 72)], duration: 0.5)
        let a = renderAll(SampleSequencer(events: [event], bank: bank, sampleRate: sampleRate))
        let b = renderAll(
            SampleSequencer(events: [event], bank: bank, sampleRate: sampleRate), chunk: 333
        )
        for index in stride(from: 0, to: min(a.count, b.count), by: 997) {
            XCTAssertEqual(a[index], b[index])
        }
    }
}

final class SamplePackManifestTests: XCTestCase {
    private let json = """
        {
          "formatVersion": 1,
          "id": "salamander-lite",
          "name": "Piano",
          "version": "1.0.0",
          "instrument": "piano",
          "sampleRate": 44100,
          "channels": 1,
          "releaseSeconds": 0.35,
          "attribution": {
            "title": "Salamander Grand Piano V3+",
            "author": "Alexander Holm",
            "license": "CC-BY-3.0",
            "url": "https://freepats.zenvoid.org/Piano/acoustic-grand-piano.html"
          },
          "layers": [ { "id": 8, "nominalGain": 0.85 } ],
          "samples": [ { "file": "A1v8.m4a", "rootMidi": 33, "layer": 8 } ]
        }
        """

    func testDecodeAndValidate() throws {
        let manifest = try SamplePackManifest.decode(from: Data(json.utf8))
        XCTAssertEqual(manifest.id, "salamander-lite")
        XCTAssertEqual(manifest.samples.count, 1)
        XCTAssertEqual(manifest.nominalGain(forLayer: 8), 0.85)
        XCTAssertNil(manifest.nominalGain(forLayer: 9))
    }

    func testRejectsUnsupportedFormatVersion() {
        let bad = json.replacingOccurrences(of: "\"formatVersion\": 1", with: "\"formatVersion\": 2")
        XCTAssertThrowsError(try SamplePackManifest.decode(from: Data(bad.utf8))) { error in
            XCTAssertEqual(
                error as? SamplePackManifest.ValidationError, .unsupportedFormatVersion(2)
            )
        }
    }

    func testRejectsSampleWithUnknownLayer() {
        let bad = json.replacingOccurrences(of: "\"layer\": 8", with: "\"layer\": 3")
        XCTAssertThrowsError(try SamplePackManifest.decode(from: Data(bad.utf8))) { error in
            XCTAssertEqual(error as? SamplePackManifest.ValidationError, .unknownLayer(3))
        }
    }
}

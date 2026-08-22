import MusicTheory
import Playback

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

/// Renders a sequence of `PlaybackEvent`s from recorded samples.
///
/// Mirrors `ToneSequencer`: all scheduling happens at init — every event
/// pitch becomes an immutable `SampleVoice` with fixed start/end frames —
/// and `render(into:)` is allocation- and lock-free, so it is safe to call
/// from a real-time audio thread.
public final class SampleSequencer {
    public let sampleRate: Double
    /// Total frames including the final release tail.
    public let totalFrames: Int

    private let voices: [SampleVoice]
    private var cursor: Int = 0

    public var isFinished: Bool { cursor >= totalFrames }

    /// Seconds of audio this sequencer will produce.
    public var totalDuration: Double { Double(totalFrames) / sampleRate }

    /// Bounds for scaling a recording's amplitude toward the event gain;
    /// keeps a nearest-layer mismatch from sounding wildly off.
    private static let gainScaleRange = 0.25...1.25

    public init(events: [PlaybackEvent], bank: SampleBank, sampleRate: Double) {
        self.sampleRate = sampleRate
        var voices: [SampleVoice] = []
        var frame = 0
        var lastEnd = 0
        for event in events {
            // Split the event's gain across its simultaneous pitches;
            // sqrt keeps chords loud enough without clipping.
            let chordShare = 1.0 / Double(event.pitches.count).squareRoot()
            for pitch in event.pitches {
                guard let buffer = bank.buffer(forMidi: pitch.midi, gain: event.gain) else {
                    continue
                }
                let scale = min(
                    max(event.gain / buffer.nominalGain, Self.gainScaleRange.lowerBound),
                    Self.gainScaleRange.upperBound
                )
                let voice = SampleVoice(
                    buffer: buffer,
                    midi: pitch.midi,
                    gain: scale * chordShare,
                    startFrame: frame,
                    gateDuration: event.duration,
                    release: bank.release,
                    outputSampleRate: sampleRate
                )
                voices.append(voice)
                lastEnd = max(lastEnd, voice.endFrame)
            }
            frame += Int((event.totalDuration * sampleRate).rounded())
        }
        self.voices = voices
        self.totalFrames = max(frame, lastEnd)
    }

    /// Fill `buffer` with the next chunk of audio, advancing the cursor.
    /// Produces silence once finished.
    public func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        for index in buffer.indices {
            buffer[index] = 0
        }
        let range = cursor..<(cursor + buffer.count)
        for voice in voices where voice.isActive(in: range) {
            voice.render(into: buffer, bufferStart: cursor)
        }
        for index in buffer.indices {
            buffer[index] = Self.softClip(buffer[index])
        }
        cursor += buffer.count
    }

    /// Unlike the synth's shaped voices, summed recordings can momentarily
    /// exceed full scale; this keeps the output in (-1, 1) while leaving
    /// everything below the threshold untouched. Linear to 0.8, then a
    /// smooth compression asymptoting at 1.0 (C¹-continuous at the knee).
    @inline(__always)
    private static func softClip(_ x: Float) -> Float {
        let threshold: Float = 0.8
        let magnitude = abs(x)
        guard magnitude > threshold else { return x }
        let headroom: Float = 1.0 - threshold
        let compressed = threshold + headroom * (1 - exp(-(magnitude - threshold) / headroom))
        return x < 0 ? -compressed : compressed
    }
}

extension SampleSequencer: AudioRenderer {}

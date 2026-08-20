import MusicTheory
import Playback

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

/// Renders a sequence of `PlaybackEvent`s to mono samples.
///
/// All scheduling happens at init: every event pitch becomes an immutable
/// `Voice` with fixed start/end frames. `render(into:)` is allocation- and
/// lock-free, so it is safe to call from a real-time audio thread
/// (e.g. an `AVAudioSourceNode` render block).
public final class ToneSequencer {
    public let sampleRate: Double
    /// Total frames including the final release tail.
    public let totalFrames: Int

    private let voices: [Voice]
    private var cursor: Int = 0

    public var isFinished: Bool { cursor >= totalFrames }

    /// Seconds of audio this sequencer will produce.
    public var totalDuration: Double { Double(totalFrames) / sampleRate }

    public init(
        events: [PlaybackEvent],
        sampleRate: Double,
        timbre: Timbre = .ePiano,
        envelope: ADSR = ADSR()
    ) {
        self.sampleRate = sampleRate
        var voices: [Voice] = []
        var frame = 0
        var lastEnd = 0
        for event in events {
            // Split the event's gain across its simultaneous pitches;
            // sqrt keeps chords loud enough without clipping.
            let voiceGain = event.gain / (Double(event.pitches.count)).squareRoot()
            for pitch in event.pitches {
                let voice = Voice(
                    frequency: pitch.frequency,
                    gain: voiceGain,
                    startFrame: frame,
                    gateDuration: event.duration,
                    timbre: timbre,
                    envelope: envelope,
                    sampleRate: sampleRate
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
        cursor += buffer.count
    }
}

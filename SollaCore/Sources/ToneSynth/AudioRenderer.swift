/// A finite mono audio stream rendered in real-time-safe chunks.
///
/// Both the synthesized (`ToneSequencer`) and sampled (`SampleSequencer`)
/// paths conform, so the platform playback engine can drive either.
/// Conformers' `render` must stay allocation- and lock-free; callers are
/// responsible for synchronizing access across threads.
public protocol AudioRenderer: AnyObject {
    /// Seconds of audio this renderer will produce, including release tails.
    var totalDuration: Double { get }
    /// True once the cursor has passed the end; `render` then emits silence.
    var isFinished: Bool { get }
    /// Fill `buffer` with the next chunk of audio, advancing the cursor.
    func render(into buffer: UnsafeMutableBufferPointer<Float>)
}

extension ToneSequencer: AudioRenderer {}

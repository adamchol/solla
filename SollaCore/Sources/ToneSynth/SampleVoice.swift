#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

/// One sounding note played from a recorded sample: linear-interpolation
/// resampling for pitch shift, a short anti-click attack ramp, and a linear
/// release ramp after the gate closes. Immutable after creation; rendering is
/// a pure function of the global frame position, deterministic and
/// allocation-free (mirrors `Voice`).
public struct SampleVoice: Sendable {
    public let buffer: SampleBuffer
    /// Source frames consumed per output frame (pitch shift × rate ratio).
    public let rate: Double
    /// Final amplitude scale (event gain vs. nominal gain × chord share).
    public let gain: Double
    /// Global output frame at which the note starts.
    public let startFrame: Int
    /// Output frames the gate is held open.
    public let gateFrames: Int
    /// Output frames of the linear release ramp after the gate closes.
    public let releaseFrames: Int
    /// Output frames of the anti-click attack ramp (~2 ms).
    public let attackFrames: Int
    /// Global output frame at which the voice is fully silent.
    public let endFrame: Int

    public init(
        buffer: SampleBuffer,
        midi: Int,
        gain: Double,
        startFrame: Int,
        gateDuration: Double,
        release: Double,
        outputSampleRate: Double
    ) {
        self.buffer = buffer
        let semitones = Double(midi - buffer.rootMidi)
        let rate = exp2(semitones / 12.0) * buffer.sampleRate / outputSampleRate
        self.rate = rate
        self.gain = gain
        self.startFrame = startFrame
        self.gateFrames = Int((gateDuration * outputSampleRate).rounded())
        self.releaseFrames = Int((release * outputSampleRate).rounded(.up))
        self.attackFrames = Int((0.002 * outputSampleRate).rounded())
        // The voice cannot outlast its source recording (interpolation reads
        // sample i+1, hence count - 1).
        let availableFrames = rate > 0 ? Int(Double(buffer.samples.count - 1) / rate) : 0
        self.endFrame = startFrame + min(gateFrames + releaseFrames, availableFrames)
    }

    public func isActive(in range: Range<Int>) -> Bool {
        startFrame < range.upperBound && endFrame > range.lowerBound
    }

    /// Add this voice's samples into `buffer`, whose first sample sits at
    /// global frame `bufferStart`.
    public func render(into out: UnsafeMutableBufferPointer<Float>, bufferStart: Int) {
        let first = max(startFrame, bufferStart)
        let last = min(endFrame, bufferStart + out.count)
        guard first < last else { return }

        let source = buffer.samples
        let amplitude = Float(gain)
        for globalFrame in first..<last {
            let n = globalFrame - startFrame
            let position = Double(n) * rate
            let index = Int(position)
            guard index + 1 < source.count else { break }
            let fraction = Float(position - Double(index))
            let sample = source[index] + fraction * (source[index + 1] - source[index])

            var envelope: Float = 1
            if n < attackFrames {
                envelope = Float(n) / Float(attackFrames)
            }
            if n >= gateFrames {
                let released = n - gateFrames
                guard released < releaseFrames else { break }
                envelope *= 1 - Float(released) / Float(releaseFrames)
            }
            out[globalFrame - bufferStart] += amplitude * envelope * sample
        }
    }
}

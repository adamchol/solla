#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

/// One sounding note: additive sine partials shaped by an ADSR envelope.
/// Immutable after creation; rendering is a pure function of the global
/// frame position, so it is deterministic and allocation-free.
public struct Voice: Sendable {
    public let frequency: Double
    public let gain: Double
    /// Global frame at which the note starts.
    public let startFrame: Int
    /// Seconds the gate is held open (the note's sounding duration).
    public let gateDuration: Double
    public let timbre: Timbre
    public let envelope: ADSR
    public let sampleRate: Double

    /// Global frame at which the voice is fully silent (gate + release).
    public let endFrame: Int

    public init(
        frequency: Double,
        gain: Double,
        startFrame: Int,
        gateDuration: Double,
        timbre: Timbre,
        envelope: ADSR,
        sampleRate: Double
    ) {
        self.frequency = frequency
        self.gain = gain
        self.startFrame = startFrame
        self.gateDuration = gateDuration
        self.timbre = timbre
        self.envelope = envelope
        self.sampleRate = sampleRate
        self.endFrame = startFrame + Int(((gateDuration + envelope.release) * sampleRate).rounded(.up))
    }

    public func isActive(in range: Range<Int>) -> Bool {
        startFrame < range.upperBound && endFrame > range.lowerBound
    }

    /// Add this voice's samples into `buffer`, whose first sample sits at
    /// global frame `bufferStart`.
    public func render(into buffer: UnsafeMutableBufferPointer<Float>, bufferStart: Int) {
        let normalization = timbre.totalAmplitude
        guard normalization > 0 else { return }
        let twoPiF = 2.0 * Double.pi * frequency

        let first = max(startFrame, bufferStart)
        let last = min(endFrame, bufferStart + buffer.count)
        guard first < last else { return }

        for globalFrame in first..<last {
            let t = Double(globalFrame - startFrame) / sampleRate
            let amp = envelope.amplitude(at: t, gateDuration: gateDuration) * gain
            if amp <= 0 { continue }
            var sample = 0.0
            for (index, harmonic) in timbre.harmonics.enumerated() {
                sample += harmonic * sin(twoPiF * Double(index + 1) * t)
            }
            buffer[globalFrame - bufferStart] += Float(amp * sample / normalization)
        }
    }
}

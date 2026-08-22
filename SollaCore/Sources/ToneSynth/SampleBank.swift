/// One decoded audio recording of a single note.
public struct SampleBuffer: Sendable {
    /// Mono PCM samples (copy-on-write storage is shared across voices).
    public let samples: [Float]
    /// Rate the samples were recorded at (independent of the output rate).
    public let sampleRate: Double
    /// MIDI note the recording sounds at when played unshifted.
    public let rootMidi: Int
    /// The gain this recording naturally represents (its velocity layer);
    /// used both to pick a layer and to scale amplitude toward event gain.
    public let nominalGain: Double

    public init(samples: [Float], sampleRate: Double, rootMidi: Int, nominalGain: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.rootMidi = rootMidi
        self.nominalGain = nominalGain
    }
}

/// The set of sample recordings available to a `SampleSequencer`, with
/// nearest-layer / nearest-root lookup.
public struct SampleBank: Sendable {
    public let buffers: [SampleBuffer]
    /// Note-off release ramp in seconds (from the pack manifest).
    public let release: Double

    public init(buffers: [SampleBuffer], release: Double) {
        self.buffers = buffers
        self.release = release
    }

    /// The best recording for `midi` at `gain`: minimal nominal-gain distance
    /// first (velocity layer), then minimal root distance. Ties resolve to
    /// the earliest buffer, so lookup is deterministic.
    public func buffer(forMidi midi: Int, gain: Double) -> SampleBuffer? {
        var best: SampleBuffer?
        var bestGainDistance = Double.infinity
        var bestMidiDistance = Int.max
        for buffer in buffers {
            let gainDistance = abs(buffer.nominalGain - gain)
            let midiDistance = abs(buffer.rootMidi - midi)
            if gainDistance < bestGainDistance
                || (gainDistance == bestGainDistance && midiDistance < bestMidiDistance)
            {
                best = buffer
                bestGainDistance = gainDistance
                bestMidiDistance = midiDistance
            }
        }
        return best
    }
}

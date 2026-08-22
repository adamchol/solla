import AVFoundation
import Playback
import ToneSynth

/// Owns one sound pack: its parsed manifest and a cache of decoded sample
/// buffers. Decoding happens on the actor, never on the render thread, and
/// only for the files a stimulus actually needs — so even large packs keep a
/// small memory footprint.
actor SamplePackLibrary {
    let manifest: SamplePackManifest
    private let directory: URL
    private var cache: [String: SampleBuffer] = [:]

    init(directory: URL) throws {
        let data = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        self.manifest = try SamplePackManifest.decode(from: data)
        self.directory = directory
    }

    /// A bank containing decoded buffers for every (layer, root) recording
    /// the given events resolve to.
    func bank(covering events: [PlaybackEvent]) throws -> SampleBank {
        var needed: [SamplePackManifest.Sample] = []
        var seenFiles: Set<String> = []
        for event in events {
            for pitch in event.pitches {
                guard let sample = resolve(midi: pitch.midi, gain: event.gain),
                    seenFiles.insert(sample.file).inserted
                else { continue }
                needed.append(sample)
            }
        }

        var buffers: [SampleBuffer] = []
        for sample in needed {
            if cache[sample.file] == nil {
                cache[sample.file] = try decode(sample)
            }
            if let buffer = cache[sample.file] {
                buffers.append(buffer)
            }
        }
        return SampleBank(buffers: buffers, release: manifest.releaseSeconds)
    }

    /// Mirror of `SampleBank`'s nearest-layer / nearest-root selection, done
    /// on manifest metadata so we know which files to decode.
    private func resolve(midi: Int, gain: Double) -> SamplePackManifest.Sample? {
        var best: SamplePackManifest.Sample?
        var bestGainDistance = Double.infinity
        var bestMidiDistance = Int.max
        for sample in manifest.samples {
            guard let nominalGain = manifest.nominalGain(forLayer: sample.layer) else { continue }
            let gainDistance = abs(nominalGain - gain)
            let midiDistance = abs(sample.rootMidi - midi)
            if gainDistance < bestGainDistance
                || (gainDistance == bestGainDistance && midiDistance < bestMidiDistance)
            {
                best = sample
                bestGainDistance = gainDistance
                bestMidiDistance = midiDistance
            }
        }
        return best
    }

    private func decode(_ sample: SamplePackManifest.Sample) throws -> SampleBuffer {
        let url = directory.appendingPathComponent(sample.file)
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: file.processingFormat.sampleRate,
            channels: file.processingFormat.channelCount,
            interleaved: false
        )!
        let frameCount = AVAudioFrameCount(file.length)
        guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try file.read(into: pcm)

        let frames = Int(pcm.frameLength)
        let channels = Int(format.channelCount)
        var samples = [Float](repeating: 0, count: frames)
        if let channelData = pcm.floatChannelData {
            if channels == 1 {
                samples.withUnsafeMutableBufferPointer { output in
                    output.baseAddress!.update(from: channelData[0], count: frames)
                }
            } else {
                // Downmix to mono by averaging channels.
                let scale = 1.0 / Float(channels)
                for frame in 0..<frames {
                    var sum: Float = 0
                    for channel in 0..<channels {
                        sum += channelData[channel][frame]
                    }
                    samples[frame] = sum * scale
                }
            }
        }
        guard let nominalGain = manifest.nominalGain(forLayer: sample.layer) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return SampleBuffer(
            samples: samples,
            sampleRate: format.sampleRate,
            rootMidi: sample.rootMidi,
            nominalGain: nominalGain
        )
    }
}

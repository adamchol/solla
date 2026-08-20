import AVFoundation
import Playback
import ToneSynth

/// AVAudioEngine-backed implementation of the core's `AudioPlaying` boundary.
///
/// An `AVAudioSourceNode` pulls samples from the current `ToneSequencer`
/// (whose render path is allocation-free). `play` swaps in a fresh sequencer
/// and suspends for the audio's duration; `stop` swaps in silence.
final class SynthAudioPlayer: AudioPlaying, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var sequencer: ToneSequencer?
    private var generation = 0
    private let sampleRate: Double

    init() {
        let hardwareRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let rate = hardwareRate > 0 ? hardwareRate : 44_100
        self.sampleRate = rate

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: rate,
            channels: 1,
            interleaved: false
        )!
        let sourceNode = AVAudioSourceNode(format: format) {
            [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let self, let data = buffers[0].mData else { return noErr }
            let samples = data.bindMemory(to: Float.self, capacity: Int(frameCount))
            let buffer = UnsafeMutableBufferPointer(start: samples, count: Int(frameCount))

            self.lock.lock()
            let current = self.sequencer
            self.lock.unlock()

            if let current, !current.isFinished {
                current.render(into: buffer)
            } else {
                for index in buffer.indices {
                    buffer[index] = 0
                }
            }
            return noErr
        }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
    }

    func play(_ events: [PlaybackEvent]) async throws {
        let next = ToneSequencer(events: events, sampleRate: sampleRate)

        lock.lock()
        sequencer = next
        generation += 1
        let myGeneration = generation
        lock.unlock()

        if !engine.isRunning {
            try engine.start()
        }

        do {
            // Duration-based completion: the sequencer's length already
            // includes the final release tail; the margin absorbs clock skew.
            try await Task.sleep(for: .seconds(next.totalDuration + 0.05))
        } catch {
            clear(ifGeneration: myGeneration)
            throw error
        }
        clear(ifGeneration: myGeneration)
    }

    func stop() async {
        lock.lock()
        sequencer = nil
        generation += 1
        lock.unlock()
    }

    /// Detach the sequencer, but only if no newer playback has replaced it.
    private func clear(ifGeneration expected: Int) {
        lock.lock()
        if generation == expected {
            sequencer = nil
        }
        lock.unlock()
    }
}

import Playback
import ToneSynth

/// Synthesized-tone implementation of the core's `AudioPlaying` boundary;
/// the last-resort fallback when no sample pack is usable.
final class SynthAudioPlayer: AudioPlaying, @unchecked Sendable {
    private let engine = RenderEngine()

    func play(_ events: [PlaybackEvent]) async throws {
        try await engine.play(ToneSequencer(events: events, sampleRate: engine.sampleRate))
    }

    func stop() async {
        await engine.stop()
    }
}

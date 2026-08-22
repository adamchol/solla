import Foundation
import Playback
import ToneSynth

/// Sample-pack implementation of the core's `AudioPlaying` boundary: real
/// piano recordings rendered through the shared `RenderEngine`.
final class SampleAudioPlayer: AudioPlaying, @unchecked Sendable {
    private let engine = RenderEngine()
    private let library: SamplePackLibrary

    /// Fails if the pack directory has no readable, valid manifest; callers
    /// fall back to another player.
    init?(packDirectory: URL) {
        guard let library = try? SamplePackLibrary(directory: packDirectory) else {
            return nil
        }
        self.library = library
    }

    func play(_ events: [PlaybackEvent]) async throws {
        let bank = try await library.bank(covering: events)
        let sequencer = SampleSequencer(events: events, bank: bank, sampleRate: engine.sampleRate)
        try await engine.play(sequencer)
    }

    func stop() async {
        await engine.stop()
    }
}

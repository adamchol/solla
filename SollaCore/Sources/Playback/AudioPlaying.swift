/// The core ↔ platform audio boundary.
///
/// `play` suspends until the audio has finished sounding, so callers can
/// sequence stimuli with straight-line async code. Implementations live in
/// the platform layer (AVAudioEngine on iOS); tests use mocks.
public protocol AudioPlaying: Sendable {
    /// Play the events in order; returns when playback (including release tails) is done.
    func play(_ events: [PlaybackEvent]) async throws

    /// Stop any in-flight playback immediately.
    func stop() async
}

/// A silent player that returns immediately. Useful on platforms without
/// audio (Linux) and as a default in previews/tests.
public struct NullAudioPlayer: AudioPlaying {
    public init() {}

    public func play(_ events: [PlaybackEvent]) async throws {}

    public func stop() async {}
}

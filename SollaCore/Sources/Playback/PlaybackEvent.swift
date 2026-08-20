import MusicTheory

/// One sound in a stimulus: a note or chord, followed by optional silence.
public struct PlaybackEvent: Hashable, Sendable {
    /// Pitches sounding simultaneously (1 = note, >1 = chord).
    public let pitches: [Pitch]
    /// Sounding duration in seconds.
    public let duration: Double
    /// Silence after the event before the next one, in seconds.
    public let gapAfter: Double
    /// Linear gain, 0...1, shared across the event's voices.
    public let gain: Double

    public init(pitches: [Pitch], duration: Double, gapAfter: Double = 0, gain: Double = 1) {
        self.pitches = pitches
        self.duration = duration
        self.gapAfter = gapAfter
        self.gain = gain
    }

    /// Total time the event occupies, including the trailing gap.
    public var totalDuration: Double { duration + gapAfter }
}

/// Identifies a replayable part of a round's stimulus.
public enum StimulusID: Hashable, Sendable {
    /// The tonality-establishing chord progression.
    case cadence
    /// The material the user must identify.
    case target
    /// Room for future exercise types.
    case custom(String)
}

/// A named, optionally replayable group of playback events.
public struct StimulusSegment: Hashable, Sendable {
    public let id: StimulusID
    public let events: [PlaybackEvent]
    public let replayable: Bool

    public init(id: StimulusID, events: [PlaybackEvent], replayable: Bool = true) {
        self.id = id
        self.events = events
        self.replayable = replayable
    }

    public var totalDuration: Double {
        events.reduce(0) { $0 + $1.totalDuration }
    }
}

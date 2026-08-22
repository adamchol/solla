import MusicTheory
import Playback

/// Maps a resolution walk (as built by `BenbassatDegreeExercise`) to semitone
/// offsets 0...12 above the tonic of the register it plays in, where 0 is the
/// tonic (Do) and 12 the tonic an octave up. UIs use this to light up the
/// sounding note while the walk plays.
public enum ResolutionWalk {
    public static func offsets(of events: [PlaybackEvent]) -> [Int] {
        guard let first = events.first?.pitches.first,
            let last = events.last?.pitches.first
        else { return [] }

        // The walk always ends on a tonic: itself for a single-note walk,
        // the low tonic when descending, the high tonic when ascending.
        let anchor: Int
        if events.count == 1 {
            anchor = first.midi
        } else if first.midi > last.midi {
            anchor = last.midi
        } else {
            anchor = last.midi - 12
        }

        return events.compactMap { event in
            guard let pitch = event.pitches.first else { return nil }
            return pitch.midi - anchor
        }
    }
}

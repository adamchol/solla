/// A classic attack–decay–sustain–release amplitude envelope.
/// Pure math, evaluated per-sample by `Voice`.
public struct ADSR: Hashable, Sendable {
    /// Seconds from 0 to full level.
    public var attack: Double
    /// Seconds from full level down to `sustain`.
    public var decay: Double
    /// Held level (0...1) while the gate is open.
    public var sustain: Double
    /// Seconds from gate close to silence.
    public var release: Double

    public init(attack: Double = 0.01, decay: Double = 0.08, sustain: Double = 0.7, release: Double = 0.25) {
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
    }

    /// Envelope level while the gate is open, ignoring release.
    private func gateLevel(at t: Double) -> Double {
        if t <= 0 { return 0 }
        if t < attack { return t / attack }
        if t < attack + decay { return 1 - (1 - sustain) * (t - attack) / decay }
        return sustain
    }

    /// Envelope level `t` seconds after note-on, for a gate held open
    /// `gateDuration` seconds. Continuous everywhere, 0 outside
    /// [0, gateDuration + release].
    public func amplitude(at t: Double, gateDuration: Double) -> Double {
        if t <= 0 { return 0 }
        if t < gateDuration { return gateLevel(at: t) }
        let released = t - gateDuration
        if released >= release { return 0 }
        return gateLevel(at: gateDuration) * (1 - released / release)
    }
}

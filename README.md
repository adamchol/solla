# Solla

An ear-training app for musicians building strong relative pitch — named after
the solfège degrees *Sol* and *La*.

The first training mode is **Scale Degrees** (the Benbassat method): each round
establishes a fresh random key with an I–IV–V–I cadence, then plays one
diatonic note. You name its degree using movable-do solfège buttons
(Do Re Mi Fa Sol La Ti). A session is 20 rounds with a per-degree accuracy
summary at the end.

## Architecture

The repo is split so that everything except SwiftUI and AVFoundation plumbing
builds and tests on **Linux**:

```
SollaCore/          SwiftPM package — platform-agnostic, zero dependencies
  MusicTheory       pitches, keys, scale degrees, cadences, chord voicing
  Playback          PlaybackEvent + the AudioPlaying protocol (core ↔ platform boundary)
  ToneSynth         additive synth DSP (ADSR, harmonics, sample-accurate sequencer)
  SollaEngine       generic Exercise protocol + SessionEngine state machine,
                    BenbassatDegreeExercise (the first exercise)
ios/                thin SwiftUI app (iOS 17+), built on a Mac
  project.yml       XcodeGen spec — the .xcodeproj is generated, not checked in
  Solla/            views, @Observable view model, AVAudioEngine synth player
```

New training modes (melody dictation, chord types, …) implement the `Exercise`
protocol in `SollaEngine` and get the session lifecycle, scoring, replay, and
audio scheduling for free; each mode brings its own answer UI and summary.

Audio is fully synthesized in code (no assets): `ToneSynth` renders
harmonics-plus-ADSR tones; on iOS an `AVAudioSourceNode` pulls samples from its
allocation-free render path.

## Developing on Linux (this repo's Nix flake)

```sh
nix develop                              # Swift 5.10 toolchain + corelibs
swift build --package-path SollaCore
swift test  --package-path SollaCore     # full unit-test suite
```

### Linux test-discovery caveat

nixpkgs' Swift toolchain is missing `libIndexStore.so`, which SwiftPM's
automatic test discovery needs. The repo therefore uses an explicit entry
point: `SollaCore/Tests/LinuxMain.swift` plus one `XCTestManifests.swift` per
test target. **When you add a test method, add it to the target's manifest
too** — macOS/Xcode ignores these files and discovers tests natively.

## Building the iOS app (on a Mac)

```sh
brew install xcodegen        # ≥ 2.36
cd ios
xcodegen generate
open Solla.xcodeproj         # or:
xcodebuild -project Solla.xcodeproj -scheme Solla \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Run in the simulator: Home → **Scale Degrees** → listen to the cadence and the
note, answer with the solfège buttons, replay either stimulus any time, and
finish 20 rounds for the summary.

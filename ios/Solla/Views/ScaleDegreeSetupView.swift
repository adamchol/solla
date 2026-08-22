import MusicTheory
import SwiftUI

/// Pre-game options for the Scale Degrees exercise. The last-used values are
/// remembered across sessions.
struct ScaleDegreeSetupView: View {
    @State private var options = ScaleDegreeOptions.loadLastUsed()

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $options.isMinor) {
                    Text("Major").tag(false)
                    Text("Minor").tag(true)
                }
                .pickerStyle(.segmented)

                Picker("Key", selection: $options.tonic) {
                    Text("Random each round").tag(Int?.none)
                    ForEach(0..<12, id: \.self) { value in
                        Text(Key(tonic: PitchClass(value), mode: options.mode).displayName)
                            .tag(Int?.some(value))
                    }
                }

                Stepper(
                    "Rounds: \(options.roundCount)",
                    value: $options.roundCount, in: 5...50, step: 5
                )

                Toggle("Random octaves", isOn: $options.randomOctaves)
            } header: {
                Text("Session")
            } footer: {
                Text("The mystery note lands in a different octave each round.")
            }

            Section {
                DegreeRows(mode: options.mode, visible: Set(0...11), buttonSize: 34) { offset in
                    degreeChip(offset: offset)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } header: {
                Text("Degrees")
            } footer: {
                Text(
                    "Pick which notes can appear — at least two. "
                        + "Chromatic notes sit above the scale."
                )
            }

            Section {
                VStack(alignment: .leading) {
                    LabeledContent("Cadence", value: "\(Int(options.cadenceBpm)) BPM")
                    Slider(value: $options.cadenceBpm, in: 60...240, step: 2)
                }
                VStack(alignment: .leading) {
                    LabeledContent("Note", value: "\(Int(options.noteBpm)) BPM")
                    Slider(value: $options.noteBpm, in: 60...240, step: 2)
                }
            } header: {
                Text("Tempo")
            }

            Section {
                Toggle("Auto-play resolution", isOn: $options.autoPlayResolution)
            } footer: {
                Text(
                    "After you answer, the note walks step by step to the nearest "
                        + "tonic. When off, a Resolution button plays it on demand."
                )
            }

            Section {
                NavigationLink(value: Route.scaleDegreeGame(options)) {
                    Text("Start")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Scale Degrees")
        .onChange(of: options.isMinor) { _, isMinor in
            // The diatonic set differs per mode; reset to the new scale.
            options.enabledDegrees = (isMinor ? Mode.minor : Mode.major).intervals
        }
        .onChange(of: options) { _, newValue in
            newValue.saveAsLastUsed()
        }
    }

    /// One selectable degree in the picker; both Do chips (offsets 0 and 12)
    /// toggle the tonic together.
    private func degreeChip(offset: Int) -> some View {
        let degree = ChromaticDegree(offset)
        let isOn = options.enabledDegrees.contains(degree.semitone)
        return Button {
            toggleDegree(degree.semitone)
        } label: {
            Circle()
                .fill(isOn ? Color.accentColor : Color.accentColor.opacity(0.12))
                .overlay {
                    Text(degree.solfege(in: options.mode))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(isOn ? Color.white : Color.secondary)
                        .padding(2)
                }
        }
        .buttonStyle(.plain)
    }

    private func toggleDegree(_ semitone: Int) {
        if options.enabledDegrees.contains(semitone) {
            // Keep the game meaningful: at least two degrees stay enabled.
            guard options.enabledDegrees.count > 2 else { return }
            options.enabledDegrees.removeAll { $0 == semitone }
        } else {
            options.enabledDegrees.append(semitone)
            options.enabledDegrees.sort()
        }
    }
}

#Preview {
    NavigationStack {
        ScaleDegreeSetupView()
    }
}

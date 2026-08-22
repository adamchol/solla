import MusicTheory
import Playback
import SollaEngine
import SwiftUI

struct GameView: View {
    @State private var model: GameViewModel
    @Environment(\.dismiss) private var dismiss

    private let options: ScaleDegreeOptions

    init(options: ScaleDegreeOptions = .default) {
        self.options = options
        _model = State(initialValue: GameViewModel(options: options))
    }

    var body: some View {
        Group {
            if case .summary = model.state.phase {
                SummaryView(summary: model.summary, mode: currentMode) {
                    dismiss()
                }
            } else {
                gameBody
            }
        }
        .navigationTitle("Scale Degrees")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.tearDown() }
        #if DEBUG
            .task {
                // Test hook: answer automatically after the stimulus so
                // screenshot runs can capture feedback and the resolution
                // walk without driving the UI.
                if let raw = ProcessInfo.processInfo.environment["SOLLA_AUTO_ANSWER"],
                    let offset = Int(raw)
                {
                    try? await Task.sleep(for: .seconds(8))
                    model.tapOffset(offset)
                }
            }
        #endif
    }

    private var gameBody: some View {
        VStack(spacing: 32) {
            header

            keyLabel

            Spacer()

            statusIndicator

            replayButtons

            Spacer()

            scaleRow

            nextButton
        }
        .padding(24)
    }

    private var header: some View {
        HStack {
            Text("Round \(model.state.roundIndex + 1) of \(model.state.roundCount)")
            Spacer()
            Text("Score \(model.state.score)")
                .monospacedDigit()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var keyLabel: some View {
        // The space placeholder keeps the layout stable before round 1.
        Text(model.state.round?.key?.displayName ?? " ")
            .font(.title2.weight(.semibold))
    }

    private var statusIndicator: some View {
        Group {
            switch model.state.phase {
            case .playing:
                Image(systemName: "speaker.wave.2")
                    .symbolEffect(.variableColor.iterative, isActive: true)
                    .foregroundStyle(.secondary)
            case .feedback(let record):
                Image(systemName: record.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(record.isCorrect ? Color.green : Color.red)
            default:
                Color.clear
            }
        }
        .font(.title)
        .frame(height: 36)
        .animation(.default, value: model.state.phase)
    }

    private var replayButtons: some View {
        HStack(spacing: 20) {
            Button {
                model.replayCadence()
            } label: {
                Image(systemName: "music.quarternote.3")
            }
            .accessibilityLabel("Replay cadence")
            .disabled(!canInteract)

            Button {
                model.replayNote()
            } label: {
                Image(systemName: "music.note")
            }
            .accessibilityLabel("Replay note")
            .disabled(!canInteract)

            Button {
                model.playResolution()
            } label: {
                Image(systemName: "arrow.down.right.circle")
            }
            .accessibilityLabel("Play resolution")
            .disabled(!isInFeedback || model.state.isPlayingResolution)
        }
        .font(.title3)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
    }

    /// The enabled degrees a round offers, as semitone offsets.
    private var visibleOffsets: Set<Int> {
        if let roundOptions = model.state.round?.options {
            return Set(roundOptions.map(\.semitone))
        }
        return Set(options.enabledDegrees)
    }

    /// The answer buttons laid out like a keyboard: diatonic degrees (plus
    /// the high Do) below, chromatic degrees above, between their neighbours.
    /// Both Do buttons submit the tonic; either one is a valid answer.
    private var scaleRow: some View {
        DegreeRows(mode: currentMode, visible: visibleOffsets) { offset in
            let degree = ChromaticDegree(offset)
            ScaleNoteButton(
                label: degree.solfege(in: currentMode),
                role: role(at: offset, degree: degree),
                isSounding: model.resolutionHighlight == offset,
                enabled: canAnswer
            ) {
                model.tapOffset(offset)
            }
        }
    }

    @ViewBuilder
    private var nextButton: some View {
        Button {
            model.next()
        } label: {
            Text(isLastRound ? "Finish" : "Next")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .opacity(isInFeedback ? 1 : 0)
        .disabled(!isInFeedback)
    }

    private var currentMode: Mode {
        model.state.round?.key?.mode ?? options.mode
    }

    private var canAnswer: Bool {
        switch model.state.phase {
        case .awaitingAnswer:
            return true
        case .playing(let id):
            // The target note accepts answers while it is still sounding.
            return model.state.round?.segment(id)?.acceptsEarlyAnswer == true
        default:
            return false
        }
    }

    private var isInFeedback: Bool {
        if case .feedback = model.state.phase { return true }
        return false
    }

    private var canInteract: Bool {
        canAnswer || isInFeedback
    }

    private var isLastRound: Bool {
        model.state.roundIndex + 1 >= model.state.roundCount
    }

    private func role(at offset: Int, degree: ChromaticDegree) -> ScaleNoteButton.Role {
        guard case .feedback(let record) = model.state.phase else { return .neutral }
        if degree == record.expected { return .correct }
        if offset == model.lastTappedOffset, !record.isCorrect { return .wrong }
        return .neutral
    }
}

#Preview {
    NavigationStack {
        GameView()
    }
}

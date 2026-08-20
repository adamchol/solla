import MusicTheory
import Playback
import SollaEngine
import SwiftUI

struct GameView: View {
    @State private var model = GameViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if case .summary = model.state.phase {
                SummaryView(summary: model.summary) {
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
    }

    private var gameBody: some View {
        VStack(spacing: 32) {
            header

            Spacer()

            statusLabel

            replayButtons

            Spacer()

            degreeGrid

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

    private var statusLabel: some View {
        Group {
            switch model.state.phase {
            case .playing(.cadence):
                Text("Listen — the key…")
            case .playing:
                Text("…and the note")
            case .awaitingAnswer:
                Text("Which degree was it?")
            case .feedback(let record):
                if record.isCorrect {
                    Text("Correct")
                        .foregroundStyle(.green)
                } else {
                    Text("It was \(record.expected.solfege)")
                        .foregroundStyle(.red)
                }
            default:
                Text(" ")
            }
        }
        .font(.title3.weight(.medium))
        .animation(.default, value: model.state.phase)
    }

    private var replayButtons: some View {
        HStack(spacing: 16) {
            Button {
                model.replayCadence()
            } label: {
                Label("Cadence", systemImage: "arrow.counterclockwise")
            }

            Button {
                model.replayNote()
            } label: {
                Label("Note", systemImage: "arrow.counterclockwise")
            }
        }
        .buttonStyle(.bordered)
        .disabled(!canInteract)
    }

    private var degreeGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 12)], spacing: 12) {
            ForEach(model.state.round?.options ?? ScaleDegree.allCases, id: \.self) { degree in
                DegreeButton(
                    degree: degree,
                    role: buttonRole(for: degree),
                    enabled: canAnswer
                ) {
                    model.tapDegree(degree)
                }
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

    private var canAnswer: Bool {
        if case .awaitingAnswer = model.state.phase { return true }
        return false
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

    private func buttonRole(for degree: ScaleDegree) -> DegreeButton.Role {
        guard case .feedback(let record) = model.state.phase else { return .neutral }
        if degree == record.expected { return .correct }
        if degree == record.given { return .wrong }
        return .neutral
    }
}

#Preview {
    NavigationStack {
        GameView()
    }
}

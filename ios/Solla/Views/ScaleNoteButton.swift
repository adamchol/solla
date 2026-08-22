import SwiftUI

/// One compact circular note button in the scale row (Do … high Do).
struct ScaleNoteButton: View {
    enum Role {
        case neutral
        case correct
        case wrong
    }

    let label: String
    let role: Role
    /// True while this note sounds in the resolution walk.
    let isSounding: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(fill)
                .overlay {
                    Text(label)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(textColor)
                        .padding(2)
                }
                .overlay {
                    if isSounding {
                        Circle().strokeBorder(.primary, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSounding ? 1.18 : 1)
        .animation(.spring(duration: 0.2), value: isSounding)
        .disabled(!enabled && role == .neutral)
    }

    private var fill: Color {
        switch role {
        case .neutral: return Color.accentColor.opacity(0.15)
        case .correct: return .green
        case .wrong: return .red
        }
    }

    private var textColor: Color {
        role == .neutral ? .accentColor : .white
    }
}

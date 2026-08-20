import MusicTheory
import SwiftUI

struct DegreeButton: View {
    enum Role {
        case neutral
        case correct
        case wrong
    }

    let degree: ScaleDegree
    let role: Role
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(degree.solfege)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .disabled(!enabled && role == .neutral)
    }

    private var tint: Color {
        switch role {
        case .neutral: return .accentColor
        case .correct: return .green
        case .wrong: return .red
        }
    }
}

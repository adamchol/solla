import SwiftUI

struct HomeView: View {
    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.scaleDegreeGame) {
                    modeRow(
                        title: "Scale Degrees",
                        subtitle: "Hear a cadence, name the note",
                        systemImage: "music.note"
                    )
                }
            } header: {
                Text("Relative Pitch")
            }

            Section {
                modeRow(
                    title: "Melody Dictation",
                    subtitle: "Coming soon",
                    systemImage: "music.note.list"
                )
                .foregroundStyle(.tertiary)

                modeRow(
                    title: "Chord Types",
                    subtitle: "Coming soon",
                    systemImage: "pianokeys"
                )
                .foregroundStyle(.tertiary)
            } header: {
                Text("More Training")
            }
        }
        .navigationTitle("Solla")
    }

    private func modeRow(title: String, subtitle: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}

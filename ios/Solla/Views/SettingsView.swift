import SwiftUI

struct SettingsView: View {
    @Environment(SoundPackStore.self) private var store

    var body: some View {
        List {
            Section {
                ForEach(SoundPackCatalog.entries) { entry in
                    SoundPackRow(entry: entry)
                }
            } header: {
                Text("Sounds")
            } footer: {
                Text(
                    """
                    Piano samples: Salamander Grand Piano by Alexander Holm, \
                    CC-BY 3.0. Sound changes apply the next time you start an \
                    exercise.
                    """
                )
            }
        }
        .navigationTitle("Settings")
        .onAppear { store.refresh() }
    }
}

private struct SoundPackRow: View {
    let entry: SoundPackCatalogEntry
    @Environment(SoundPackStore.self) private var store

    private var state: SoundPackState {
        store.states[entry.id] ?? .notInstalled
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(isFailed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            }

            Spacer()

            trailingControl
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if store.isSelectable(entry.id) {
                store.select(entry.id)
            }
        }
        .swipeActions {
            if case .installed = state {
                Button("Delete", role: .destructive) {
                    store.delete(entry.id)
                }
            }
        }
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    private var subtitle: String {
        if case .failed(let message) = state {
            return message
        }
        return entry.details
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch state {
        case .bundled, .installed:
            if store.activePackID == entry.id {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
            }
        case .notInstalled:
            Button("Download") {
                store.download(entry)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        case .downloading(let progress):
            HStack(spacing: 12) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 80)
                Button {
                    store.cancelDownload(entry.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        case .failed:
            Button("Retry") {
                store.download(entry)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(SoundPackStore())
    }
}

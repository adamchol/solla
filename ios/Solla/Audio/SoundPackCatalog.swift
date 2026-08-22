import Foundation

/// One pack the app knows how to offer: either bundled or downloadable from
/// a GitHub Release asset.
struct SoundPackCatalogEntry: Identifiable, Sendable {
    /// Matches the pack manifest's `id` and its install directory name.
    let id: String
    let name: String
    /// Short human description shown in Settings ("30 notes · 3 dynamics").
    let details: String
    /// Rough download size, used for progress when the server omits a length.
    let estimatedBytes: Int64
    /// nil for the bundled pack.
    let downloadURL: URL?
    /// Version the catalog expects; an installed older version means an
    /// update is available.
    let version: String
}

enum SoundPackCatalog {
    static let bundledID = "salamander-lite"
    private static let releaseBase: String = {
        #if DEBUG
            // Lets tests point downloads at a local server:
            // SIMCTL_CHILD_SOLLA_PACKS_BASE_URL=http://127.0.0.1:8765 simctl launch …
            if let override = ProcessInfo.processInfo.environment["SOLLA_PACKS_BASE_URL"] {
                return override
            }
        #endif
        return "https://github.com/adamchol/solla/releases/download/sound-packs-v1"
    }()

    static let entries: [SoundPackCatalogEntry] = [
        SoundPackCatalogEntry(
            id: bundledID,
            name: "Piano (built-in)",
            details: "18 notes · 1 dynamic · included",
            estimatedBytes: 1_100_000,
            downloadURL: nil,
            version: "1.0.0"
        ),
        SoundPackCatalogEntry(
            id: "salamander-standard",
            name: "Salamander Standard",
            details: "30 notes · 3 dynamics · ~8 MB",
            estimatedBytes: 7_900_000,
            downloadURL: URL(string: "\(releaseBase)/salamander-standard-1.0.0.zip"),
            version: "1.0.0"
        ),
        SoundPackCatalogEntry(
            id: "salamander-full",
            name: "Salamander Full",
            details: "30 notes · 6 dynamics · ~28 MB",
            estimatedBytes: 29_000_000,
            downloadURL: URL(string: "\(releaseBase)/salamander-full-1.0.0.zip"),
            version: "1.0.0"
        ),
    ]

    static func entry(forID id: String) -> SoundPackCatalogEntry? {
        entries.first { $0.id == id }
    }
}

/// Filesystem locations for sound packs.
enum SoundPackLocator {
    /// The pack shipped inside the app bundle.
    static var bundledDirectory: URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let directory = resources.appendingPathComponent(
            "SoundPacks/\(SoundPackCatalog.bundledID)", isDirectory: true
        )
        let manifest = directory.appendingPathComponent("manifest.json")
        return FileManager.default.fileExists(atPath: manifest.path) ? directory : nil
    }

    /// Root for downloaded packs (created on demand, excluded from backup).
    static func installRoot() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        var root = support.appendingPathComponent("SoundPacks", isDirectory: true)
        if !FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try root.setResourceValues(values)
        }
        return root
    }

    /// The installed directory for a downloaded pack, or nil if absent.
    static func installedDirectory(forPackID id: String) -> URL? {
        guard let root = try? installRoot() else { return nil }
        let directory = root.appendingPathComponent(id, isDirectory: true)
        let manifest = directory.appendingPathComponent("manifest.json")
        return FileManager.default.fileExists(atPath: manifest.path) ? directory : nil
    }

    /// Where the active pack's audio lives right now: an installed download,
    /// the bundled pack for the bundled id.
    static func directory(forPackID id: String) -> URL? {
        if id == SoundPackCatalog.bundledID {
            return bundledDirectory
        }
        return installedDirectory(forPackID: id)
    }
}

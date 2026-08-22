import Foundation
import Observation
import ToneSynth
import ZIPFoundation

enum SoundPackState: Equatable {
    case bundled
    case notInstalled
    case downloading(Double)
    case installed(version: String)
    case failed(String)
}

/// Manages downloadable sound packs: download, verify, install, delete, and
/// the active-pack selection. UI state lives on the main actor; the actual
/// network + file work runs detached.
@MainActor
@Observable
final class SoundPackStore {
    private(set) var states: [String: SoundPackState] = [:]
    private(set) var activePackID: String

    @ObservationIgnored
    private var downloads: [String: Task<Void, Never>] = [:]

    init() {
        activePackID =
            UserDefaults.standard.string(forKey: SettingsKeys.activePackID)
            ?? SoundPackCatalog.bundledID
        refresh()
    }

    /// Re-derive pack states from disk (in-flight downloads keep their state).
    func refresh() {
        for entry in SoundPackCatalog.entries {
            guard entry.downloadURL != nil else {
                states[entry.id] = .bundled
                continue
            }
            if case .downloading = states[entry.id] { continue }
            if let directory = SoundPackLocator.installedDirectory(forPackID: entry.id),
                let data = try? Data(contentsOf: directory.appendingPathComponent("manifest.json")),
                let manifest = try? SamplePackManifest.decode(from: data)
            {
                states[entry.id] = .installed(version: manifest.version)
            } else {
                states[entry.id] = .notInstalled
            }
        }
        if SoundPackLocator.directory(forPackID: activePackID) == nil {
            select(SoundPackCatalog.bundledID)
        }
    }

    /// True when selecting this pack would actually produce its sound.
    func isSelectable(_ id: String) -> Bool {
        SoundPackLocator.directory(forPackID: id) != nil
    }

    func select(_ id: String) {
        guard isSelectable(id) else { return }
        activePackID = id
        UserDefaults.standard.set(id, forKey: SettingsKeys.activePackID)
    }

    func download(_ entry: SoundPackCatalogEntry) {
        guard let url = entry.downloadURL, downloads[entry.id] == nil else { return }
        states[entry.id] = .downloading(0)
        downloads[entry.id] = Task { [weak self] in
            do {
                try await Self.downloadAndInstall(entry: entry, url: url) { progress in
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading = self.states[entry.id] else { return }
                        self.states[entry.id] = .downloading(progress)
                    }
                }
                self?.states[entry.id] = .installed(version: entry.version)
            } catch is CancellationError {
                self?.states[entry.id] = .notInstalled
            } catch {
                self?.states[entry.id] = .failed(error.localizedDescription)
            }
            self?.downloads[entry.id] = nil
        }
    }

    func cancelDownload(_ id: String) {
        downloads[id]?.cancel()
    }

    func delete(_ id: String) {
        guard let directory = SoundPackLocator.installedDirectory(forPackID: id) else { return }
        try? FileManager.default.removeItem(at: directory)
        states[id] = .notInstalled
        if activePackID == id {
            select(SoundPackCatalog.bundledID)
        }
    }

    enum InstallError: LocalizedError {
        case badServerResponse(Int)
        case wrongPack(expected: String, found: String)
        case missingFile(String)

        var errorDescription: String? {
            switch self {
            case .badServerResponse(let code):
                return "Download failed (HTTP \(code))."
            case .wrongPack(let expected, let found):
                return "Downloaded pack “\(found)” doesn't match “\(expected)”."
            case .missingFile(let file):
                return "Pack is missing “\(file)”."
            }
        }
    }

    private nonisolated static func downloadAndInstall(
        entry: SoundPackCatalogEntry,
        url: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let fileManager = FileManager.default
        let temporary = fileManager.temporaryDirectory
        let zipURL = temporary.appendingPathComponent("\(entry.id)-\(UUID().uuidString).zip")
        let stagingURL = temporary.appendingPathComponent(
            "\(entry.id)-staging-\(UUID().uuidString)", isDirectory: true
        )
        defer {
            try? fileManager.removeItem(at: zipURL)
            try? fileManager.removeItem(at: stagingURL)
        }

        // 1. Stream the archive to disk, reporting progress.
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw InstallError.badServerResponse(http.statusCode)
        }
        let expectedLength =
            response.expectedContentLength > 0
            ? response.expectedContentLength : entry.estimatedBytes

        fileManager.createFile(atPath: zipURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: zipURL)
        do {
            var chunk = Data()
            chunk.reserveCapacity(256 * 1024)
            var written: Int64 = 0
            for try await byte in bytes {
                chunk.append(byte)
                if chunk.count >= 256 * 1024 {
                    try handle.write(contentsOf: chunk)
                    written += Int64(chunk.count)
                    chunk.removeAll(keepingCapacity: true)
                    progress(min(0.99, Double(written) / Double(expectedLength)))
                    try Task.checkCancellation()
                }
            }
            if !chunk.isEmpty {
                try handle.write(contentsOf: chunk)
            }
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }

        // 2. Extract and verify before touching the install location.
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: zipURL, to: stagingURL)
        let manifestData = try Data(
            contentsOf: stagingURL.appendingPathComponent("manifest.json")
        )
        let manifest = try SamplePackManifest.decode(from: manifestData)
        guard manifest.id == entry.id else {
            throw InstallError.wrongPack(expected: entry.id, found: manifest.id)
        }
        for sample in manifest.samples {
            let file = stagingURL.appendingPathComponent(sample.file)
            guard fileManager.fileExists(atPath: file.path) else {
                throw InstallError.missingFile(sample.file)
            }
        }

        // 3. Atomic install.
        let installURL = try SoundPackLocator.installRoot()
            .appendingPathComponent(entry.id, isDirectory: true)
        if fileManager.fileExists(atPath: installURL.path) {
            try fileManager.removeItem(at: installURL)
        }
        try fileManager.moveItem(at: stagingURL, to: installURL)
        progress(1)
    }
}

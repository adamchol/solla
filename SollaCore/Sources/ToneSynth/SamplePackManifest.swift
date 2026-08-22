import Foundation

/// Describes a sound pack: a directory of per-note recordings plus this
/// manifest. One format serves both the bundled pack and downloaded packs;
/// decoding lives in the core so it is testable on Linux.
public struct SamplePackManifest: Codable, Equatable, Sendable {
    public struct Attribution: Codable, Equatable, Sendable {
        public let title: String
        public let author: String
        public let license: String
        public let url: String

        public init(title: String, author: String, license: String, url: String) {
            self.title = title
            self.author = author
            self.license = license
            self.url = url
        }
    }

    /// A velocity layer: recordings sharing a dynamic level.
    public struct Layer: Codable, Equatable, Sendable {
        /// Source velocity index (e.g. Salamander's 1...16).
        public let id: Int
        /// The playback gain this layer naturally represents, 0...1.
        public let nominalGain: Double

        public init(id: Int, nominalGain: Double) {
            self.id = id
            self.nominalGain = nominalGain
        }
    }

    public struct Sample: Codable, Equatable, Sendable {
        public let file: String
        public let rootMidi: Int
        public let layer: Int

        public init(file: String, rootMidi: Int, layer: Int) {
            self.file = file
            self.rootMidi = rootMidi
            self.layer = layer
        }
    }

    public static let supportedFormatVersion = 1

    public let formatVersion: Int
    public let id: String
    public let name: String
    public let version: String
    public let instrument: String
    public let sampleRate: Double
    public let channels: Int
    public let releaseSeconds: Double
    public let attribution: Attribution
    public let layers: [Layer]
    public let samples: [Sample]

    public init(
        formatVersion: Int,
        id: String,
        name: String,
        version: String,
        instrument: String,
        sampleRate: Double,
        channels: Int,
        releaseSeconds: Double,
        attribution: Attribution,
        layers: [Layer],
        samples: [Sample]
    ) {
        self.formatVersion = formatVersion
        self.id = id
        self.name = name
        self.version = version
        self.instrument = instrument
        self.sampleRate = sampleRate
        self.channels = channels
        self.releaseSeconds = releaseSeconds
        self.attribution = attribution
        self.layers = layers
        self.samples = samples
    }

    public enum ValidationError: Error, Equatable {
        case unsupportedFormatVersion(Int)
        case noSamples
        case unknownLayer(Int)
    }

    public func validate() throws {
        guard formatVersion == Self.supportedFormatVersion else {
            throw ValidationError.unsupportedFormatVersion(formatVersion)
        }
        guard !samples.isEmpty else {
            throw ValidationError.noSamples
        }
        let layerIDs = Set(layers.map(\.id))
        for sample in samples where !layerIDs.contains(sample.layer) {
            throw ValidationError.unknownLayer(sample.layer)
        }
    }

    public func nominalGain(forLayer id: Int) -> Double? {
        layers.first { $0.id == id }?.nominalGain
    }

    public static func decode(from data: Data) throws -> SamplePackManifest {
        let manifest = try JSONDecoder().decode(SamplePackManifest.self, from: data)
        try manifest.validate()
        return manifest
    }
}

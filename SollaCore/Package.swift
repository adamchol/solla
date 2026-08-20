// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SollaCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MusicTheory", targets: ["MusicTheory"]),
        .library(name: "Playback", targets: ["Playback"]),
        .library(name: "ToneSynth", targets: ["ToneSynth"]),
        .library(name: "SollaEngine", targets: ["SollaEngine"]),
    ],
    targets: [
        .target(name: "MusicTheory"),
        .target(name: "Playback", dependencies: ["MusicTheory"]),
        .target(name: "ToneSynth", dependencies: ["MusicTheory", "Playback"]),
        .target(name: "SollaEngine", dependencies: ["MusicTheory", "Playback"]),
        .testTarget(name: "MusicTheoryTests", dependencies: ["MusicTheory"]),
        .testTarget(name: "ToneSynthTests", dependencies: ["ToneSynth"]),
        .testTarget(name: "SollaEngineTests", dependencies: ["SollaEngine"]),
    ]
)

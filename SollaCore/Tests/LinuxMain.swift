import MusicTheoryTests
import SollaEngineTests
import ToneSynthTests
// Explicit test entry point for Linux, where nixpkgs' Swift toolchain lacks
// libIndexStore.so and SwiftPM cannot auto-discover tests. Each test target
// exports __allTests() from its XCTestManifests.swift.
import XCTest

var tests = [XCTestCaseEntry]()
tests += MusicTheoryTests.__allTests()
tests += SollaEngineTests.__allTests()
tests += ToneSynthTests.__allTests()
XCTMain(tests)

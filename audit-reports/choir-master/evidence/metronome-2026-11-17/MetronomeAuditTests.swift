import XCTest
import AVFoundation
@testable import Choir_Master

@MainActor final class MetronomeAuditTests: XCTestCase {
    private func model() -> ConductorModel {
        ConductorModel(makeAudio: { _ in throw CocoaError(.fileNoSuchFile) }, loadChords: { _ in [] })
    }
    private func preserveDefaults(_ body: () -> Void) {
        let key = Bundle.main.bundleIdentifier!
        let snapshot = UserDefaults.standard.persistentDomain(forName: key) ?? [:]
        defer { UserDefaults.standard.setPersistentDomain(snapshot, forName: key) }
        body()
    }
    func testAllTemposRoundTripBothDirectionsAndExplicitEditResetsReturn() {
        preserveDefaults {
            let state = model()
            defer { state.stopAll() }
            state.meter = 6; state.denominator = 8
            for original in 30...240 {
                for initial in [true, false] {
                    state.compound = initial
                    state.setTempo(original)
                    state.setCompound(!initial)
                    XCTAssertTrue((30...240).contains(state.tempo))
                    state.setCompound(initial)
                    XCTAssertEqual(state.tempo, original, "\(original), dotted=\(initial)")
                }
            }
            state.compound = true; state.setTempo(96); state.setCompound(false)
            XCTAssertEqual(state.tempo, 240)
            state.setTempo(180); state.setCompound(true)
            XCTAssertEqual(state.tempo, 60)
            state.setTempo(Int.max); XCTAssertEqual(state.tempo, 240)
            state.setTempo(Int.min); XCTAssertEqual(state.tempo, 30)
        }
    }
    func testAllNumeratorDenominatorBeatCounts() {
        preserveDefaults {
            let state = model()
            defer { state.stopAll() }
            for numerator in 1...16 {
                for denominator in [1, 2, 4, 8, 16] {
                    state.meter = numerator; state.denominator = denominator
                    state.compound = false
                    XCTAssertEqual(state.beatCount, numerator)
                    state.compound = true
                    let expected = numerator == 6 && denominator == 8 ? 2 : numerator
                    XCTAssertEqual(state.beatCount, expected)
                    XCTAssertFalse(state.beatUnit.isEmpty)
                }
            }
        }
    }
    func testNoOpBoundaryArrowsLoseReturnTempoCharacterization() {
        preserveDefaults {
            let state = model()
            defer { state.stopAll() }
            state.meter = 6; state.denominator = 8; state.compound = true
            state.setTempo(96); state.setCompound(false)
            XCTAssertEqual(state.tempo, 240)
            state.setTempo(state.tempo + 1) // Same call as the visible upper tempo arrow.
            XCTAssertEqual(state.tempo, 240)
            state.setCompound(true)
            XCTAssertEqual(state.tempo, 80) // Reproduces lost 96, not the desired musical result.
            state.compound = false
            state.setTempo(80); state.setCompound(true)
            XCTAssertEqual(state.tempo, 30)
            state.setTempo(state.tempo - 1) // Lower arrow; displayed tempo stays 30.
            XCTAssertEqual(state.tempo, 30)
            state.setCompound(false)
            XCTAssertEqual(state.tempo, 90) // Reproduces lost 80.
        }
    }

    func testLossyRoundTripAcrossReloadCharacterization() {
        preserveDefaults {
            let before = model()
            before.meter = 6; before.denominator = 8; before.compound = true
            before.setTempo(96); before.setCompound(false)
            XCTAssertEqual(before.tempo, 240)
            before.flushSettings()
            let after = model() // Same persisted state as a new launch; no process kill required.
            XCTAssertFalse(after.compound)
            XCTAssertEqual(after.tempo, 240)
            after.setCompound(true)
            // Characterization, not an assertion that 80 is musically desired.
            XCTAssertEqual(after.tempo, 80)
            before.stopAll(); after.stopAll()
        }
    }
}

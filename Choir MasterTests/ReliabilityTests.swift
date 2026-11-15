import XCTest
import AVFoundation
import UIKit
import GoogleMobileAds
@testable import Choir_Master

@MainActor private final class SessionDouble: AudioSessionDriving {
    var category: AVAudioSession.Category = .playback
    var categoryOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]
    var activations: [Bool] = []
    var failActivation = false
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
        self.category = category; categoryOptions = options
    }
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        if active && failActivation { throw CocoaError(.userCancelled) }
        activations.append(active)
    }
    func setPreferredIOBufferDuration(_ duration: TimeInterval) throws {}
}

@MainActor final class ReliabilityTests: XCTestCase {
    func testRecordingAnalysisDecodesFileAndInvalidatesA4Cache() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("tone.wav")
        let rate = 22050
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(rate), channels: 1)!
        do {
            let file = try AVAudioFile(forWriting: source, settings: format.settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(rate * 18))!
            buffer.frameLength = buffer.frameCapacity
            for index in 0..<Int(buffer.frameLength) {
                buffer.floatChannelData![0][index] = Float(0.2 * sin(2 * .pi * 440 * Double(index) / Double(rate)))
            }
            try file.write(from: buffer)
        }
        let store = RecordingAnalysisStore(source: source)
        let first = try store.resolve(a4: 440) { _ in }
        XCTAssertEqual(first.total, 2)
        XCTAssertEqual(first.valid, 2)
        XCTAssertTrue(first.points.compactMap(\.cents).allSatisfy { abs($0) < 1 })
        let reopened = try store.resolve(a4: 440) { _ in }
        XCTAssertEqual(first.points, reopened.points)
        let shifted = try store.resolve(a4: 442) { _ in }
        XCTAssertTrue(shifted.points.compactMap(\.cents).allSatisfy { abs($0 + 7.85) < 1 })
        XCTAssertEqual(shifted.config.a4, 442)
    }

    func testTunerSharesOnlyReferenceOutputAndRestoresPlaybackCategory() throws {
        let driver = SessionDouble()
        let session = AudioSessionCoordinator(driver: driver)
        try session.begin(.recording)
        XCTAssertThrowsError(try session.begin(.tuner))
        session.end(.recording)
        try session.begin(.tuner)
        XCTAssertEqual(driver.category, .playAndRecord)
        XCTAssertThrowsError(try session.begin(.recording))
        try session.begin(.sound)
        XCTAssertEqual(session.clients, [.tuner, .sound])
        XCTAssertFalse(driver.categoryOptions.contains(.allowBluetoothHFP))
        XCTAssertTrue(driver.categoryOptions.contains(.allowBluetoothA2DP))
        session.end(.sound)
        XCTAssertThrowsError(try session.begin(.playback))
        session.end(.tuner)
        XCTAssertEqual(driver.category, .playback)
        XCTAssertTrue(session.clients.isEmpty)
        try session.begin(.sound)
        XCTAssertEqual(session.clients, [.sound])
    }

    func testTunerTargetsAllTemperamentsAndQuarterTones() {
        for temperament in Temperament.allCases {
            for root in 0..<12 {
                for note in 36...84 {
                    let frequency = temperament.frequency(note: Double(note), a4: 442, root: root)
                    let target = TunerPitch(hz: frequency).target(a4: 442, temperament: temperament, root: root, divisions: 12)
                    XCTAssertEqual(target.note, Double(note))
                    XCTAssertEqual(target.cents, 0, accuracy: 0.000001)
                }
            }
        }
        let quarter = TunerPitch(hz: 442 * pow(2, 0.5 / 12)).target(a4: 442, temperament: .equal, root: 0, divisions: 24)
        XCTAssertEqual(quarter.note, 69.5)
        XCTAssertEqual(quarter.cents, 0, accuracy: 0.000001)
    }

    func testCompoundConversionAndHeldChordKeepScreenAwake() {
        let domain = Bundle.main.bundleIdentifier!
        let previous = UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
        let model = ConductorModel()
        defer {
            model.stopAll()
            UserDefaults.standard.setPersistentDomain(previous, forName: domain)
        }
        model.meter = 6; model.denominator = 8
        if !model.compound { model.setCompound(true) }
        model.setTempo(60)
        model.setCompound(false)
        XCTAssertEqual(model.tempo, 180)
        model.setCompound(true)
        XCTAssertEqual(model.tempo, 60)
        let chord = SavedChord(name: "Held", notes: [60, 64, 67], tuning: 442, temperament: .equal, root: 0, divisions: 12)
        XCTAssertTrue(model.playChord(chord))
        XCTAssertTrue(UIApplication.shared.isIdleTimerDisabled)
        model.silencePiano()
        XCTAssertFalse(UIApplication.shared.isIdleTimerDisabled)
    }

    func testAdsCannotManageSessionOrPlayAudio() {
        AdsConsent.configureAudioPolicy()
        XCTAssertTrue(MobileAds.shared.audioVideoManager.isAudioSessionApplicationManaged)
        XCTAssertTrue(MobileAds.shared.isApplicationMuted)
    }

    func testRecordingRestoresPlaybackWithoutRepeatedActivation() throws {
        let driver = SessionDouble()
        let session = AudioSessionCoordinator(driver: driver)
        try session.begin(.sound)
        try session.begin(.sound)
        XCTAssertEqual(driver.activations, [true])
        try session.begin(.recording)
        XCTAssertEqual(driver.category, .playAndRecord)
        session.end(.recording)
        XCTAssertEqual(driver.category, .playback)
        XCTAssertEqual(driver.categoryOptions, [.mixWithOthers])
        XCTAssertEqual(session.clients, [.sound])
        session.end(.sound)
        XCTAssertEqual(driver.activations, [true, false])
    }
    func testInterruptionRequiresExplicitRestart() throws {
        let driver = SessionDouble()
        let session = AudioSessionCoordinator(driver: driver)
        try session.begin(.sound)
        session.interruptionBegan()
        XCTAssertThrowsError(try session.begin(.recording))
        session.interruptionEnded()
        XCTAssertTrue(session.clients.isEmpty)
        XCTAssertEqual(driver.activations, [true])
        try session.begin(.sound)
        XCTAssertEqual(driver.activations, [true, true])
    }
    func testFailedActivationRestoresSessionPolicy() {
        let driver = SessionDouble(); driver.failActivation = true
        let session = AudioSessionCoordinator(driver: driver)
        XCTAssertThrowsError(try session.begin(.recording))
        XCTAssertTrue(session.clients.isEmpty)
        XCTAssertEqual(driver.category, .playback)
    }
    func testCorruptChordsCannotBeOverwritten() throws {
        let suite = "ChoirRecoveryTest-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupt = Data("broken json".utf8)
        defaults.set(corrupt, forKey: ChordStore.key)
        XCTAssertThrowsError(try ChordStore.load(from: defaults))
        XCTAssertThrowsError(try ChordStore.save([], to: defaults))
        XCTAssertEqual(defaults.data(forKey: ChordStore.key), corrupt)
        XCTAssertEqual(defaults.data(forKey: ChordStore.key + ".unreadableBackup"), corrupt)
    }
    func testOldRecorderErrorIsIgnored() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = RecordingManager(session: AudioSessionCoordinator(driver: SessionDouble()), directory: directory)
        while manager.loading { try await Task.sleep(for: .milliseconds(10)) }
        let oldRecorder = try AVAudioRecorder(url: directory.appendingPathComponent("old.m4a"), settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
        manager.audioRecorderEncodeErrorDidOccur(oldRecorder, error: CocoaError(.fileWriteUnknown))
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertNil(manager.error)
        XCTAssertFalse(manager.recording)
    }
    func testHistoricalPitchSpellingFollowsFifthChain() {
        let c = NoteNaming.pitchClasses(international: true, temperament: .quarterComma, root: 0)
        XCTAssertEqual(c[8], "G♯")
        XCTAssertEqual(c[3], "E♭")
        let f = NoteNaming.pitchClasses(international: true, temperament: .quarterComma, root: 5)
        XCTAssertEqual(f[8], "A♭")
        XCTAssertEqual(f[1], "C♯")
        let d = NoteNaming.pitchClasses(international: false, temperament: .pythagorean, root: 2)
        XCTAssertEqual(d[10], "A♯")
        let natural = NoteNaming.pitchClasses(international: true, temperament: .just, root: 0)
        XCTAssertEqual(natural[8], "A♭")
        XCTAssertEqual(natural[1], "D♭")
    }
    func testMailboxRetainsChordAndReleaseAcrossVolumeUpdates() {
        let renderer = AudioRenderer()
        renderer.samples = Array(repeating: Array(repeating: Float(0.25), count: 44100), count: 25)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        renderer.configure(tempo: 80, beats: 4, piano: 0.7, click: 0, pitches: Array(repeating: 1, count: 97))
        renderer.startNotes([60, 64, 67])
        renderer.render(512, buffer.mutableAudioBufferList)
        XCTAssertGreaterThan(buffer.floatChannelData![0][511], 0)
        renderer.configure(tempo: 90, beats: 4, piano: 0.8, click: 0, pitches: nil)
        renderer.render(512, buffer.mutableAudioBufferList)
        XCTAssertEqual(renderer.voices.filter(\.held).count, 3)
        for note in [60.0, 64, 67] { renderer.releaseNote(note) }
        for _ in 0..<24 { renderer.render(512, buffer.mutableAudioBufferList) }
        XCTAssertLessThan(abs(buffer.floatChannelData![0][511]), 0.00001)
    }
    func testAudioRenderingDuringConcurrentControlUpdates() {
        let renderer = AudioRenderer()
        renderer.samples = Array(repeating: Array(repeating: Float(0.25), count: 44100), count: 25)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        let producer = DispatchGroup()
        producer.enter()
        DispatchQueue.global().async {
            for i in 0..<3000 {
                renderer.configure(tempo: Double(80 + i % 100), beats: 4, piano: 0.7, click: 0.6, pitches: nil)
                renderer.startNotes([60, 64, 67]); renderer.releaseNote(64)
            }
            producer.leave()
        }
        for _ in 0..<300 {
            renderer.render(512, buffer.mutableAudioBufferList)
            for frame in 0..<512 { XCTAssertTrue(buffer.floatChannelData![0][frame].isFinite) }
        }
        XCTAssertEqual(producer.wait(timeout: .now() + 5), .success)
        renderer.clear(); renderer.render(512, buffer.mutableAudioBufferList)
        XCTAssertTrue((0..<512).allSatisfy { buffer.floatChannelData![0][$0] == 0 })
    }
    func testPackagedSampleMetadataMatchesFiles() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "metadata", withExtension: "json", subdirectory: "PianoSamples") ?? Bundle.main.url(forResource: "metadata", withExtension: "json"))
        let items = try PianoSampleMetadata.load(from: url)
        for item in items {
            let sampleURL = try XCTUnwrap(Bundle.main.url(forResource: "note_\(item.midi)", withExtension: "wav", subdirectory: "PianoSamples") ?? Bundle.main.url(forResource: "note_\(item.midi)", withExtension: "wav"))
            let file = try AVAudioFile(forReading: sampleURL)
            XCTAssertEqual(Int(file.length), item.frames)
            XCTAssertEqual(file.processingFormat.sampleRate, Double(item.sampleRate))
            XCTAssertEqual(Int(file.processingFormat.channelCount), item.channels)
        }
    }
    func testMissingSoundFontStillProducesPreciseTone() async throws {
        let engine = AVAudioEngine()
        let tone = try ReferenceTone(engine: engine, soundFontURL: URL(fileURLWithPath: "/missing-font.sf2"))
        XCTAssertFalse(tone.soundFontAvailable)
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
        try engine.start()
        defer { engine.stop() }
        tone.configure(tuning: 442, volume: 0.7, sound: .soundFont)
        tone.play(69)
        try await Task.sleep(nanoseconds: 70_000_000)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
        var peak: Float = 0
        for _ in 0..<10 {
            XCTAssertEqual(try engine.renderOffline(512, to: buffer), .success)
            for frame in 0..<512 { peak = max(peak, abs(buffer.floatChannelData![0][frame])) }
        }
        XCTAssertGreaterThan(peak, 0.001)
    }

    func testWrongTypeChordStoreIsAlsoPreserved() {
        let suite = "ChoirRecoveryTest-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("unexpected string", forKey: ChordStore.key)
        XCTAssertThrowsError(try ChordStore.save([], to: defaults))
        XCTAssertEqual(defaults.string(forKey: ChordStore.key), "unexpected string")
        XCTAssertEqual(defaults.string(forKey: ChordStore.key + ".unreadableBackup"), "unexpected string")
    }
    func testQuarterToneKeyTargetsAndAccessibilityActivation() throws {
        let scroll = KeyboardScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 160))
        scroll.configure(start: 48, sounding: [], names: NoteNaming.pitchClasses(international: false), divisions: 24)
        scroll.layoutIfNeeded(); scroll.keyboard.layoutIfNeeded()
        let elements = try XCTUnwrap(scroll.keyboard.accessibilityElements as? [UIAccessibilityElement])
        XCTAssertEqual(elements.count, 49)
        for key in elements where key.accessibilityFrameInContainerSpace.height < 150 {
            XCTAssertGreaterThanOrEqual(key.accessibilityFrameInContainerSpace.width, 44 - 0.001)
        }
        var played: [Double] = []
        scroll.keyboard.down = { played.append($0) }
        XCTAssertTrue(elements[0].accessibilityActivate())
        XCTAssertEqual(played, [48])
        XCTAssertTrue(scroll.keyboard.accessibilityScroll(.left))
        XCTAssertGreaterThan(scroll.contentOffset.x, 0)
    }

}

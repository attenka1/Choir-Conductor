import SwiftUI
import Combine
import AVFoundation

enum SoundMode: String, CaseIterable {
    case piano, reference
    var title: String { self == .piano ? T("Piano") : T("Viritysääni") }
}

@MainActor final class ConductorModel: ObservableObject {
    let recordings = RecordingManager()
    @Published var tempo: Int { didSet { save(); configure() } }
    @Published var meter: Int { didSet { save(); resetMeter() } }
    @Published var denominator: Int { didSet { save(); resetMeter() } }
    @Published var compound: Bool { didSet { save(); resetMeter() } }
    @Published var tuning: Double { didSet { save(); configure() } }
    @Published var pianoVolume: Double { didSet { save(); configure() } }
    @Published var clickVolume: Double { didSet { save(); configure() } }
    @Published var international: Bool { didSet { save() } }
    @Published var divisions: Int { didSet {
        silencePiano()
        if divisions == 24 && temperament != .equal { temperament = .equal }
        save(); configure()
    } }
    @Published var temperament: Temperament { didSet {
        silencePiano()
        if temperament != .equal && divisions == 24 { divisions = 12 }
        save(); configure()
    } }
    @Published var tuningRoot: Int { didSet { silencePiano(); save(); configure() } }
    var rootNames: [String] { international ? ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "G♯", "A", "B♭", "B"] : ["C", "C♯", "D", "Es", "E", "F", "Fis", "G", "Gis", "A", "B", "H"] }
    var tuningLabel: String { tuning.formatted(.number.precision(.fractionLength(0...2))) }
    var tuningSummary: String { "A4 = \(tuningLabel) Hz · " + (temperament == .equal ? T("%@ säv.", String(divisions)) : "\(temperament.title) · \(rootNames[tuningRoot])") }
    @Published var referenceSound: ReferenceSound { didSet { silencePiano(); save(); configure() } }
    @Published var soundMode: SoundMode = .piano { didSet { silencePiano() } }
    @Published var running = false
    @Published var beat = -1
    @Published var sustain = false { didSet { if !sustain { releaseUnpressed() } } }
    @Published var sounding: Set<Double> = []
    @Published var octave = 3
    @Published var error: String?
    @Published private(set) var savedChords: [SavedChord] = []
    private var pressed: Set<Double> = []
    private var audio: ChoirAudio?
    private var subscriptions: Set<AnyCancellable> = []
    var isSixEight: Bool { meter == 6 && denominator == 8 }
    var beatCount: Int { isSixEight && compound ? 2 : meter }
    var beatUnit: String {
        if isSixEight && compound { return T("BPM = pisteellinen neljäsosa ♩.") }
        switch denominator {
        case 16: return T("BPM = kuudestoistaosa ♬")
        case 8: return T("BPM = kahdeksasosa ♪")
        case 2: return T("BPM = puolinuotti 𝅗𝅥")
        case 1: return T("BPM = kokonuotti 𝅝")
        default: return T("BPM = neljäsosa ♩")
        }
    }
    init() {
        let d = UserDefaults.standard
        referenceSound = ReferenceSound(rawValue: d.string(forKey: "referenceSound") ?? "precise") ?? .precise
        tempo = min(240, max(30, d.object(forKey: "tempo") as? Int ?? 80))
        let savedMeter = d.integer(forKey: "meter")
        meter = (1...16).contains(savedMeter) ? savedMeter : 4
        let savedDenominator = d.object(forKey: "denominator") as? Int
        denominator = savedDenominator.flatMap { [16,8,4,2,1].contains($0) ? $0 : nil } ?? (savedMeter == 6 ? 8 : 4)
        compound = d.object(forKey: "compound") as? Bool ?? true
        let savedTuning = (d.object(forKey: "tuning") as? NSNumber)?.doubleValue ?? 442
        tuning = savedTuning.isFinite && (300...500).contains(savedTuning) ? savedTuning : 442
        let savedTemperament = Temperament(rawValue: d.string(forKey: "temperament") ?? "equal") ?? .equal
        temperament = savedTemperament
        tuningRoot = min(11, max(0, d.integer(forKey: "tuningRoot")))
        divisions = d.integer(forKey: "divisions") == 24 && savedTemperament == .equal ? 24 : 12
        pianoVolume = min(1, max(0, d.object(forKey: "pianoVolume") as? Double ?? 0.7))
        clickVolume = min(1, max(0, d.object(forKey: "clickVolume") as? Double ?? 0.6))
        international = d.bool(forKey: "international")
        do { audio = try ChoirAudio(); configure() } catch { self.error = error.localizedDescription }
        do { savedChords = try ChordStore.load(from: d) } catch { self.error = T("Tallennettuja sointuja ei voitu lukea: ") + error.localizedDescription }
        recordings.prepareSession = { [weak self] in self?.stopSound() }
        Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, let audio = self.audio else { return }
            audio.renderer.update { self.beat = $0.beat }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification).sink { [weak self] _ in
            Task { @MainActor in self?.stopAll() }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).sink { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { Task { @MainActor in self?.stopAll() } }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange).sink { [weak self] _ in
            Task { @MainActor in self?.recoverAudioConfiguration() }
        }.store(in: &subscriptions)
    }
    private func save() {
        let d = UserDefaults.standard
        d.set(tempo, forKey: "tempo"); d.set(meter, forKey: "meter"); d.set(denominator, forKey: "denominator"); d.set(compound, forKey: "compound")
        d.set(referenceSound.rawValue, forKey: "referenceSound")
        d.set(temperament.rawValue, forKey: "temperament"); d.set(tuningRoot, forKey: "tuningRoot")
        d.set(divisions, forKey: "divisions"); d.set(tuning, forKey: "tuning"); d.set(pianoVolume, forKey: "pianoVolume"); d.set(clickVolume, forKey: "clickVolume"); d.set(international, forKey: "international")
    }
    private func configure() {
        audio?.reference.configure(tuning: tuning, volume: pianoVolume, temperament: temperament, root: tuningRoot, sound: referenceSound)
        audio?.renderer.update { $0.tempo = Double(tempo); $0.beats = beatCount; $0.tuning = Double(tuning); $0.pianoVolume = Float(pianoVolume); $0.clickVolume = Float(clickVolume)
            for index in 0..<97 {
                let note = Double(index) / 2 + 36
                let source = min(79, max(55, Int(note.rounded())))
                $0.steps[index] = temperament.frequency(note: note, a4: tuning, root: tuningRoot) / $0.frequencies[source - 55]
            }
        }
    }
    private func resetMeter() { configure(); audio?.renderer.update { $0.beat = -1; $0.remaining = 0 }; beat = -1 }
    func setTempo(_ value: Int) { tempo = min(240, max(30, value)) }
    private func recoverAudioConfiguration() {
        // Starting microphone recording can change the hardware format. Resume the
        // existing renderer state instead of cancelling a running metronome.
        guard running || !sounding.isEmpty else { return }
        _ = ensureAudio()
    }
    private func ensureAudio() -> Bool {
        guard let audio else { return false }
        do { try audio.start(); return true } catch { self.error = error.localizedDescription; stopAll(); return false }
    }
    func toggleMetronome() {
        if !running && !ensureAudio() { return }
        running.toggle()
        audio?.renderer.update { $0.running = running; $0.beat = -1; $0.remaining = 0; $0.clickAge = 10000 }
        beat = -1
        UIApplication.shared.isIdleTimerDisabled = running
    }
    func noteDown(_ note: Double) {
        guard note.isFinite, (36...84).contains(note), note * 2 == (note * 2).rounded(), ensureAudio() else { return }
        if soundMode == .reference {
            sounding = [note]
            audio?.reference.play(note)
            return
        }
        pressed.insert(note)
        if sustain && sounding.contains(note) { release(note); return }
        sounding.insert(note)
        audio?.renderer.update { $0.voices[Int((note - 36) * 2)].held = true; $0.voices[Int((note - 36) * 2)].position = 0; $0.voices[Int((note - 36) * 2)].gain = 0 }
    }
    func noteUp(_ note: Double) { if soundMode == .reference { return }; pressed.remove(note); if !sustain { release(note) } }
    func noteCancelled(_ note: Double) {
        if soundMode == .reference { if sounding.contains(note) { silencePiano() }; return }
        pressed.remove(note); release(note)
    }
    private func release(_ note: Double) { sounding.remove(note); audio?.renderer.update { $0.voices[Int((note - 36) * 2)].held = false } }
    private func releaseUnpressed() { guard soundMode == .piano else { return }; for note in sounding.subtracting(pressed) { release(note) } }
    func silencePiano() {
        audio?.reference.stop()
        pressed.removeAll()
        for note in sounding { release(note) }
    }
    func prepareChordSelection() {
        soundMode = .piano
        silencePiano()
        sustain = true
    }
    func noteLabel(_ note: Double) -> String {
        let midi = Int(note.rounded(.down))
        return rootNames[midi % 12] + String(midi / 12 - 1) + (note != Double(midi) ? "↑" : "")
    }
    @discardableResult func saveCurrentChord(name: String) -> Bool {
        guard soundMode == .piano, !sounding.isEmpty else { return false }
        let chord = SavedChord(name: name.trimmingCharacters(in: .whitespacesAndNewlines), notes: sounding.sorted(), tuning: tuning, temperament: temperament, root: tuningRoot, divisions: divisions)
        return updateChords(savedChords + [chord])
    }
    @discardableResult private func updateChords(_ chords: [SavedChord]) -> Bool {
        do { try ChordStore.save(chords, to: .standard); savedChords = chords; return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func renameChord(_ chord: SavedChord, to name: String) {
        var chords = savedChords
        guard let index = chords.firstIndex(where: { $0.id == chord.id }) else { return }
        chords[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updateChords(chords)
    }
    func deleteChord(_ chord: SavedChord) { updateChords(savedChords.filter { $0.id != chord.id }) }
    @discardableResult func playChord(_ chord: SavedChord) -> Bool {
        guard chord.isValid else { return false }
        silencePiano()
        soundMode = .piano
        divisions = chord.divisions
        temperament = chord.temperament
        tuningRoot = chord.root
        tuning = chord.tuning
        sustain = true
        guard ensureAudio() else { return false }
        sounding = Set(chord.notes)
        // Start every voice in the same audio-buffer boundary, without per-key engine starts.
        audio?.renderer.update { state in
            for note in chord.notes {
                let index = Int((note - 36) * 2)
                state.voices[index].held = true
                state.voices[index].position = 0
                state.voices[index].gain = 0
            }
        }
        octave = min(4, max(2, Int(chord.notes.min()! / 12) - 1))
        return true
    }
    func stopSound() { running = false; beat = -1; pressed.removeAll(); sounding.removeAll(); audio?.silence(deactivateSession: !recordings.recording); UIApplication.shared.isIdleTimerDisabled = false }
    func stopAll() { recordings.stopAll(); stopSound() }
}

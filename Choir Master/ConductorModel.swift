import SwiftUI
import Combine
import AVFoundation

enum SoundMode: String, CaseIterable {
    case piano, reference
    var title: String { self == .piano ? T("Piano") : T("Viritysääni") }
}

@MainActor final class ConductorModel: ObservableObject {
    // Audio is stopped explicitly; avoid nested isolated-deinit back-deployment on iOS 18.5.
    nonisolated deinit {}
    let recordings: RecordingManager
    let tuner: LiveTuner
    private let session: AudioSessionCoordinator
    private var beatUpdates: AnyCancellable?
    private var idleStop: Task<Void, Never>?
    private var applyingProfile = false
    private var pendingSettingsSave: Task<Void, Never>?
    private struct PitchProfile: Equatable { let tuning: Double; let temperament: Temperament; let root: Int }
    private var appliedPitch: PitchProfile?
    @Published var tempo: Int { didSet { guard !applyingProfile else { return }; save(); configure() } }
    @Published var meter: Int { didSet { guard !applyingProfile else { return }; save(); resetMeter() } }
    @Published var denominator: Int { didSet { guard !applyingProfile else { return }; save(); resetMeter() } }
    @Published var compound: Bool { didSet { guard !applyingProfile else { return }; save(); resetMeter() } }
    @Published var tuning: Double { didSet { guard !applyingProfile else { return }; save(); configure() } }
    @Published var pianoVolume: Double { didSet { guard !applyingProfile else { return }; scheduleSettingsSave(); configure() } }
    @Published var clickVolume: Double { didSet { guard !applyingProfile else { return }; scheduleSettingsSave(); configure() } }
    @Published var international: Bool { didSet { guard !applyingProfile else { return }; save() } }
    @Published var divisions: Int { didSet { guard !applyingProfile else { return };
        silencePiano()
        if divisions == 24 && temperament != .equal { temperament = .equal }
        save(); configure()
    } }
    @Published var temperament: Temperament { didSet { guard !applyingProfile else { return };
        silencePiano()
        if temperament != .equal && divisions == 24 { divisions = 12 }
        save(); configure()
    } }
    @Published var tuningRoot: Int { didSet { guard !applyingProfile else { return }; silencePiano(); save(); configure() } }
    var rootNames: [String] { NoteNaming.pitchClasses(international: international) }
    var keyNames: [String] { NoteNaming.pitchClasses(international: international, temperament: temperament, root: tuningRoot) }
    var tuningLabel: String { tuning.formatted(.number.precision(.fractionLength(0...2))) }
    var tuningSummary: String { "A4 = \(tuningLabel) Hz · " + (temperament == .equal ? T("%@ säv.", String(divisions)) : "\(temperament.title) · \(rootNames[tuningRoot])") }
    @Published var referenceSound: ReferenceSound { didSet { guard !applyingProfile else { return }; silencePiano(); save(); configure() } }
    @Published var soundMode: SoundMode = .piano { didSet { guard !applyingProfile else { return }; silencePiano() } }
    @Published var running = false
    @Published var beat = -1
    @Published var sustain = false { didSet { guard !applyingProfile else { return }; if !sustain { releaseUnpressed() } } }
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
        let coordinator = AudioSessionCoordinator()
        session = coordinator
        recordings = RecordingManager(session: coordinator)
        tuner = LiveTuner(session: coordinator)
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
        do { audio = try ChoirAudio(session: coordinator); configure() } catch { self.error = error.localizedDescription }
        do { savedChords = try ChordStore.load(from: d) } catch { self.error = T("Tallennettuja sointuja ei voitu lukea: ") + error.localizedDescription }
        recordings.$requestingPermission.removeDuplicates().sink { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }.store(in: &subscriptions)
        tuner.$active.removeDuplicates().sink { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }.store(in: &subscriptions)
        coordinator.onChange = { [weak self] in
            self?.refreshIdleTimer()
            self?.objectWillChange.send()
        }
        coordinator.onError = { [weak self] in self?.error = $0.localizedDescription }
        recordings.prepareSession = { [weak self] in self?.stopSound() }
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification).sink { [weak self] notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                guard let self else { return }
                if raw == AVAudioSession.InterruptionType.began.rawValue {
                    self.session.interruptionBegan(); self.stopAll()
                } else if raw == AVAudioSession.InterruptionType.ended.rawValue {
                    self.session.interruptionEnded()
                }
            }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).sink { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { Task { @MainActor in self?.stopAll() } }
        }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange, object: audio?.engine).sink { [weak self] _ in
            Task { @MainActor in self?.recoverAudioConfiguration() }
        }.store(in: &subscriptions)
    }
    private func scheduleSettingsSave() {
        pendingSettingsSave?.cancel()
        pendingSettingsSave = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            self?.save()
        }
    }
    func flushSettings() { save() }
    private func save() {
        pendingSettingsSave?.cancel()
        pendingSettingsSave = nil
        let d = UserDefaults.standard
        d.set(tempo, forKey: "tempo"); d.set(meter, forKey: "meter"); d.set(denominator, forKey: "denominator"); d.set(compound, forKey: "compound")
        d.set(referenceSound.rawValue, forKey: "referenceSound")
        d.set(temperament.rawValue, forKey: "temperament"); d.set(tuningRoot, forKey: "tuningRoot")
        d.set(divisions, forKey: "divisions"); d.set(tuning, forKey: "tuning"); d.set(pianoVolume, forKey: "pianoVolume"); d.set(clickVolume, forKey: "clickVolume"); d.set(international, forKey: "international")
    }
    private func configure() {
        if referenceSound == .soundFont, let audio, !audio.reference.soundFontAvailable {
            referenceSound = .precise
            error = T("Viritysäänen SoundFont puuttuu.")
            return
        }
        audio?.reference.configure(tuning: tuning, volume: pianoVolume, temperament: temperament, root: tuningRoot, sound: referenceSound)
        guard let audio else { return }
        let profile = PitchProfile(tuning: tuning, temperament: temperament, root: tuningRoot)
        var pitches: [Double]?
        if profile != appliedPitch {
            // Expensive frequency calculations happen outside the control mailbox.
            pitches = (0..<97).map { index in
                let note = Double(index) / 2 + 36
                let source = min(79, max(55, Int(note.rounded())))
                return temperament.frequency(note: note, a4: tuning, root: tuningRoot) / audio.renderer.frequencies[source - 55]
            }
            appliedPitch = profile
        }
        audio.renderer.configure(tempo: Double(tempo), beats: beatCount, piano: Float(pianoVolume), click: Float(clickVolume), pitches: pitches)
    }
    private func resetMeter() { configure(); audio?.renderer.setMetronome(running: running, reset: true); beat = -1 }
    func setTempo(_ value: Int) { tempo = min(240, max(30, value)) }
    private func recoverAudioConfiguration() {
        // Starting microphone recording can change the hardware format. Resume the
        // existing renderer state instead of cancelling a running metronome.
        guard running || !sounding.isEmpty else { return }
        _ = ensureAudio()
    }
    private func ensureAudio() -> Bool {
        idleStop?.cancel(); idleStop = nil
        guard let audio else { return false }
        do { try audio.start(); return true } catch { self.error = error.localizedDescription; stopSound(); return false }
    }
    func toggleMetronome() {
        if !running && !ensureAudio() { return }
        running.toggle()
        audio?.renderer.setMetronome(running: running, reset: true)
        beat = -1
        updateBeatTracking(); refreshIdleTimer(); scheduleIdleStop()
    }
    func noteDown(_ note: Double) {
        guard note.isFinite, (36...84).contains(note), note * 2 == (note * 2).rounded(), ensureAudio() else { return }
        if soundMode == .reference {
            sounding = [note]
            audio?.reference.play(note)
            refreshIdleTimer()
            return
        }
        pressed.insert(note)
        if sustain && sounding.contains(note) { release(note); return }
        sounding.insert(note)
        audio?.renderer.startNotes([note])
        refreshIdleTimer()
    }
    func noteUp(_ note: Double) { if soundMode == .reference { return }; pressed.remove(note); if !sustain { release(note) } }
    func noteCancelled(_ note: Double) {
        if soundMode == .reference { if sounding.contains(note) { silencePiano() }; return }
        pressed.remove(note); release(note)
    }
    private func release(_ note: Double) { sounding.remove(note); audio?.renderer.releaseNote(note); refreshIdleTimer(); scheduleIdleStop() }
    private func releaseUnpressed() { guard soundMode == .piano else { return }; for note in sounding.subtracting(pressed) { release(note) } }
    func silencePiano() {
        audio?.reference.stop()
        pressed.removeAll()
        for note in sounding { release(note) }
        refreshIdleTimer(); scheduleIdleStop()
    }
    func prepareChordSelection() {
        soundMode = .piano
        silencePiano()
        sustain = true
    }
    func noteLabel(_ note: Double) -> String {
        NoteNaming.label(note, names: keyNames)
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
        // Audio preparation is the only fallible step; do it before committing settings.
        guard chord.isValid, ensureAudio() else { return false }
        silencePiano()
        idleStop?.cancel(); idleStop = nil
        applyingProfile = true
        soundMode = .piano
        divisions = chord.divisions
        temperament = chord.temperament
        tuningRoot = chord.root
        tuning = chord.tuning
        sustain = true
        applyingProfile = false
        save(); configure()
        sounding = Set(chord.notes)
        // Start every voice in the same audio-buffer boundary, without per-key engine starts.
        audio?.renderer.startNotes(chord.notes)
        octave = min(4, max(2, Int(chord.notes.min()! / 12) - 1))
        refreshIdleTimer()
        return true
    }
    private func updateBeatTracking() {
        beatUpdates?.cancel(); beatUpdates = nil
        guard running else { return }
        beatUpdates = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, let audio = self.audio else { return }
            let next = audio.renderer.currentBeat
            if self.beat != next { self.beat = next }
        }
    }
    private func refreshIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = running || session.clients.contains(.recording) || session.clients.contains(.tuner) || !sounding.isEmpty
    }
    private func scheduleIdleStop() {
        guard !running, sounding.isEmpty else { return }
        idleStop?.cancel()
        idleStop = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
            guard let self, !self.running, self.sounding.isEmpty else { return }
            self.audio?.silence(); self.idleStop = nil
        }
    }
    func stopSound() {
        idleStop?.cancel(); idleStop = nil
        running = false; beat = -1; pressed.removeAll(); sounding.removeAll()
        audio?.silence(); updateBeatTracking(); refreshIdleTimer()
    }
    func prepareTuner() -> Bool {
        guard !recordings.recording, !recordings.requestingPermission else { return false }
        recordings.stopPlayback()
        stopSound()
        return true
    }
    var audioBusy: Bool {
        !session.clients.isEmpty || running || !sounding.isEmpty ||
            recordings.requestingPermission || tuner.active
    }
    func playTunerReference(_ note: Double) {
        guard tuner.active else { return }
        soundMode = .reference
        noteDown(note)
    }
    func setCompound(_ value: Bool) {
        guard value != compound else { return }
        // Preserve bar duration while changing the beat unit; the supported BPM range still applies.
        applyingProfile = true
        tempo = min(240, max(30, value ? Int((Double(tempo) / 3).rounded()) : tempo * 3))
        compound = value
        applyingProfile = false
        save(); resetMeter()
    }
    func stopAll() {
        tuner.stop()
        recordings.stopAll()
        stopSound()
    }
}

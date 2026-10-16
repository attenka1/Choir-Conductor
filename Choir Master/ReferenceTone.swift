import AVFoundation

enum ReferenceSound: String, CaseIterable {
    case precise, soundFont
    var title: String { self == .precise ? T("Tarkka viritysääni") : T("SoundFont-urut") }
}

/// Reference playback shares the existing engine; its gain envelope is independent of the metronome.
@MainActor final class ReferenceTone {
    private(set) var soundFontAvailable = false
    private let sampler = AVAudioUnitSampler()
    private let mixer = AVAudioMixerNode()
    private let oscillator = ReferenceOscillator()
    private var source: AVAudioSourceNode?
    private var sound: ReferenceSound = .precise
    private var tuning = 442.0
    private var transition: Task<Void, Never>?
    private var currentNote: Double?
    private var tuningCents = 0.0
    private var temperament: Temperament = .equal
    private var root = 0
    private var volume: Float = 0.7 * 0.35

    init(engine: AVAudioEngine, soundFontURL: URL? = nil) throws {
        let url = soundFontURL ?? Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2", subdirectory: "SoundFonts") ?? Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2")
        engine.attach(sampler)
        engine.attach(mixer)
        engine.connect(sampler, to: mixer, format: nil)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        // GM Pipe Organ (zero-based program 19), with sustained loops in this bank.
        if let url {
            do {
                try sampler.loadSoundBankInstrument(at: url, program: 19, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0)
                soundFontAvailable = true
            } catch { soundFontAvailable = false }
        }
        sampler.sendController(1, withValue: 0, onChannel: 0) // No added modulation.
        sampler.sendController(91, withValue: 0, onChannel: 0)
        sampler.sendController(93, withValue: 0, onChannel: 0)
        let renderer = oscillator
        let node = AVAudioSourceNode { _, _, frames, buffers in
            renderer.render(Int(frames), buffers)
            return noErr
        }
        source = node
        engine.attach(node)
        engine.connect(node, to: mixer, format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        mixer.outputVolume = 0
    }
    func configure(tuning: Double, volume: Double, temperament: Temperament = .equal, root: Int = 0, sound: ReferenceSound = .precise) {
        if self.sound != sound { stop(immediately: true) }
        self.sound = sound == .soundFont && !soundFontAvailable ? .precise : sound
        self.tuning = tuning
        self.temperament = temperament
        self.root = root
        tuningCents = 1200 * log2(tuning / 440)
        applyPitch(currentNote ?? 69)
        self.volume = Float(volume) * 0.35
        if transition == nil && currentNote != nil { applyVolume(self.volume) }
    }
    func play(_ note: Double) {
        transition?.cancel()
        transition = Task { @MainActor [weak self] in
            guard let self else { return }
            if self.currentNote != nil {
                guard await self.fade(to: 0) else { return }
                self.killNotes()
            }
            self.mixer.outputVolume = 0
            self.currentNote = note
            self.applyPitch(note)
            if self.sound == .precise {
                self.oscillator.play(frequency: self.temperament.frequency(note: note, a4: self.tuning, root: self.root))
            } else {
                self.sampler.startNote(UInt8(Int(note.rounded())), withVelocity: 90, onChannel: 0)
            }
            guard await self.fade(to: self.volume) else { return }
            self.transition = nil
            // Include volume changes made during the envelope.
            self.applyVolume(self.volume)
        }
    }
    func stop(immediately: Bool = false) {
        transition?.cancel()
        transition = nil
        if immediately { mixer.outputVolume = 0; killNotes(); return }
        transition = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await self.fade(to: 0) else { return }
            self.killNotes()
            self.transition = nil
        }
    }
    private func applyVolume(_ value: Float) {
        if sound == .precise { oscillator.setVolume(value); mixer.outputVolume = 1 }
        else { mixer.outputVolume = value }
    }
    private func fade(to target: Float) async -> Bool {
        if sound == .precise {
            // The audio callback advances the envelope at sample resolution.
            applyVolume(target)
            do { try await Task.sleep(for: .milliseconds(18)) } catch { return false }
            return !Task.isCancelled
        }
        let initial = mixer.outputVolume
        for step in 1...6 {
            if Task.isCancelled { return false }
            mixer.outputVolume = initial + (target - initial) * Float(step) / 6
            do { try await Task.sleep(for: .milliseconds(3)) } catch { return false }
        }
        return true
    }
    private func applyPitch(_ note: Double) {
        sampler.globalTuning = Float(tuningCents + temperament.correction(note: note, root: root) + (note - note.rounded()) * 100)
        oscillator.setFrequency(temperament.frequency(note: note, a4: tuning, root: root))
    }
    private func killNotes() {
        oscillator.stop()
        if let note = currentNote { sampler.stopNote(UInt8(Int(note.rounded())), onChannel: 0) }
        sampler.sendController(120, withValue: 0, onChannel: 0)
        currentNote = nil
    }
}

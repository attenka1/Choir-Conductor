import AVFoundation
import Combine

/// Microphone recordings stay in the app's Documents directory; no network is used.
@MainActor final class RecordingManager: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    @Published private(set) var recordings: [RehearsalRecording] = []
    @Published private(set) var recording = false
    @Published private(set) var requestingPermission = false
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var playing: UUID?
    @Published var error: String?
    var prepareSession: (() -> Void)?
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var current: RehearsalRecording?
    private var timer: AnyCancellable?
    private var requestGeneration = 0
    private let directory: URL
    private var store: RecordingStore { RecordingStore(directory: directory) }

    override init() {
        directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recordings", isDirectory: true)
        super.init()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            do { recordings = try store.load() }
            catch {
                // Keep the unreadable index for recovery; never discard microphone audio.
                let backup = directory.appendingPathComponent("index-unreadable-" + UUID().uuidString + ".json")
                try FileManager.default.copyItem(at: store.index, to: backup)
                self.error = error.localizedDescription
            }
            // Recover completed files if the app was killed before updating the index.
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
            for file in files where file.pathExtension == "m4a" {
                guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent), !recordings.contains(where: { $0.id == id }), let audio = try? AVAudioPlayer(contentsOf: file), audio.duration > 0 else { continue }
                recordings.append(RehearsalRecording(id: id, name: T("Tallenne"), date: (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date(), duration: audio.duration))
            }
            recordings = recordings.filter { FileManager.default.fileExists(atPath: url($0).path) }.sorted { $0.date > $1.date }
            try persist()
        } catch { self.error = error.localizedDescription }
        timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, self.recording else { return }; self.elapsed = self.recorder?.currentTime ?? 0
        }
    }
    func url(_ item: RehearsalRecording) -> URL { store.url(item) }
    func start() async {
        guard !recording, !requestingPermission else { return }
        requestingPermission = true
        requestGeneration += 1
        let generation = requestGeneration
        let granted = await AVAudioApplication.requestRecordPermission()
        guard generation == requestGeneration else { return }
        requestingPermission = false
        guard granted else { error = T("Salli mikrofonin käyttö iPhonen asetuksissa."); return }
        stopPlayback()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
            try session.setActive(true)
            let item = RehearsalRecording(id: UUID(), name: T("Tallenne"), date: Date(), duration: 0)
            let newRecorder = try AVAudioRecorder(url: url(item), settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue, AVEncoderBitRateKey: 128000])
            newRecorder.delegate = self
            guard newRecorder.prepareToRecord(), newRecorder.record() else { throw CocoaError(.fileWriteUnknown) }
            current = item; recorder = newRecorder; elapsed = 0; recording = true
        } catch { self.error = error.localizedDescription }
    }
    func stop() {
        requestGeneration += 1; requestingPermission = false
        guard let recorder, var item = current else { return }
        let capturedDuration = max(recorder.currentTime, elapsed)
        self.recorder = nil; current = nil; recording = false
        recorder.stop()
        // currentTime can reset when a system interruption finishes the recorder.
        // Read the finalized file so a completed recording is never mistaken for an empty one.
        item.duration = (try? AVAudioPlayer(contentsOf: url(item)).duration) ?? capturedDuration
        elapsed = item.duration
        if item.duration > 0 { recordings.insert(item, at: 0); save() }
        else { try? FileManager.default.removeItem(at: url(item)) }
    }
    func togglePlayback(_ item: RehearsalRecording) {
        if playing == item.id { stopPlayback(); return }
        stop(); stopPlayback(); prepareSession?()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers]); try session.setActive(true)
            let newPlayer = try AVAudioPlayer(contentsOf: url(item)); newPlayer.delegate = self
            guard newPlayer.play() else { throw CocoaError(.fileReadUnknown) }
            player = newPlayer; playing = item.id
        } catch { self.error = error.localizedDescription }
    }
    func stopPlayback() { player?.stop(); player = nil; playing = nil }
    func stopAll() { stop(); stopPlayback() }
    func rename(_ item: RehearsalRecording, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 100, let i = recordings.firstIndex(where: { $0.id == item.id }) else { return }
        recordings[i].name = clean; save()
    }
    func delete(_ item: RehearsalRecording) {
        if playing == item.id { stopPlayback() }
        do { try FileManager.default.removeItem(at: url(item)); recordings.removeAll { $0.id == item.id }; try persist() }
        catch { self.error = error.localizedDescription }
    }
    private func persist() throws { try store.save(recordings) }
    private func save() { do { try persist() } catch { self.error = error.localizedDescription } }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            self.stop(); if !flag { self.error = T("Äänitys keskeytyi.") }
        }
    }
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in self?.stop(); self?.error = error?.localizedDescription ?? T("Äänitys keskeytyi.") }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in guard self?.player === player else { return }; self?.stopPlayback() }
    }
}

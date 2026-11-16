import AVFoundation
import Combine

/// Microphone recordings stay in the app's Documents directory; no network is used.
@MainActor final class RecordingManager: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    @Published private(set) var recordings: [RehearsalRecording] = []
    @Published private(set) var loading = true
    @Published private(set) var importing = false
    private var importTask: Task<RehearsalRecording, Error>?
    @Published private(set) var recording = false
    @Published private(set) var requestingPermission = false
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var playing: UUID?
    @Published var error: String?
    private let session: AudioSessionCoordinator
    var prepareSession: (() -> Void)?
    nonisolated static let maximumDuration: TimeInterval = 2 * 60 * 60
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var current: RehearsalRecording?
    private var timer: AnyCancellable?
    private var requestGeneration = 0
    private let directory: URL
    private var store: RecordingStore { RecordingStore(directory: directory) }

    init(session: AudioSessionCoordinator, directory directoryURL: URL? = nil) {
        self.session = session
        self.directory = directoryURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Recordings", isDirectory: true)
        super.init()
        let directory = self.directory
        Task { @MainActor [weak self] in
            let loaded = await Task.detached(priority: .utility) {
                Self.loadLibrary(directory: directory)
            }.value
            guard let self else { return }
            self.recordings = loaded.items
            self.error = loaded.error
            self.loading = false
        }
    }

    private nonisolated static func loadLibrary(directory: URL) -> (items: [RehearsalRecording], error: String?) {
        let store = RecordingStore(directory: directory)
        var recordings: [RehearsalRecording] = []
        var failure: String?
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            do { recordings = try store.load() }
            catch {
                let backup = directory.appendingPathComponent("index-unreadable-" + UUID().uuidString + ".json")
                try FileManager.default.copyItem(at: store.index, to: backup)
                failure = error.localizedDescription
            }
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
            var known = Set(recordings.map(\.id))
            for file in files where RehearsalRecording.supportedExtensions.contains(file.pathExtension) {
                guard let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                      !known.contains(id), let audio = try? AVAudioPlayer(contentsOf: file), audio.duration > 0 else { continue }
                known.insert(id)
                recordings.append(RehearsalRecording(id: id, name: T("Tallenne"),
                    date: (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date(), duration: audio.duration, fileExtension: file.pathExtension))
            }
            recordings = recordings.filter { FileManager.default.fileExists(atPath: store.url($0).path) }.sorted { $0.date > $1.date }
            try store.save(recordings)
        } catch { failure = error.localizedDescription }
        return (recordings, failure)
    }
    private func startElapsedUpdates() {
        timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self, self.recording else { return }; self.elapsed = self.recorder?.currentTime ?? 0
        }
    }
    func url(_ item: RehearsalRecording) -> URL { store.url(item) }
    /// Copy the original bytes without transcoding; analysis decodes the private copy.
    func importRecording(from source: URL) async -> RehearsalRecording? {
        guard !loading, !importing, !recording, !requestingPermission else { return nil }
        importing = true
        error = nil
        stopPlayback()
        let ext = source.pathExtension.lowercased()
        let stem = source.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = RehearsalRecording(id: UUID(), name: stem.isEmpty ? T("Tallenne") : String(stem.prefix(100)),
                                     date: Date(), duration: 0, fileExtension: ext)
        let destination = url(item)
        let worker = Task.detached(priority: .utility) {
            try Self.copyImport(source: source, destination: destination, item: item)
        }
        importTask = worker
        defer { importing = false; importTask = nil }
        do {
            let imported = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: { worker.cancel() }
            try Task.checkCancellation()
            if worker.isCancelled { throw CancellationError() }
            let updated = [imported] + recordings
            try store.save(updated)
            recordings = updated
            return imported
        } catch {
            try? FileManager.default.removeItem(at: destination)
            if !(error is CancellationError) { self.error = error.localizedDescription }
            return nil
        }
    }

    private nonisolated static func copyImport(source: URL, destination: URL,
                                               item: RehearsalRecording) throws -> RehearsalRecording {
        guard item.isValid else { throw RecordingImportError.unsupported }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".import-" + item.filename)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try Task.checkCancellation()
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
            do { try FileManager.default.copyItem(at: readable, to: temporary) }
            catch { copyError = error }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
        try Task.checkCancellation()
        let audio = try AVAudioFile(forReading: temporary, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = audio.processingFormat
        guard format.sampleRate.isFinite, (8000...192000).contains(format.sampleRate),
              (1...2).contains(format.channelCount), audio.length > 0 else {
            throw RecordingImportError.unsupported
        }
        let duration = Double(audio.length) / format.sampleRate
        guard duration.isFinite, duration <= maximumDuration else { throw RecordingImportError.tooLong }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else {
            throw CocoaError(.fileReadTooLarge)
        }
        try audio.read(into: buffer)
        guard buffer.frameLength > 0 else { throw RecordingImportError.unsupported }
        try Task.checkCancellation()
        try FileManager.default.moveItem(at: temporary, to: destination)
        var imported = item
        imported.duration = duration
        return imported
    }

    func start() async {
        guard !loading, !importing, !recording, !requestingPermission else { return }
        requestingPermission = true
        requestGeneration += 1
        let generation = requestGeneration
        let granted = await AVAudioApplication.requestRecordPermission()
        guard generation == requestGeneration else { return }
        requestingPermission = false
        guard granted else { error = T("Salli mikrofonin käyttö iPhonen asetuksissa."); return }
        stopPlayback()
        let item = RehearsalRecording(id: UUID(), name: T("Tallenne"), date: Date(), duration: 0)
        do {
            try session.begin(.recording)
            let newRecorder = try AVAudioRecorder(url: url(item), settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue, AVEncoderBitRateKey: 128000])
            newRecorder.delegate = self
            guard newRecorder.prepareToRecord(), newRecorder.record(forDuration: Self.maximumDuration) else { throw CocoaError(.fileWriteUnknown) }
            current = item; recorder = newRecorder; elapsed = 0; recording = true; startElapsedUpdates()
        } catch {
            session.end(.recording)
            try? FileManager.default.removeItem(at: url(item))
            self.error = error.localizedDescription
        }
    }
    func stop() {
        requestGeneration += 1; requestingPermission = false
        timer?.cancel(); timer = nil
        guard let recorder, var item = current else { return }
        let capturedDuration = max(recorder.currentTime, elapsed)
        self.recorder = nil; current = nil; recording = false
        recorder.stop()
        session.end(.recording)
        // currentTime can reset when a system interruption finishes the recorder.
        // Read the finalized file so a completed recording is never mistaken for an empty one.
        item.duration = (try? AVAudioPlayer(contentsOf: url(item)).duration) ?? capturedDuration
        elapsed = item.duration
        if item.duration > 0 { recordings.insert(item, at: 0); save() }
        else { try? FileManager.default.removeItem(at: url(item)) }
    }
    func togglePlayback(_ item: RehearsalRecording) {
        if playing == item.id { stopPlayback(); return }
        playRecording(item)
    }
    var playbackPosition: Double { player?.currentTime ?? 0 }
    func seekPlayback(_ item: RehearsalRecording, to seconds: Double) {
        guard playing == item.id, seconds.isFinite, let player else { return }
        player.currentTime = min(player.duration, max(0, seconds))
    }
    func playRecording(_ item: RehearsalRecording, at seconds: Double = 0) {
        guard !recording, !requestingPermission, recordings.contains(where: { $0.id == item.id }),
              seconds.isFinite else { return }
        error = nil
        stopPlayback(); prepareSession?()
        do {
            try session.begin(.playback, userInitiated: true)
            let newPlayer = try AVAudioPlayer(contentsOf: url(item)); newPlayer.delegate = self
            newPlayer.currentTime = min(newPlayer.duration, max(0, seconds))
            guard newPlayer.play() else { throw CocoaError(.fileReadUnknown) }
            player = newPlayer; playing = item.id
        } catch { session.end(.playback); self.error = error.localizedDescription }
    }
    func stopPlayback() { player?.stop(); player = nil; playing = nil; session.end(.playback) }
    func stopAll() { importTask?.cancel(); stop(); stopPlayback() }
    func rename(_ item: RehearsalRecording, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 100, let i = recordings.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = recordings
        updated[i].name = clean
        do { try store.save(updated); recordings = updated }
        catch { self.error = error.localizedDescription }
    }
    func delete(_ item: RehearsalRecording) {
        if playing == item.id { stopPlayback() }
        do { try FileManager.default.removeItem(at: url(item))
            let cache = RecordingAnalysisStore(source: url(item)).cache
            try? FileManager.default.removeItem(at: cache)
            recordings.removeAll { $0.id == item.id }; try persist() }
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
        Task { @MainActor [weak self] in
            guard let self, self.recorder === recorder else { return }
            self.stop(); self.error = error?.localizedDescription ?? T("Äänitys keskeytyi.")
        }
    }
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.player === player else { return }
            self.stopPlayback(); self.error = error?.localizedDescription ?? T("Äänitys keskeytyi.")
        }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in guard self?.player === player else { return }; self?.stopPlayback() }
    }
}

private nonisolated enum RecordingImportError: LocalizedError {
    case unsupported, tooLong
    var errorDescription: String? {
        switch self {
        case .unsupported:
            return analysisText("Äänitiedostoa ei tueta. Valitse mono- tai stereoäänite, jonka näytetaajuus on 8–192 kHz.")
        case .tooLong:
            return analysisText("Tuotava äänite saa kestää enintään 2 tuntia.")
        }
    }
}

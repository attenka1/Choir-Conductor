import AVFoundation

@MainActor protocol AudioSessionDriving {
    var category: AVAudioSession.Category { get }
    var categoryOptions: AVAudioSession.CategoryOptions { get }
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
    func setPreferredIOBufferDuration(_ duration: TimeInterval) throws
}

@MainActor private struct SystemAudioSession: AudioSessionDriving {
    private var session: AVAudioSession { .sharedInstance() }
    var category: AVAudioSession.Category { session.category }
    var categoryOptions: AVAudioSession.CategoryOptions { session.categoryOptions }
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
        try session.setCategory(category, mode: mode, options: options)
    }
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws { try session.setActive(active, options: options) }
    func setPreferredIOBufferDuration(_ duration: TimeInterval) throws { try session.setPreferredIOBufferDuration(duration) }
}

/// The only owner of AVAudioSession. Clients describe their actual audio needs.
@MainActor final class AudioSessionCoordinator {
    enum Client: Hashable { case sound, recording, playback, tuner }
    private let driver: any AudioSessionDriving
    init(driver: (any AudioSessionDriving)? = nil) { self.driver = driver ?? SystemAudioSession() }
    // Session claims are released explicitly. Avoid the isolated-deinit back-deployment
    // runtime path, which crashes on the iOS 18.5 simulator with this toolchain.
    nonisolated deinit {}
    private(set) var clients: Set<Client> = []
    private var active = false
    private var interrupted = false
    var onChange: (() -> Void)?
    var onError: ((Error) -> Void)?

    func begin(_ client: Client) throws {
        guard !interrupted else { throw CocoaError(.userCancelled) }
        guard !clients.contains(client) else { return }
        // The tuner owns microphone capture, but an explicitly enabled reference may play.
        guard client == .tuner ? clients.subtracting([.sound]).isEmpty :
                (!clients.contains(.tuner) || client == .sound) else {
            throw CocoaError(.userCancelled)
        }
        let previous = clients
        clients.insert(client)
        do { try reconcile(); onChange?() }
        catch { clients = previous; try? reconcile(); onChange?(); throw error }
    }
    func end(_ client: Client) {
        guard clients.remove(client) != nil else { return }
        do { try reconcile() } catch { onError?(error) }
        onChange?()
    }
    func interruptionBegan() {
        interrupted = true; active = false
        clients.removeAll(); onChange?()
    }
    func interruptionEnded() { interrupted = false; active = false }

    private func reconcile() throws {
        guard !interrupted else { return }
        let session = driver
        if clients.isEmpty {
            if active {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
                active = false
            }
            // Do not retain microphone routing after the recorder has stopped.
            if session.category != .playback || session.categoryOptions != [.mixWithOthers] {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
            return
        }
        let needsInput = clients.contains(.recording) || clients.contains(.tuner)
        let category: AVAudioSession.Category = needsInput ? .playAndRecord : .playback
        let options: AVAudioSession.CategoryOptions = needsInput ? [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers] : [.mixWithOthers]
        if session.category != category || session.categoryOptions != options {
            try session.setCategory(category, mode: .default, options: options)
        }
        if !active {
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true, options: [])
            active = true
        }
    }
}

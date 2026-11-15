import AVFoundation
import Combine
import Foundation

/// The input tap only copies into a bounded ring and never waits for the worker.
private nonisolated final class TunerTap: @unchecked Sendable {
    private let inputLock = NSLock()
    private let resultLock = NSLock()
    private var ring: [Float]
    private var readIndex = 0
    private var writeIndex = 0
    private var available = 0
    private var dropped = false
    private var missedInput = false // Owned only by the input callback.
    private var result: (pitch: TunerPitch?, time: TimeInterval)?
    private let worker: DispatchSourceTimer
    private let processor: TunerInputProcessor
    private var scratch = [Float](repeating: 0, count: 4096)

    init(rate: Double) {
        ring = Array(repeating: 0, count: max(4096, Int(rate / 2)))
        processor = TunerInputProcessor(rate: rate)
        worker = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "ChoirMaster.tuner", qos: .userInitiated))
        worker.schedule(deadline: .now(), repeating: .milliseconds(20))
        worker.setEventHandler { [weak self] in self?.drain() }
        worker.resume()
    }

    deinit { worker.cancel() }

    func consume(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        guard inputLock.try() else { missedInput = true; return }
        defer { inputLock.unlock() }
        if missedInput {
            available = 0; readIndex = writeIndex; dropped = true; missedInput = false
        }
        let count = Int(buffer.frameLength)
        guard count <= ring.count - available else {
            // Discard old windows under overload instead of building latency.
            available = 0; readIndex = writeIndex; dropped = true
            return
        }
        for index in 0..<count {
            ring[writeIndex] = channel[index * buffer.stride]
            writeIndex = (writeIndex + 1) % ring.count
        }
        available += count
    }

    private func drain() {
        // Only the serial worker touches the processor and scratch buffer.
        inputLock.lock()
        let reset = dropped
        dropped = false
        let count = min(available, scratch.count)
        for index in 0..<count {
            scratch[index] = ring[readIndex]
            readIndex = (readIndex + 1) % ring.count
        }
        available -= count
        inputLock.unlock()
        if reset { processor.reset() }
        guard count > 0 else { return }
        scratch.withUnsafeBufferPointer { buffer in
            processor.consume(UnsafeBufferPointer(rebasing: buffer[..<count])) { [self] pitch in
                resultLock.withLock { result = (pitch, ProcessInfo.processInfo.systemUptime) }
            }
        }
    }

    func latest() -> (pitch: TunerPitch?, time: TimeInterval)? {
        resultLock.withLock { result }
    }
}

@MainActor final class LiveTuner: ObservableObject {
    @Published private(set) var active = false
    @Published private(set) var pitch: TunerPitch?
    @Published private(set) var inputName: String?
    @Published private(set) var error: String?
    private let session: AudioSessionCoordinator
    private var engine: AVAudioEngine?
    private var updates: AnyCancellable?
    private var generation = 0

    init(session: AudioSessionCoordinator) {
        self.session = session
    }

    // stop() releases capture explicitly. Avoid the iOS 18.5 isolated-deinit
    // back-deployment runtime path (also used by AudioSessionCoordinator).
    nonisolated deinit {}

    func start(prepare: @MainActor () -> Bool) async {
        guard !active, !Task.isCancelled else { return }
        error = nil
        active = true
        generation += 1
        let request = generation
        let granted = await AVAudioApplication.requestRecordPermission()
        guard generation == request, !Task.isCancelled else {
            if generation == request { stop() }
            return
        }
        guard granted else {
            fail(T("Salli mikrofonin käyttö iPhonen asetuksissa."))
            return
        }
        guard prepare() else {
            fail(tunerText("Lopeta äänitys ennen viritysmittarin käyttöä."))
            return
        }
        do {
            try session.begin(.tuner)
            let engine = AVAudioEngine()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            let route = AVAudioSession.sharedInstance().currentRoute.inputs
            guard format.sampleRate.isFinite, format.sampleRate >= 8000,
                  format.channelCount > 0, format.commonFormat == .pcmFormatFloat32,
                  let device = route.first else {
                fail(tunerText("Mikrofonin kuuntelu ei onnistunut."))
                return
            }
            let tap = TunerTap(rate: format.sampleRate)
            // The explicit Sendable callback must not inherit the main actor.
            let receive: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, _ in tap.consume(buffer) }
            input.installTap(onBus: 0, bufferSize: 1024, format: nil, block: receive)
            self.engine = engine
            try engine.start()
            inputName = device.portName
            let routeIDs = route.map(\.uid)
            let started = ProcessInfo.processInfo.systemUptime
            updates = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                guard let self, let engine = self.engine else { return }
                let currentRoute = AVAudioSession.sharedInstance().currentRoute.inputs.map(\.uid)
                let reading = tap.latest()
                let age = ProcessInfo.processInfo.systemUptime - (reading?.time ?? started)
                guard engine.isRunning, currentRoute == routeIDs, age < 4 else {
                    self.fail(tunerText("Mikrofonin kuuntelu keskeytyi."))
                    return
                }
                let pitch = age < 0.5 ? reading?.pitch : nil
                if self.pitch != pitch { self.pitch = pitch }
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    func stop() {
        generation += 1
        updates?.cancel()
        updates = nil
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            self.engine = nil
        }
        session.end(.tuner)
        pitch = nil
        inputName = nil
        active = false
    }

    private func fail(_ message: String) {
        stop()
        error = message
    }
}

import AVFoundation
import Foundation

@MainActor final class ChoirAudio {
    let engine = AVAudioEngine()
    let renderer = AudioRenderer()
    private(set) var reference: ReferenceTone!
    private var source: AVAudioSourceNode?
    init() throws {
        for note in 55...79 {
            guard let url = Bundle.main.url(forResource: "note_\(note)", withExtension: "wav", subdirectory: "PianoSamples") ?? Bundle.main.url(forResource: "note_\(note)", withExtension: "wav") else {
                throw NSError(domain: "ChoirAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: T("Pianonäyte note_%@.wav puuttuu.", String(note))])
            }
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { throw NSError(domain: "ChoirAudio", code: 2) }
            try file.read(into: buffer)
            guard let channels = buffer.floatChannelData else { throw NSError(domain: "ChoirAudio", code: 3) }
            var mono = [Float](repeating: 0, count: Int(buffer.frameLength))
            for i in mono.indices { for c in 0..<Int(buffer.format.channelCount) { mono[i] += channels[c][i] / Float(buffer.format.channelCount) } }
            renderer.samples.append(mono)
        }
        let state = renderer
        let node = AVAudioSourceNode { _, _, count, buffers in
            state.render(Int(count), buffers)
            return noErr
        }
        source = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        reference = try ReferenceTone(engine: engine)
        engine.prepare()
    }
    func start() throws {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord { try session.setCategory(.playback, mode: .default, options: [.mixWithOthers]) }
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        if !engine.isRunning { try engine.start() }
    }
    func silence(deactivateSession: Bool = true) {
        reference.stop(immediately: true)
        renderer.update { state in
            state.running = false; state.clickAge = 10000
            for i in state.voices.indices { state.voices[i].held = false; state.voices[i].gain = 0 }
        }
        engine.pause()
        if deactivateSession { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }
}

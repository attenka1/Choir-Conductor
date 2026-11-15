import AVFoundation
import Foundation

@MainActor final class ChoirAudio {
    // Audio is stopped explicitly; avoid nested isolated-deinit back-deployment on iOS 18.5.
    nonisolated deinit {}
    let engine = AVAudioEngine()
    private let session: AudioSessionCoordinator
    let renderer = AudioRenderer()
    private(set) var reference: ReferenceTone!
    private var source: AVAudioSourceNode?
    init(session: AudioSessionCoordinator) throws {
        self.session = session
        guard let metadataURL = Bundle.main.url(forResource: "metadata", withExtension: "json", subdirectory: "PianoSamples") ?? Bundle.main.url(forResource: "metadata", withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
        let metadata = try PianoSampleMetadata.load(from: metadataURL)
        renderer.frequencies = metadata.map(\.fundamentalHz)
        for item in metadata {
            let note = item.midi
            guard let url = Bundle.main.url(forResource: "note_\(note)", withExtension: "wav", subdirectory: "PianoSamples") ?? Bundle.main.url(forResource: "note_\(note)", withExtension: "wav") else {
                throw NSError(domain: "ChoirAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: T("Pianonäyte note_%@.wav puuttuu.", String(note))])
            }
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { throw NSError(domain: "ChoirAudio", code: 2) }
            try file.read(into: buffer)
            guard Int(buffer.frameLength) == item.frames,
                  Int(buffer.format.sampleRate) == item.sampleRate,
                  Int(buffer.format.channelCount) == item.channels else { throw CocoaError(.fileReadCorruptFile) }
            let index = note - 55
            renderer.loopEnds[index] = Double(item.loopEndFrame)
            renderer.loopLengths[index] = Double(item.loopLengthFrames)
            renderer.crossfades[index] = Double(item.crossfadeFrames)
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
        try session.begin(.sound)
        do { if !engine.isRunning { try engine.start() } }
        catch { session.end(.sound); throw error }
    }
    func silence() {
        reference.stop(immediately: true)
        // Pause before releasing the engine's session claim; the next callback consumes clear().
        engine.pause()
        renderer.clear()
        session.end(.sound)
    }
}

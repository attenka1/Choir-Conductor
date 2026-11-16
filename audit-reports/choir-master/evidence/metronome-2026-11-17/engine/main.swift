import AVFoundation
import Foundation
var results: [[String: Any]] = []
for rate in [44100.0, 48000.0] {
    let engine = AVAudioEngine()
    let state = AudioRenderer()
    state.configure(tempo: 137, beats: 1, piano: 0, click: 0.6, pitches: nil)
    state.setMetronome(running: true, reset: true)
    let node = AVAudioSourceNode { _, _, frames, buffers in state.render(Int(frames), buffers); return noErr }
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
    let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
    try engine.start()
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
    var quiet = 1000
    var onsets: [Int] = []
    var frames = 0
    var retries = 0
    while frames < Int(rate * 60) {
        let count = min(4096, Int(rate * 60) - frames)
        let status = try engine.renderOffline(AVAudioFrameCount(count), to: buffer)
        if status == .cannotDoInCurrentContext {
            retries += 1
            precondition(retries < 100, "Too many offline retries")
            continue
        }
        precondition(status == .success, "Offline engine status \(status)")
        let data = buffer.floatChannelData![0]
        for index in 0..<Int(buffer.frameLength) {
            precondition(data[index].isFinite)
            if abs(data[index]) > 1e-6 {
                if quiet > 200 { onsets.append(frames + index) }
                quiet = 0
            } else { quiet += 1 }
        }
        frames += Int(buffer.frameLength)
    }
    engine.stop()
    precondition(onsets.count == 137, "Output beat count \(onsets.count) at \(rate)")
    let first = onsets[0]
    let error = onsets.enumerated().map { abs(Double($0.element - first) - Double($0.offset) * rate * 60 / 137) }.max()!
    precondition(error < 3, "Output phase error \(error) at \(rate)")
    results.append(["output_rate": rate, "input_rate":44100, "bpm":137, "seconds":60,
                    "onsets":onsets.count, "first_onset":first, "max_relative_phase_error_output_samples":error])
}
let json = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted,.sortedKeys])
try json.write(to: URL(fileURLWithPath: "/tmp/choir-metronome-audit/engine-results.json"))
print("PASS: actual AVAudioEngine offline graph, 44.1/48 kHz output, 137 PCM onsets per minute")

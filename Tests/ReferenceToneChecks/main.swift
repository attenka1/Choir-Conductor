import AVFoundation
import Foundation

// Exercise the production SoundFont voice without a speaker or microphone.
let engine = AVAudioEngine()
let tone = try ReferenceTone(engine: engine, soundFontURL: URL(fileURLWithPath: CommandLine.arguments[1]))
let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 512)
try engine.start()
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
func render(seconds: Double) throws -> [Float] {
    var result: [Float] = []
    for _ in 0..<Int(seconds * 44100 / 512) {
        let status = try engine.renderOffline(512, to: buffer)
        precondition(status == .success, "Offline rendering failed")
        result.append(contentsOf: UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }
    return result
}
func rms(_ samples: [Float]) -> Double { sqrt(samples.reduce(0) { $0 + Double($1 * $1) } / Double(samples.count)) }
let cases: [(Double, Double, Temperament)] = [(415,69,.equal), (440,69,.equal), (442,69,.equal), (443.5,69,.equal), (442,69.5,.equal)] + Temperament.allCases.filter { $0 != .equal }.map { (442,64,$0) }
for (tuning, note, system) in cases {
    tone.configure(tuning: tuning, volume: 0.7, temperament: system, root: 0)
    tone.play(note)
    try await Task.sleep(for: .milliseconds(70))
    let samples = try render(seconds: 6)
    precondition(samples.allSatisfy { $0.isFinite && abs($0) < 1 }, "Invalid or clipped output")
    let tail = Array(samples.suffix(44100))
    precondition(rms(tail) > 0.0001, "Sustained tone became silent")
    let file = try AVAudioFile(forWriting: URL(fileURLWithPath: "/tmp/choir-reference-\(tuning)-\(note)\(system == .equal ? "" : "-" + system.rawValue).wav"), settings: format.settings)
    for base in stride(from: 0, to: samples.count, by: 512) {
        let count = min(512, samples.count-base); buffer.frameLength = AVAudioFrameCount(count)
        for channel in 0..<2 { for i in 0..<count { buffer.floatChannelData![channel][i] = samples[base+i] } }
        try file.write(from: buffer)
    }
    tone.stop()
    try await Task.sleep(for: .milliseconds(70))
    _ = try render(seconds: 0.2)
    let silence = try render(seconds: 0.2)
    precondition(rms(silence) < 0.00001, "Stop left a tone sounding")
    print("PASS: A4 \(tuning), MIDI \(note), six-second sustain, bounded output, soft stop; tail RMS \(rms(tail))")
}
tone.play(60); tone.play(72); tone.stop(immediately: true)
try await Task.sleep(for: .milliseconds(70))
_ = try render(seconds: 0.2)
let silence = try render(seconds: 0.2)
precondition(rms(silence) < 0.00001, "Cancelled transition restarted sound")
print("PASS: rapid changes and immediate stop do not restart playback")
engine.stop()

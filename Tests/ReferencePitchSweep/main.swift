import AVFoundation
import Foundation

let baseline = CommandLine.arguments.contains("--baseline")
let folder = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let engine = AVAudioEngine()
let tone = try ReferenceTone(engine: engine, soundFontURL: URL(fileURLWithPath: CommandLine.arguments[1]))
let sampleRate = CommandLine.arguments.contains("--48000") ? 48000.0 : 44100.0
let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
try engine.start()
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
func render(seconds: Double, capture: Bool) throws -> [Float] {
    var samples: [Float] = []
    for _ in 0..<Int(seconds * sampleRate / 1024) {
        let status = try engine.renderOffline(1024, to: buffer)
        precondition(status == .success)
        let channel = buffer.floatChannelData![0]
        for i in 0..<Int(buffer.frameLength) {
            precondition(channel[i].isFinite && abs(channel[i]) < 1)
            if capture { samples.append(channel[i]) }
        }
    }
    return samples
}
var cases: [(Double, Double, Temperament, Int)] = []
if baseline {
    cases = (36...84).map { (440, Double($0), .equal, 0) }
} else if sampleRate == 48000 {
    for system in Temperament.allCases {
        for midi in 36...84 { cases.append((442, Double(midi), system, 0)) }
    }
    for index in 0..<48 { cases.append((442, 36.5 + Double(index), .equal, 0)) }
} else {
    for tuning in [415.0, 440.0, 442.0] {
        for system in Temperament.allCases {
            for midi in 36...84 { cases.append((tuning, Double(midi), system, 0)) }
        }
        for index in 0..<48 { cases.append((tuning, 36.5 + Double(index), .equal, 0)) }
    }
    for root in 1..<12 {
        for system in Temperament.allCases where system != .equal {
            for midi in 36...84 { cases.append((442, Double(midi), system, root)) }
        }
    }
    for tuning in [300.0, 500.0] {
        for midi in 36...84 { cases.append((tuning, Double(midi), .equal, 0)) }
    }
}
var manifest = "file,a4,note,system,root,target_hz,sample_rate\n"
for (index, item) in cases.enumerated() {
    let (tuning, note, system, root) = item
    tone.stop(immediately: true)
    _ = try render(seconds: 0.08, capture: false)
    tone.configure(tuning: tuning, volume: 0.7, temperament: system, root: root, sound: baseline ? .soundFont : .precise)
    tone.play(note)
    try await Task.sleep(for: .milliseconds(30))
    _ = try render(seconds: 0.6, capture: false)
    let samples = try render(seconds: 2.05, capture: true)
    precondition(samples.contains { abs($0) > 0.0001 }, "Silent note")
    let name = "\(index).f32"
    try samples.withUnsafeBytes { try Data($0).write(to: folder.appendingPathComponent(name)) }
    let target = system.frequency(note: note, a4: tuning, root: root)
    manifest += "\(name),\(tuning),\(note),\(system.rawValue),\(root),\(target),\(sampleRate)\n"
    if index % 100 == 0 { print("Rendered \(index + 1)/\(cases.count)"); fflush(stdout) }
}
try manifest.write(to: folder.appendingPathComponent("manifest.csv"), atomically: true, encoding: .utf8)
tone.stop(immediately: true)
_ = try render(seconds: 0.5, capture: false)
let silence = try render(seconds: 0.2, capture: true)
precondition(silence.allSatisfy { abs($0) < 0.00001 }, "Stuck note")
print("PASS: \(cases.count) voices rendered; bounded audio and final silence")
engine.stop()

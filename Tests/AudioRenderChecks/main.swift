import AVFoundation
import Foundation

func require(_ condition: Bool, _ message: String) {
    if !condition { fatalError(message) }
}
let renderer = AudioRenderer()
let folder = CommandLine.arguments[1]
let metadata = try PianoSampleMetadata.load(from: URL(fileURLWithPath: folder).appendingPathComponent("metadata.json"))
renderer.frequencies = metadata.map(\.fundamentalHz)
for (index, item) in metadata.enumerated() {
    renderer.loopEnds[index] = Double(item.loopEndFrame)
    renderer.loopLengths[index] = Double(item.loopLengthFrames)
    renderer.crossfades[index] = Double(item.crossfadeFrames)
}
for note in 55...79 {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: folder).appendingPathComponent("note_\(note).wav"))
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    let channels = buffer.floatChannelData!
    renderer.samples.append((0..<Int(buffer.frameLength)).map { (channels[0][$0] + channels[1][$0]) / 2 })
}
let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
func render(_ frames: Int) -> [Float] {
    buffer.frameLength = AVAudioFrameCount(frames)
    renderer.render(frames, buffer.mutableAudioBufferList)
    return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: frames))
}
// Verify exact sample intervals and accent/meter cycling for all beat modes.
for beats in 1...16 {
    renderer.running = true; renderer.tempo = 240; renderer.beats = beats; renderer.beat = -1; renderer.remaining = 0
    var events: [(Int,Int,Bool)] = []
    for frame in 0..<(11025 * (beats + 1)) {
        let old = renderer.remaining
        _ = render(1)
        if old <= 0 { events.append((frame,renderer.beat,renderer.accent)) }
    }
    require(events.count == beats + 1, "Beat count")
    for (index,event) in events.enumerated() {
        require(event.0 == index * 11025, "Metronome sample drift")
        require(event.1 == index % beats && event.2 == (index % beats == 0), "Meter accent")
    }
}
renderer.tempo = 120; renderer.remaining = 0; _ = render(1)
require(renderer.remaining == 22049, "Live tempo change")
renderer.running = false; renderer.clickAge = 10000
// All available notes can run together; verify finite, bounded output and releases.
for index in 0..<97 {
    let note = Double(index) / 2 + 36; let source = min(79,max(55,Int(note.rounded())))
    renderer.steps[index] = 442 * pow(2,(note-69)/12) / renderer.frequencies[source-55]
    renderer.voices[index].held = true
}
// Render isolated adjacent 24-EDO notes for independent spectral verification.
for i in renderer.voices.indices { renderer.voices[i] = AudioRenderer.Voice() }
for note in [69.0,69.5] {
    let index = Int((note - 36) * 2)
    renderer.voices[index].held = true
    let file = try AVAudioFile(forWriting: URL(fileURLWithPath: "/tmp/choir-piano-442.0-\(note).wav"), settings: format.settings)
    for _ in 0..<40 { _ = render(512); try file.write(from: buffer) }
    renderer.voices[index] = AudioRenderer.Voice()
}
for i in renderer.voices.indices { renderer.voices[i].held = true }
var peak: Float = 0
for _ in 0..<500 {
    for sample in render(512) { require(sample.isFinite && abs(sample) <= 1, "Invalid/clipped output"); peak = max(peak,abs(sample)) }
}
require(peak > 0.01, "No piano output")
require(renderer.voices.allSatisfy { $0.gain > 0.99 }, "Sustain stopped")
for i in 0..<97 { renderer.voices[i].held = false }
for _ in 0..<20 { _ = render(512) }
require(render(512).allSatisfy { abs($0) < 0.00001 }, "Release did not reach silence")
print("PASS: sample-accurate 1–16 beats and accents, live tempo, 97 quarter-tone voices, sustain loops, bounded output, soft release. Peak: \(peak)")

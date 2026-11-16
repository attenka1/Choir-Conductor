import AVFoundation
import Foundation

let rate = 44100.0
let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
var checks = 0
var records: [[String: Any]] = []
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { fatalError(message) }
}
func configured(_ bpm: Double, beats: Int = 4, click: Float = 0.6) -> AudioRenderer {
    let renderer = AudioRenderer()
    renderer.configure(tempo: bpm, beats: beats, piano: 0, click: click, pitches: nil)
    renderer.setMetronome(running: true, reset: true)
    return renderer
}
func block(_ renderer: AudioRenderer, _ count: Int) -> [Float] {
    buffer.frameLength = AVAudioFrameCount(count)
    renderer.render(count, buffer.mutableAudioBufferList)
    let left = buffer.floatChannelData![0]
    let right = buffer.floatChannelData![1]
    for i in 0..<count { check(left[i].isFinite && left[i] == right[i] && abs(left[i]) <= 1, "Stereo/finiteness") }
    return Array(UnsafeBufferPointer(start: left, count: count))
}
func output(_ bpm: Double, frames: Int, sizes: [Int]) -> [Float] {
    let renderer = configured(bpm)
    var samples: [Float] = []
    var part = 0
    while samples.count < frames {
        samples += block(renderer, min(sizes[part % sizes.count], frames - samples.count))
        part += 1
    }
    return samples
}
func events(_ samples: [Float]) -> [Int] {
    var quiet = 1000
    var starts: [Int] = []
    for (i, sample) in samples.enumerated() {
        if abs(sample) > 1e-6 {
            if quiet > 200 { starts.append(i - 1) }
            quiet = 0
        } else { quiet += 1 }
    }
    return starts
}
// Independent onsets from PCM, not the renderer's remaining/beat counters.
for bpm in 30...240 {
    let samples = output(Double(bpm), frames: Int(ceil(rate * 60 / Double(bpm) * 7)) + 100, sizes: [1, 127, 512, 4096, 33])
    let onsets = events(samples)
    check(onsets.count == 8, "Onset count at \(bpm): \(onsets)")
    let worst = onsets.enumerated().map { abs(Double($0.element) - Double($0.offset) * rate * 60 / Double(bpm)) }.max()!
    check(worst <= 1.000001, "Onset phase at \(bpm): \(worst)")
}
records.append(["test": "all_integer_tempos", "cases": 211, "beats_each": 8, "phase_error_source_samples_max": 1])
for bpm in [40, 60, 120, 180, 240, 137, 239] {
    let renderer = configured(Double(bpm))
    let frames = Int(rate) * 600
    var quiet = 1000
    var count = 0
    var worst = 0.0
    var last = 0
    var position = 0
    while position < frames {
        let n = min(4096, frames - position)
        renderer.render(n, buffer.mutableAudioBufferList)
        let samples = buffer.floatChannelData![0]
        for i in 0..<n {
            if abs(samples[i]) > 1e-6 {
                if quiet > 200 {
                    let onset = position + i - 1
                    worst = max(worst, abs(Double(onset) - Double(count) * rate * 60 / Double(bpm)))
                    count += 1; last = onset
                }
                quiet = 0
            } else { quiet += 1 }
        }
        position += n
    }
    check(count == bpm * 10, "10-minute beat count at \(bpm): \(count)")
    check(worst <= 1.000001, "10-minute phase at \(bpm): \(worst)")
    records.append(["test":"ten_minute_clock", "bpm": bpm, "frames":frames, "onsets":count, "max_phase_error_samples":worst, "last_onset":last])
}
for bpm in [40.0, 137, 240] {
    let frames = Int(rate * 4)
    let fixed = output(bpm, frames: frames, sizes: [512])
    let variable = output(bpm, frames: frames, sizes: [1, 17, 4096, 89, 256])
    check(fixed == variable, "Buffer size changes output at \(bpm)")
}
records.append(["test":"buffer_invariance", "bpm":[40,137,240], "result":"bit-identical PCM"])
func frequency(_ snippet: ArraySlice<Float>) -> Double {
    var crossings: [Double] = []
    let samples = Array(snippet)
    for i in 1..<samples.count where samples[i - 1] <= 0 && samples[i] > 0 {
        let a = Double(samples[i - 1]), b = Double(samples[i])
        crossings.append(Double(i - 1) - a / (b - a))
    }
    return Double(crossings.count - 1) * rate / (crossings.last! - crossings.first!)
}
for meter in 1...16 {
    let renderer = configured(240, beats: meter)
    var samples: [Float] = []
    while samples.count < (meter + 1) * 11025 + 1000 {
        samples += block(renderer, min(4096, (meter + 1) * 11025 + 1000 - samples.count))
    }
    let onsets = events(samples)
    for (index, onset) in onsets.enumerated() {
        check(onset == index * 11025, "Meter time")
        let measured = frequency(samples[(onset + 20)..<(onset + 900)])
        let expected = index % meter == 0 ? 1600.0 : 1000.0
        check(abs(measured - expected) < 0.5, "Meter \(meter) beat \(index): \(measured)")
    }
}
records.append(["test":"all_meters_pcm_accents", "meters":16, "accent_hz":1600, "regular_hz":1000])
// Tempo change is applied at the next scheduled beat, without shortening the old interval.
do {
    let renderer = configured(120)
    var samples = block(renderer, 1000)
    renderer.configure(tempo: 240, beats: 4, piano: 0, click: 0.6, pitches: nil)
    while samples.count < 46000 { samples += block(renderer, min(4096, 46000 - samples.count)) }
    check(events(samples) == [0, 22050, 33075, 44100], "Live tempo transition \(events(samples))")
    renderer.setMetronome(running: false, reset: true)
    check(block(renderer, 4096).allSatisfy { $0 == 0 }, "Stop not silent")
    renderer.setMetronome(running: true, reset: true)
    let restarted = block(renderer, 1000)
    check(events(restarted) == [0] && renderer.currentBeat == 0, "Restart downbeat")
    renderer.clear()
    check(block(renderer, 4096).allSatisfy { $0 == 0 }, "Clear not silent")
}
do {
    let renderer = configured(137, click: 0)
    check(block(renderer, 4096).allSatisfy { $0 == 0 } && renderer.currentBeat == 0, "Muted clock")
}
records.append(["test":"control_mailbox", "live_onsets":[0,22050,33075,44100], "stop_clear_restart_mute":"pass"])
let result: [String: Any] = ["assertions":checks, "results":records, "source_sample_rate":rate]
let json = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try json.write(to: URL(fileURLWithPath: "/tmp/choir-metronome-audit/clock-results.json"))
print("PASS: 211 tempos; seven 10-minute clocks; PCM meter accents; variable buffers; mailbox tempo/stop/restart/mute. Assertions: \(checks)")

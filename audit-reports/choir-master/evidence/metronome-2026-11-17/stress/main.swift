import AVFoundation
import Foundation
func render(_ renderer: AudioRenderer, frames: Int) -> [Float] {
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512)!
    var output = [Float](); output.reserveCapacity(frames)
    while output.count < frames {
        let count = min(512, frames - output.count)
        renderer.render(count, buffer.mutableAudioBufferList)
        output.append(contentsOf: UnsafeBufferPointer(start: buffer.floatChannelData![0], count: count))
    }
    return output
}
func configured() -> AudioRenderer {
    let state = AudioRenderer()
    state.configure(tempo:137, beats:4, piano:0, click:0.6, pitches:nil)
    state.setMetronome(running:true, reset:true)
    return state
}
let baseline = configured()
let stressed = configured()
// Consume initial commands before contention so both streams start at the same clock phase.
var reference = render(baseline, frames:512)
var actual = render(stressed, frames:512)
let group = DispatchGroup()
group.enter()
DispatchQueue.global(qos:.userInitiated).async {
    for _ in 0..<1_000_000 {
        stressed.configure(tempo:137, beats:4, piano:0, click:0.6, pitches:nil)
        _ = stressed.currentBeat
    }
    group.leave()
}
actual += render(stressed, frames:44100 * 60 - 512)
reference += render(baseline, frames:44100 * 60 - 512)
precondition(group.wait(timeout:.now() + 20) == .success, "Publisher timeout")
precondition(reference == actual, "Mailbox contention altered PCM clock")
print("PASS: one million concurrent same-state publications/beat reads, 60s at 137 BPM, bit-identical PCM")

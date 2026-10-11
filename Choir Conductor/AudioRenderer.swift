import AVFoundation
import Foundation

// Only the audio callback advances time. UI polling never schedules sound.
nonisolated final class AudioRenderer: @unchecked Sendable {
    struct Voice { var position = 0.0; var gain: Float = 0; var held = false }
    let lock = NSLock()
    var samples: [[Float]] = []
    var voices = Array(repeating: Voice(), count: 97)
    let frequencies: [Double] = [194.531,206.414,219.322,232.151,245.854,260.781,276.878,292.618,310.947,329.334,348.640,368.790,390.463,413.547,439.672,465.173,491.441,521.523,553.243,587.345,620.539,656.855,696.428,737.334,782.513]
    var steps = Array(repeating: 1.0, count: 97)
    var tuning = 442.0
    var pianoVolume: Float = 0.7
    var clickVolume: Float = 0.6
    var tempo = 80.0
    var beats = 4
    var running = false
    var beat = -1
    var remaining = 0.0
    var clickAge = 10_000
    var accent = false
    let rate = 44100.0

    func update(_ action: (AudioRenderer) -> Void) { lock.lock(); defer { lock.unlock() }; action(self) }
    func render(_ count: Int, _ buffers: UnsafeMutablePointer<AudioBufferList>) {
        lock.lock(); defer { lock.unlock() }
        let output = UnsafeMutableAudioBufferListPointer(buffers)
        for frame in 0..<count {
            var value: Float = 0
            if running {
                if remaining <= 0 {
                    beat = (beat + 1) % beats
                    accent = beat == 0
                    clickAge = 0
                    remaining += rate * 60 / tempo
                }
                remaining -= 1
            }
            if clickAge < 1600 {
                let t = Double(clickAge) / rate
                let envelope = min(1, Double(clickAge) / 30) * exp(-t * 180)
                value += Float(sin(2 * .pi * (accent ? 1600 : 1000) * t) * envelope) * clickVolume * 0.28
                clickAge += 1
            }
            for index in 0..<97 {
                if !voices[index].held && voices[index].gain < 0.00001 { continue }
                let note = Double(index) / 2 + 36
                let source = min(79, max(55, Int(note.rounded())))
                let data = samples[source - 55]
                let end = min(Double(data.count - 2), 28665.0) // Sustain after the natural attack.
                let loopLength = min(17640.0, end / 2)
                let crossfade = 3528.0
                if voices[index].position >= end { voices[index].position -= loopLength }
                let p = voices[index].position
                let i = Int(p)
                let fraction = Float(p - Double(i))
                var sample = data[i] + (data[i + 1] - data[i]) * fraction
                // Crossfade the sustained tail to prevent a discontinuity at the loop boundary.
                if p > end - crossfade {
                    let q = p - loopLength
                    let j = Int(q)
                    let f = Float(q - Double(j))
                    let other = data[j] + (data[j + 1] - data[j]) * f
                    let mix = Float((p - end + crossfade) / crossfade)
                    sample = sample * (1 - mix) + other * mix
                }
                if voices[index].held { voices[index].gain = min(1, voices[index].gain + 1 / 220.0) }
                else { voices[index].gain *= 0.997 }
                value += sample * voices[index].gain * pianoVolume * 0.12
                voices[index].position += steps[index]
            }
            // Bounded output even with every key held.
            value = tanh(value)
            for buffer in output {
                if let pointer = buffer.mData?.assumingMemoryBound(to: Float.self) { pointer[frame] = value }
            }
        }
    }
}


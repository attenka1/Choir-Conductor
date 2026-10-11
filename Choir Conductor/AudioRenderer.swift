import AVFoundation
import Foundation

// Only the audio callback advances time. UI polling never schedules sound.
nonisolated final class AudioRenderer: @unchecked Sendable {
    struct Voice { var position = 0.0; var gain: Float = 0; var held = false }
    // The callback only tries this mailbox lock; it never waits for the UI.
    // DSP state below is owned exclusively by the audio callback.
    private let lock = NSLock()
    private struct KeyControl { var held = false; var onset: UInt64 = 0 }
    private var keys = Array(repeating: KeyControl(), count: 97)
    private var appliedOnsets = Array(repeating: UInt64(0), count: 97)
    private var pendingSteps = Array(repeating: 1.0, count: 97)
    private var pendingTempo = 80.0
    private var pendingBeats = 4
    private var pendingPiano: Float = 0.7
    private var pendingClick: Float = 0.6
    private var pendingRunning = false
    private var resetSerial: UInt64 = 0
    private var appliedReset: UInt64 = 0
    private var clearSerial: UInt64 = 0
    private var appliedClear: UInt64 = 0
    private var dirty = false
    private var displayedBeat = -1
    var samples: [[Float]] = []
    var voices = Array(repeating: Voice(), count: 97)
    var frequencies: [Double] = []
    var loopEnds = Array(repeating: 28665.0, count: 25)
    var loopLengths = Array(repeating: 14332.5, count: 25)
    var crossfades = Array(repeating: 3528.0, count: 25)
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

    func configure(tempo: Double, beats: Int, piano: Float, click: Float, pitches: [Double]?) {
        lock.lock(); defer { lock.unlock() }
        pendingTempo = tempo; pendingBeats = beats; pendingPiano = piano; pendingClick = click
        if let pitches { for i in 0..<97 { pendingSteps[i] = pitches[i] } }
        dirty = true
    }
    func setMetronome(running: Bool, reset: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        pendingRunning = running
        if reset { resetSerial &+= 1 }
        dirty = true
    }
    func startNotes(_ notes: [Double]) {
        lock.lock(); defer { lock.unlock() }
        for note in notes {
            let i = Int((note - 36) * 2)
            keys[i].held = true; keys[i].onset &+= 1
        }
        dirty = true
    }
    func releaseNote(_ note: Double) {
        lock.lock(); defer { lock.unlock() }
        keys[Int((note - 36) * 2)].held = false; dirty = true
    }
    func clear() {
        lock.lock(); defer { lock.unlock() }
        for i in keys.indices { keys[i].held = false }
        pendingRunning = false; clearSerial &+= 1; dirty = true
    }
    var currentBeat: Int {
        lock.lock(); defer { lock.unlock() }; return displayedBeat
    }
    private func consumeControls() {
        guard lock.try() else { return } // Keep rendering the previous state if the UI is publishing.
        defer { lock.unlock() }
        guard dirty else { return }
        tempo = pendingTempo; beats = pendingBeats; pianoVolume = pendingPiano; clickVolume = pendingClick
        running = pendingRunning
        if appliedClear != clearSerial {
            for i in voices.indices { voices[i] = Voice() }
            clickAge = 10000; appliedClear = clearSerial
        }
        if appliedReset != resetSerial {
            beat = -1; remaining = 0; clickAge = 10000; appliedReset = resetSerial
        }
        for i in 0..<97 {
            steps[i] = pendingSteps[i]
            if appliedOnsets[i] != keys[i].onset {
                voices[i].position = 0; voices[i].gain = 0; appliedOnsets[i] = keys[i].onset
            }
            voices[i].held = keys[i].held
        }
        dirty = false
    }
    func render(_ count: Int, _ buffers: UnsafeMutablePointer<AudioBufferList>) {
        consumeControls()
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
                let end = loopEnds[source - 55]
                let loopLength = loopLengths[source - 55]
                let crossfade = crossfades[source - 55]
                if voices[index].position >= end {
                    voices[index].position = end - loopLength + (voices[index].position - end).truncatingRemainder(dividingBy: loopLength)
                }
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
        if lock.try() { displayedBeat = beat; lock.unlock() }
    }
}


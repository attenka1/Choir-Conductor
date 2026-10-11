import AVFoundation
import Foundation

// A fixed sample-rate source: the engine resamples to the device format.
// Harmonics share one phase, so the steady tone has no detuned sample layers.
nonisolated final class ReferenceOscillator: @unchecked Sendable {
    private let lock = NSLock()
    private let rate = 44100.0
    private var frequency = 442.0
    private var phase = 0.0
    private var gain = 0.0
    private var held = false
    private var volume = 0.0
    private var targetVolume = 0.0
    private var volumeStep = 0.0
    private var volumeFrames = 0

    private var requestedFrequency = 442.0
    private var requestedVolume = 0.0
    private var requestedHeld = false
    private var onset: UInt64 = 0
    private var appliedOnset: UInt64 = 0
    private var dirty = false

    func play(frequency: Double) {
        lock.lock(); defer { lock.unlock() }
        requestedFrequency = frequency; requestedHeld = true; onset &+= 1; dirty = true
    }
    func setFrequency(_ value: Double) {
        lock.lock(); defer { lock.unlock() }; requestedFrequency = value; dirty = true
    }
    func setVolume(_ value: Float) {
        lock.lock(); defer { lock.unlock() }; requestedVolume = Double(value); dirty = true
    }
    func stop() {
        lock.lock(); defer { lock.unlock() }; requestedHeld = false; requestedVolume = 0; dirty = true
    }
    private func consumeControls() {
        guard lock.try() else { return }
        defer { lock.unlock() }
        guard dirty else { return }
        frequency = requestedFrequency; held = requestedHeld
        if onset != appliedOnset { phase = 0; gain = 0; appliedOnset = onset }
        if requestedVolume != targetVolume {
            targetVolume = requestedVolume
            volumeFrames = Int(rate * 0.018)
            volumeStep = (targetVolume - volume) / Double(volumeFrames)
        }
        dirty = false
    }
    func render(_ count: Int, _ buffers: UnsafeMutablePointer<AudioBufferList>) {
        consumeControls()
        let output = UnsafeMutableAudioBufferListPointer(buffers)
        for frame in 0..<count {
            if volumeFrames > 0 {
                volume += volumeStep; volumeFrames -= 1
                if volumeFrames == 0 { volume = targetVolume }
            }
            gain = held ? min(1, gain + 1 / (rate * 0.005)) : max(0, gain - 1 / (rate * 0.018))
            let angle = 2 * Double.pi * phase
            let sample = Float(0.1 * volume * gain * (0.8 * sin(angle) + 0.14 * sin(2 * angle) + 0.06 * sin(3 * angle)))
            phase += frequency / rate
            if phase >= 1 { phase -= floor(phase) }
            for buffer in output {
                if let pointer = buffer.mData?.assumingMemoryBound(to: Float.self) { pointer[frame] = sample }
            }
        }
    }
}

import Accelerate
import Foundation

nonisolated struct TunerPitch: Equatable, Sendable {
    let hz: Double

    func note(a4: Double) -> (midi: Int, cents: Double) {
        let target = target(a4: a4, temperament: .equal, root: 0, divisions: 12)
        return (Int(target.note), target.cents)
    }

    /// Find the nearest actual target frequency, including transposed historical tunings.
    func target(a4: Double, temperament: Temperament, root: Int, divisions: Int) -> (note: Double, cents: Double) {
        let approximate = 69 + 12 * log2(hz / a4)
        let step = divisions == 24 && temperament == .equal ? 0.5 : 1.0
        let center = (approximate / step).rounded() * step
        var best = (note: center, cents: Double.infinity)
        for offset in -2...2 {
            let note = center + Double(offset) * step
            let frequency = temperament.frequency(note: note, a4: a4, root: root)
            let cents = 1200 * log2(hz / frequency)
            if abs(cents) < abs(best.cents) { best = (note, cents) }
        }
        return best
    }
}

/// Single-note YIN-style detection, using the same lag and confidence rules as Android.
nonisolated final class PitchDetector {
    static let windowSize = 2048
    private let rate: Double
    private var energy = [Double](repeating: 0, count: windowSize + 1)
    private var difference = [Double](repeating: 0, count: windowSize / 2)
    private var normalized = [Double](repeating: 0, count: windowSize / 2)

    init(rate: Double) {
        self.rate = rate
    }

    func detect(_ samples: [Float], clipped: Int) -> TunerPitch? {
        let size = Self.windowSize
        guard samples.count == size, clipped <= size / 100 else { return nil }
        var sum = 0.0
        for index in samples.indices {
            let value = Double(samples[index])
            sum += value
            energy[index + 1] = energy[index] + value * value
        }
        let mean = sum / Double(size)
        guard energy[size] / Double(size) - mean * mean >= 0.003 * 0.003 else { return nil }

        let first = max(2, Int(floor(rate / 1500)))
        let last = min(difference.count - 2, Int(ceil(rate / 65)))
        var cumulative = 0.0
        samples.withUnsafeBufferPointer { buffer in
            let start = buffer.baseAddress!
            for lag in 1...(last + 1) {
                var dot: Float = 0
                vDSP_dotpr(start, 1, start + lag, 1, &dot, vDSP_Length(size - lag))
                let distance = max(0, energy[size - lag] + energy[size] - energy[lag] - 2 * Double(dot))
                difference[lag] = distance
                cumulative += distance
                normalized[lag] = cumulative > 0 ? distance * Double(lag) / cumulative : 1
            }
        }

        var lag = first
        while lag <= last {
            if normalized[lag] < 0.12 {
                while lag < last && normalized[lag + 1] < normalized[lag] { lag += 1 }
                let left = difference[lag - 1]
                let right = difference[lag + 1]
                let curvature = left - 2 * difference[lag] + right
                let adjustment = abs(curvature) > 1e-12 ? max(-0.5, min(0.5, 0.5 * (left - right) / curvature)) : 0
                let hz = rate / (Double(lag) + adjustment)
                return (65...1500).contains(hz) ? TunerPitch(hz: hz) : nil
            }
            lag += 1
        }
        return nil
    }
}

/// Serial-worker input conditioning. A windowed-sinc low-pass prevents aliases
/// before decimation; no detector work runs on the microphone callback.
nonisolated final class TunerInputProcessor {
    private let detector: PitchDetector
    private let decimation: Int
    private let hop: Int
    private let taps: [Double]
    private var history: [Float]
    private var historyIndex = 0
    private var group = 0
    private var groupClipped = false
    private var samples = [Float](repeating: 0, count: PitchDetector.windowSize)
    private var clipping = [Bool](repeating: false, count: PitchDetector.windowSize)
    private var position = 0
    private var clippedCount = 0

    init(rate: Double) {
        decimation = max(1, Int((rate / 16_000).rounded()))
        let analysisRate = rate / Double(decimation)
        detector = PitchDetector(rate: analysisRate)
        hop = max(1, Int(analysisRate * 0.05))
        let count = decimation == 1 ? 1 : 32 * decimation + 1
        let center = Double(count - 1) / 2
        let cutoff = min(0.45, 0.4 / Double(decimation))
        let coefficients = (0..<count).map { index -> Double in
            if count == 1 { return 1 }
            let x = Double(index) - center
            let sinc = x == 0 ? 2 * cutoff : sin(2 * .pi * cutoff * x) / (.pi * x)
            let window = 0.42 - 0.5 * cos(2 * .pi * Double(index) / Double(count - 1)) +
                0.08 * cos(4 * .pi * Double(index) / Double(count - 1))
            return sinc * window
        }
        let scale = coefficients.reduce(0, +)
        taps = coefficients.map { $0 / scale }
        history = Array(repeating: 0, count: count)
    }

    func reset() {
        history = Array(repeating: 0, count: history.count)
        historyIndex = 0; group = 0; position = 0; clippedCount = 0; groupClipped = false
    }

    func consume(_ input: UnsafeBufferPointer<Float>, emit: (TunerPitch?) -> Void) {
        for sample in input {
            history[historyIndex] = sample
            historyIndex = (historyIndex + 1) % history.count
            groupClipped = groupClipped || abs(sample) >= 0.998
            group += 1
            guard group == decimation else { continue }
            var value = 0.0
            for index in taps.indices {
                let source = (historyIndex + history.count - 1 - index) % history.count
                value += taps[index] * Double(history[source])
            }
            samples[position] = Float(value)
            clipping[position] = groupClipped
            if groupClipped { clippedCount += 1 }
            group = 0; groupClipped = false; position += 1
            guard position == samples.count else { continue }
            emit(detector.detect(samples, clipped: clippedCount))
            let pending = samples.count - hop
            clippedCount = 0
            for index in 0..<pending {
                samples[index] = samples[index + hop]
                clipping[index] = clipping[index + hop]
                if clipping[index] { clippedCount += 1 }
            }
            position = pending
        }
    }
}

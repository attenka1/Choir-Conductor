import Accelerate
import Foundation

nonisolated struct RecordingAnalysisConfig: Codable, Equatable, Sendable {
    var window = 8192
    var hopSeconds = 0.02
    var blockSeconds = 15.0
    var stepSeconds = 2.0
    var a4 = 440.0
    var minHz = 80.0
    var maxHz = 600.0
    var minReliability = 0.2
    var maxStepCents = 45.0
    var maxContinuousCents = 12.0

    func hop(_ rate: Int) -> Int { max(1, Int((Double(rate) * hopSeconds).rounded())) }
    func block(_ rate: Int) -> Int { max(hop(rate), Int((Double(rate) * blockSeconds).rounded())) }
    func step(_ rate: Int) -> Int { max(hop(rate), Int((Double(rate) * stepSeconds).rounded())) }
    func count(frames: Int64, rate: Int) -> Int {
        frames < block(rate) ? 0 : Int((frames - Int64(block(rate))) / Int64(step(rate))) + 1
    }
}

nonisolated struct RecordingAnalysisPoint: Codable, Equatable, Sendable {
    let frame: Int64
    let cents: Double?
    let evidence: Double
    let segment: Int
    let reason: String
}

private nonisolated struct AnalysisPartial {
    let time: Double
    let offset: Double
    let weight: Double
}

private nonisolated struct AnalysisMark {
    let time: Double
    let reason: String
}

nonisolated func analysisCircle(_ a: Double, _ b: Double) -> Double {
    let value = (a - b + 50).truncatingRemainder(dividingBy: 100)
    return (value + 100).truncatingRemainder(dividingBy: 100) - 50
}

/// Based on Android android-lab-10; v2 resets continuity after long gaps.
/// FFT uses Accelerate's double-precision complex transform.
nonisolated final class RecordingPitchAnalysis {
    static let version = "ios-android-lab-10-v2"
    private let rate: Int
    private let config: RecordingAnalysisConfig
    private let fft: FFTSetupD
    private let logSize: vDSP_Length
    private let emit: (RecordingAnalysisPoint) -> Void
    private var left: [Double]
    private var right: [Double]
    private var real: [Double]
    private var imaginary: [Double]
    private let hann: [Double]
    private var previousPhase: [Double]
    private var magnitude: [Double]
    private var havePrevious = false
    private var mixSource = -1
    private var frames: Int64 = 0
    private var nextEnd: Int64
    private var partials: [AnalysisPartial] = []
    private var marks: [AnalysisMark] = []
    private var previous: Double?
    private var lastReliable = -Double.infinity
    private var segment = -1
    private var nextIndex = 0

    init(rate: Int, config: RecordingAnalysisConfig, emit: @escaping (RecordingAnalysisPoint) -> Void) throws {
        guard (8000...192000).contains(rate), config.window >= 1024, config.window <= 65536,
              config.window.nonzeroBitCount == 1, config.a4.isFinite, (300...500).contains(config.a4),
              config.hopSeconds > 0, config.hopSeconds <= 1, config.blockSeconds >= 1,
              config.stepSeconds > 0, config.stepSeconds <= config.blockSeconds else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let logSize = vDSP_Length(log2(Double(config.window)))
        guard let fft = vDSP_create_fftsetupD(logSize, FFTRadix(kFFTRadix2)) else {
            throw CocoaError(.fileReadTooLarge)
        }
        self.fft = fft
        self.logSize = logSize
        self.rate = rate
        self.config = config
        self.emit = emit
        let size = config.window
        left = Array(repeating: 0, count: size)
        right = left
        real = left
        imaginary = left
        hann = (0..<size).map { 0.5 - 0.5 * cos(2 * .pi * Double($0) / Double(size - 1)) }
        previousPhase = Array(repeating: 0, count: size / 2 + 1)
        magnitude = previousPhase
        nextEnd = Int64(size)
    }

    deinit { vDSP_destroy_fftsetupD(fft) }

    /// Noninterleaved PCM, consumed in bounded blocks. Channels remain separate until each window is mixed.
    func accept(left inputLeft: UnsafeBufferPointer<Float>, right inputRight: UnsafeBufferPointer<Float>?) throws {
        guard inputRight == nil || inputRight!.count == inputLeft.count else { throw CocoaError(.fileReadCorruptFile) }
        for i in inputLeft.indices {
            let position = Int(frames % Int64(config.window))
            left[position] = Double(inputLeft[i])
            right[position] = Double(inputRight?[i] ?? inputLeft[i])
            frames += 1
            guard frames == nextEnd else { continue }
            try Task.checkCancellation()
            let start = frames - Int64(config.window)
            let time = (Double(start) + Double(config.window) / 2) / Double(rate)
            let reason = observe(start: start, time: time, stereo: inputRight != nil)
            marks.append(AnalysisMark(time: time, reason: reason))
            emitDue()
            nextEnd += Int64(config.hop(rate))
        }
    }

    func finish() { emitDue() }

    private func observe(start: Int64, time: Double, stereo: Bool) -> String {
        let size = config.window
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        var dot = 0.0
        var clipped = 0
        for k in 0..<size {
            let index = Int((start + Int64(k)) % Int64(size))
            let l = left[index]
            let r = right[index]
            leftEnergy += l * l
            rightEnergy += r * r
            dot += l * r
            if abs(l) >= 0.999 || abs(r) >= 0.999 { clipped += 1 }
        }
        if Double(clipped) / Double(size) > 0.01 { havePrevious = false; return "CLIPPED" }
        let denominator = sqrt(leftEnergy * rightEnergy)
        let cancel = stereo && denominator > 1e-8 && dot / denominator < -0.5
        let useRight = cancel && rightEnergy > leftEnergy
        let source = !cancel ? 0 : (useRight ? 2 : 1)
        if source != mixSource { mixSource = source; havePrevious = false }
        var power = 0.0
        var mean = 0.0
        for k in 0..<size {
            let index = Int((start + Int64(k)) % Int64(size))
            let sample = cancel ? (useRight ? right[index] : left[index]) : (left[index] + right[index]) / 2
            real[k] = sample
            mean += sample
            power += sample * sample
        }
        if sqrt(power / Double(size)) < 0.002 { havePrevious = false; return "SILENCE" }
        mean /= Double(size)
        for k in 0..<size {
            real[k] = (real[k] - mean) * hann[k]
            imaginary[k] = 0
        }
        real.withUnsafeMutableBufferPointer { re in
            imaginary.withUnsafeMutableBufferPointer { im in
                var split = DSPDoubleSplitComplex(realp: re.baseAddress!, imagp: im.baseAddress!)
                vDSP_fft_zipD(fft, &split, 1, logSize, FFTDirection(FFT_FORWARD))
            }
        }
        let lo = max(1, Int(ceil(config.minHz * Double(size) / Double(rate))))
        let hi = min(magnitude.count - 2, Int(floor(config.maxHz * Double(size) / Double(rate))))
        guard hi - lo >= 4 else { havePrevious = false; return "SUPPORT" }
        for k in lo...hi { magnitude[k] = hypot(real[k], imaginary[k]) }
        let sorted = magnitude[lo...hi].sorted()
        let threshold = max(sorted.last! * 0.05, sorted[sorted.count / 2] * 8)
        if havePrevious {
            for k in (lo + 1)..<hi {
                guard magnitude[k] > magnitude[k - 1], magnitude[k] >= magnitude[k + 1],
                      magnitude[k] >= threshold else { continue }
                let frequency = instantaneous(k)
                guard (config.minHz...config.maxHz).contains(frequency),
                      abs(1200 * log2(max(instantaneous(k - 1), 1) / frequency)) < 3,
                      abs(1200 * log2(max(instantaneous(k + 1), 1) / frequency)) < 3 else { continue }
                partials.append(AnalysisPartial(time: time,
                    offset: analysisCircle(1200 * log2(frequency / config.a4), 0),
                    weight: sqrt(magnitude[k])))
            }
        }
        for k in lo...hi { previousPhase[k] = atan2(imaginary[k], real[k]) }
        havePrevious = true
        return "OK"
    }

    private func instantaneous(_ k: Int) -> Double {
        let size = Double(config.window)
        let hop = Double(config.hop(rate))
        let expected = 2 * .pi * Double(k) * hop / size
        let phase = atan2(imaginary[k], real[k]) - previousPhase[k] - expected + .pi
        let remainder = phase.truncatingRemainder(dividingBy: 2 * .pi)
        let delta = (remainder + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi) - .pi
        return (Double(k) + delta * size / (2 * .pi * hop)) * Double(rate) / size
    }

    private func emitDue() {
        let count = config.count(frames: frames, rate: rate)
        while nextIndex < count {
            let center = Int64(config.block(rate) / 2) + Int64(nextIndex) * Int64(config.step(rate))
            let half = Double(config.block(rate)) / 2 / Double(rate)
            let time = Double(center) / Double(rate)
            let start = time - half
            let end = time + half
            // Prune once per output point, keeping memory bounded by the analysis block.
            partials.removeAll { $0.time < start }
            marks.removeAll { $0.time < start }
            emit(estimate(frame: center, start: start, end: end))
            nextIndex += 1
        }
    }

    private func estimate(frame: Int64, start: Double, end: Double) -> RecordingAnalysisPoint {
        let chosen = partials.filter { $0.time >= start && $0.time < end }
        let windowMarks = marks.filter { $0.time >= start && $0.time < end }
        guard chosen.count >= 5 else {
            let reason: String
            if !windowMarks.isEmpty && windowMarks.allSatisfy({ $0.reason == "SILENCE" }) { reason = "SILENCE" }
            else if windowMarks.contains(where: { $0.reason == "CLIPPED" }) { reason = "CLIPPED" }
            else { reason = "SUPPORT" }
            return RecordingAnalysisPoint(frame: frame, cents: nil, evidence: 0, segment: segment, reason: reason)
        }
        var re = 0.0
        var im = 0.0
        var weight = 0.0
        for partial in chosen {
            let angle = 2 * .pi * partial.offset / 100
            re += partial.weight * cos(angle)
            im += partial.weight * sin(angle)
            weight += partial.weight
        }
        let mean = atan2(im, re) * 50 / .pi
        let reliability = weight > 0 ? min(1, hypot(re, im) / weight) : 0
        guard reliability >= config.minReliability else {
            return RecordingAnalysisPoint(frame: frame, cents: nil, evidence: reliability, segment: segment, reason: "SUPPORT")
        }
        let time = (start + end) / 2
        if previous == nil || time - lastReliable > config.blockSeconds {
            segment += 1
            previous = nil
        }
        var cents = mean
        if let previous {
            var target = previous + analysisCircle(mean, previous)
            if target - previous > config.maxStepCents { target -= 100 }
            cents = previous + min(config.maxContinuousCents, max(-config.maxContinuousCents, target - previous))
        }
        previous = cents
        lastReliable = time
        return RecordingAnalysisPoint(frame: frame, cents: cents, evidence: reliability, segment: segment, reason: "OK")
    }
}

/// Bounded chart projection, preserving missing observations and segment boundaries.
nonisolated final class RecordingAnalysisProjection {
    private let width: Int
    private var bucket: [RecordingAnalysisPoint] = []
    private(set) var points: [RecordingAnalysisPoint] = []
    private(set) var total = 0
    private(set) var valid = 0
    private(set) var segments = 0

    init(frames: Int64, rate: Int, config: RecordingAnalysisConfig) {
        width = max(1, Int((frames / Int64(config.step(rate)) + 1199) / 1200))
    }

    func add(_ point: RecordingAnalysisPoint) {
        total += 1
        if point.cents != nil { valid += 1 }
        segments = max(segments, point.segment + 1)
        bucket.append(point)
        if bucket.count >= width { flush() }
    }

    func flush() {
        guard let first = bucket.first else { return }
        if let gap = bucket.first(where: { $0.cents == nil }) { points.append(gap) }
        else if bucket.contains(where: { $0.segment != first.segment }) {
            points.append(RecordingAnalysisPoint(frame: first.frame, cents: nil, evidence: 0, segment: first.segment, reason: "SEGMENT"))
        } else {
            points.append(RecordingAnalysisPoint(frame: first.frame,
                cents: bucket.reduce(0) { $0 + ($1.cents ?? 0) } / Double(bucket.count),
                evidence: bucket.map(\.evidence).min() ?? 0, segment: first.segment, reason: first.reason))
        }
        bucket.removeAll(keepingCapacity: true)
    }
}

import Foundation

func signal(_ hz: Double, rate: Double, fundamental: Double = 0.5,
            second: Double = 0, third: Double = 0, dc: Double = 0) -> [Float] {
    (0..<PitchDetector.windowSize).map {
        let phase = 2 * Double.pi * hz * Double($0) / rate
        return Float(dc + fundamental * sin(phase) + second * sin(2 * phase) + third * sin(3 * phase))
    }
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

for rate in [14_700.0, 16_000.0] {
    let detector = PitchDetector(rate: rate)
    for hz in [65.41, 82.41, 110, 220, 440, 442, 659.25, 880, 1318.51] {
        let pitch = detector.detect(signal(hz, rate: rate), clipped: 0)
        check(pitch.map { abs(1200 * log2($0.hz / hz)) < 5 } ?? false, "Sustained tone \(hz) at \(rate)")
    }
    for hz in [110.0, 220, 440] {
        let pitch = detector.detect(signal(hz, rate: rate, fundamental: 0.08, second: 0.45, third: 0.2), clipped: 0)
        check(pitch.map { abs(1200 * log2($0.hz / hz)) < 5 } ?? false, "Overtones at \(hz)")
    }
    let size = PitchDetector.windowSize
    check(detector.detect(Array(repeating: 0, count: size), clipped: 0) == nil, "Silence")
    check(detector.detect(Array(repeating: 0.04, count: size), clipped: 0) == nil, "DC offset")
    var seed: UInt32 = 17
    let noise = (0..<size).map { _ -> Float in
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(Double(seed) / Double(UInt32.max) - 0.5)
    }
    check(detector.detect(noise, clipped: 0) == nil, "Noise")
    check(detector.detect(signal(440, rate: rate), clipped: size) == nil, "Clipping")
    let pitch = detector.detect(signal(442, rate: rate, dc: 0.15), clipped: 0)!
    check(pitch.note(a4: 442).midi == 69 && abs(pitch.note(a4: 442).cents) < 1, "A4 calibration")
    check(abs(pitch.note(a4: 440).cents - 7.85) < 1, "A4 offset")
    check(TunerPitch(hz: 884).note(a4: 442).midi == 81, "Octave")
}

print("PASS: pitch range, overtones, silence, DC, noise, clipping, A4 and octave at 14.7 and 16 kHz")

for temperament in Temperament.allCases {
    for root in 0..<12 {
        for note in 36...84 {
            let hz = temperament.frequency(note: Double(note), a4: 442, root: root)
            let target = TunerPitch(hz: hz).target(a4: 442, temperament: temperament, root: root, divisions: 12)
            check(target.note == Double(note) && abs(target.cents) < 0.000001, "Temperament target \(temperament), root \(root), note \(note)")
        }
    }
}
let justE = Temperament.just.frequency(note: 64, a4: 440, root: 0)
check(abs(TunerPitch(hz: justE).target(a4: 440, temperament: .just, root: 0, divisions: 12).cents) < 0.000001, "Pure major third is in tune")
let quarter = Temperament.equal.frequency(note: 69.5, a4: 442, root: 0)
check(TunerPitch(hz: quarter).target(a4: 442, temperament: .equal, root: 0, divisions: 24).note == 69.5, "Quarter tone target")

for rate in [44100.0, 48000.0, 96000.0] {
    func processed(_ fundamental: Double, high: Double) -> [TunerPitch?] {
        let processor = TunerInputProcessor(rate: rate)
        var readings: [TunerPitch?] = []
        // This high-frequency tone would alias to 440 Hz with unfiltered decimation.
        let decimation = max(1, Int((rate / 16000).rounded()))
        let aliasHz = rate / Double(decimation) - 440
        let input = (0..<Int(rate / 2)).map { index -> Float in
            let t = Double(index) / rate
            return Float(fundamental * sin(2 * .pi * 440 * t) + high * sin(2 * .pi * aliasHz * t))
        }
        input.withUnsafeBufferPointer { buffer in
            for start in stride(from: 0, to: buffer.count, by: 137) {
                processor.consume(UnsafeBufferPointer(rebasing: buffer[start..<min(start + 137, buffer.count)])) { readings.append($0) }
            }
        }
        return readings
    }
    check(processed(0, high: 0.7).suffix(3).allSatisfy { $0 == nil }, "Reject aliased high-frequency input at \(rate)")
    let pitches = processed(0.1, high: 0.7).suffix(3)
    check(pitches.count == 3 && pitches.allSatisfy { $0.map { abs(1200 * log2($0.hz / 440)) < 5 } ?? false }, "Find voice beneath high-frequency input at \(rate)")
}
print("PASS: all temperament/root targets, quarter tones, pure third and filtered streaming input at 44.1/48/96 kHz")

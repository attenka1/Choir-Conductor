import AVFoundation
import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}
let rate = 22050
let config = RecordingAnalysisConfig(hopSeconds: 0.1, blockSeconds: 3, stepSeconds: 0.5)
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ChoirAnalysisChecks-" + UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }

func fixture(_ name: String, seconds: Int = 12) -> [Float] {
    var phases = [Double](repeating: 0, count: 4)
    let notes = [48, 52, 55, 59]
    var samples = [Float](repeating: 0, count: rate * seconds)
    for i in samples.indices {
        let time = Double(i) / Double(rate)
        if name == "gap" && time >= 4 && time < 12 { continue }
        let drift = name == "fall" ? -120 * time / Double(seconds) : (name == "gap" && time >= 12 ? 48.0 : 0.0)
        var value = 0.0
        for voice in 0..<4 {
            let frequency = 440 * pow(2, Double(notes[voice] - 69) / 12 + drift / 1200)
            phases[voice] += frequency * 2 * .pi / Double(rate)
            for harmonic in 1...5 {
                value += sin(Double(harmonic) * phases[voice] + Double(voice) * 0.2) / pow(Double(harmonic), 1.4) / 12
            }
        }
        // Quantize identically to Android PCM16.
        samples[i] = Float(Int16(value * 32767)) / 32768
    }
    return samples
}

func analyze(_ samples: [Float], right: [Float]? = nil, block: Int = 16384,
             cfg: RecordingAnalysisConfig = config) throws -> [RecordingAnalysisPoint] {
    var points: [RecordingAnalysisPoint] = []
    let analysis = try RecordingPitchAnalysis(rate: rate, config: cfg) { points.append($0) }
    try samples.withUnsafeBufferPointer { leftBuffer in
        func consume(_ rightBuffer: UnsafeBufferPointer<Float>?) throws {
            for start in stride(from: 0, to: samples.count, by: block) {
                let end = min(samples.count, start + block)
                let leftSlice = UnsafeBufferPointer(rebasing: leftBuffer[start..<end])
                let rightSlice = rightBuffer.map { UnsafeBufferPointer(rebasing: $0[start..<end]) }
                try analysis.accept(left: leftSlice, right: rightSlice)
            }
        }
        if let right { try right.withUnsafeBufferPointer { try consume($0) } }
        else { try consume(nil) }
    }
    analysis.finish()
    return points
}

let stablePCM = fixture("stable")
let stable = try analyze(stablePCM)
check(stable.count == config.count(frames: Int64(stablePCM.count), rate: rate), "Point grid")
check(stable.filter { $0.cents != nil }.count >= stable.count * 9 / 10, "Stable coverage")
check(stable.compactMap(\.cents).allSatisfy { abs($0) < 5 }, "Stable tuning")
let fallPCM = fixture("fall")
let fall = try analyze(fallPCM)
let chunkedFall = try analyze(fallPCM, block: 137)
check(fall == chunkedFall, "Arbitrary block boundaries")
check((fall.last?.cents ?? 0) < -50, "Unwrap fall")
let errors = fall.compactMap { point -> Double? in
    point.cents.map { abs($0 + 120 * Double(point.frame) / Double(rate) / 12) }
}.sorted()
check(!errors.isEmpty && errors[errors.count / 2] < 8, "Fall error")
let inverted = try analyze(stablePCM, right: stablePCM.map { -$0 })
check(inverted == stable, "Inverted stereo")
let clipped = try analyze(stablePCM, right: Array(repeating: -1, count: stablePCM.count))
check(clipped.allSatisfy { $0.cents == nil && $0.reason == "CLIPPED" }, "Clipped channel")
let silence = try analyze(Array(repeating: 0, count: rate * 4))
check(!silence.isEmpty && silence.allSatisfy { $0.cents == nil && $0.reason == "SILENCE" }, "Silence")
let gapPCM = fixture("gap", seconds: 16)
let gap = try analyze(gapPCM)
let early = gap.filter { $0.cents != nil && $0.frame < rate * 4 }
let late = gap.filter { $0.cents != nil && $0.frame > rate * 14 }
check(!early.isEmpty && !late.isEmpty && early.last!.segment != late.first!.segment, "Gap segments")
let resumed = gap.first { $0.cents != nil && $0.segment == late.first!.segment }
check(resumed.map { abs(($0.cents ?? 0) - 48) < 5 } ?? false, "New segment starts at its observed pitch, not the previous segment")
let calibrated = try analyze(stablePCM, cfg: RecordingAnalysisConfig(hopSeconds: 0.1, blockSeconds: 3, stepSeconds: 0.5, a4: 442))
check(calibrated.compactMap(\.cents).allSatisfy { abs($0 - 1200 * log2(440.0 / 442)) < 5 }, "A4 calibration")
let production = try analyze(fixture("stable", seconds: 18), cfg: RecordingAnalysisConfig())
check(production.count == 2 && production.allSatisfy { $0.cents != nil }, "Production block and hop")
let projection = RecordingAnalysisProjection(frames: 48000 * 3600, rate: 48000, config: RecordingAnalysisConfig())
for i in 0..<1800 {
    projection.add(RecordingAnalysisPoint(frame: Int64(i * 96000), cents: i == 450 ? nil : 1, evidence: 0.8,
                                         segment: i < 900 ? 0 : 1, reason: "OK"))
}
projection.flush()
check(projection.points.count <= 1200 && projection.points.contains { $0.cents == nil }, "Bounded projection")
check(projection.valid == 1799 && projection.segments == 2, "Projection summary")

// Expose identical PCM and expected Swift observations for the independent Android cross-check.
if CommandLine.arguments.count > 1 {
    let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    for (name, pcm, points) in [("stable", stablePCM, stable), ("fall", fallPCM, fall), ("gap", gapPCM, gap)] {
        var data = Data()
        for sample in pcm {
            var value = Int16((sample * 32768).rounded()).littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        try data.write(to: output.appendingPathComponent(name + ".pcm"))
        try JSONEncoder().encode(points).write(to: output.appendingPathComponent(name + ".json"))
    }
}

// Exercise decoding and cache invalidation through the production file entry point.
let audio = directory.appendingPathComponent("test.wav")
let format = AVAudioFormat(standardFormatWithSampleRate: Double(rate), channels: 1)!
let longPCM = fixture("stable", seconds: 18)
func writeAudio(_ samples: [Float]) throws {
    let file = try AVAudioFile(forWriting: audio, settings: format.settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
    buffer.frameLength = buffer.frameCapacity
    samples.withUnsafeBufferPointer { source in
        buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
    }
    try file.write(from: buffer)
}
try writeAudio(longPCM)
let store = RecordingAnalysisStore(source: audio)
let original = try store.resolve(a4: 440) { _ in }
check(original.total == 2 && original.valid == 2, "File decode")
let reopened = try store.resolve(a4: 440) { _ in }
check(original.points == reopened.points, "Cache reopen")
let shifted = try store.resolve(a4: 442) { _ in }
check(shifted.config.a4 == 442 && shifted.points != original.points, "Cache A4 invalidation")
try Data("broken".utf8).write(to: store.cache)
let recovered = try store.resolve(a4: 440) { _ in }
check(recovered.points == original.points, "Corrupt cache recovery")
try writeAudio(Array(repeating: 0, count: longPCM.count))
let changed = try store.resolve(a4: 440) { _ in }
check(changed.sourceHash != original.sourceHash && changed.valid == 0, "Source hash invalidation")
try writeAudio(Array(repeating: 0, count: rate * 2))
let short = try store.resolve(a4: 440) { _ in }
check(short.total == 0 && short.points.isEmpty, "Short recording")
// Existing app recordings are AAC/M4A. Verify the same decoder entry point.
let m4a = directory.appendingPathComponent("existing.m4a")
do {
    let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100,
                                   AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128000]
    let file = try AVAudioFile(forWriting: m4a, settings: settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(longPCM.count * 2))!
    buffer.frameLength = buffer.frameCapacity
    for index in longPCM.indices {
        buffer.floatChannelData![0][index * 2] = longPCM[index]
        buffer.floatChannelData![0][index * 2 + 1] = longPCM[index]
    }
    try file.write(from: buffer)
}
if CommandLine.arguments.count > 1 {
    let exported = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("existing.m4a")
    try? FileManager.default.removeItem(at: exported)
    try FileManager.default.copyItem(at: m4a, to: exported)
}
let aac = try RecordingAnalysisStore(source: m4a).resolve(a4: 440) { _ in }
check(aac.total >= 2 && aac.valid >= 2, "Existing M4A analysis")
check(aac.points.compactMap(\.cents).allSatisfy { abs($0) < 5 }, "AAC pitch")

let cachedData = try Data(contentsOf: store.cache)
let cancelled = Task.detached {
    withUnsafeCurrentTask { $0?.cancel() }
    return try store.resolve(a4: 442) { _ in }
}
do {
    _ = try await cancelled.value
    fatalError("Cancellation was ignored")
} catch is CancellationError {}
let afterCancellation = try Data(contentsOf: store.cache)
check(cachedData == afterCancellation, "Cancellation preserves published cache")
print("PASS: tuning, drift, stereo, clipping, gaps, A4, production settings, projection, file decode and cache invalidation")

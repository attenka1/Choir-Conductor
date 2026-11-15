import AVFoundation
import CryptoKit
import Foundation

nonisolated struct RecordingAnalysisResult: Codable, Sendable {
    let version: String
    let sourceHash: String
    let config: RecordingAnalysisConfig
    let rate: Int
    let channels: Int
    let frames: Int64
    let total: Int
    let valid: Int
    let segments: Int
    let points: [RecordingAnalysisPoint]

    var coverage: Double { total == 0 ? 0 : Double(valid) / Double(total) }
    var duration: Double { Double(frames) / Double(rate) }

    func matches(hash: String, config: RecordingAnalysisConfig, rate: Int, channels: Int, frames: Int64) -> Bool {
        guard version == RecordingPitchAnalysis.version, sourceHash == hash, self.config == config,
              self.rate == rate, self.channels == channels, self.frames == frames,
              total == config.count(frames: frames, rate: rate), valid >= 0, valid <= total,
              segments >= 0, segments <= total, points.count <= 1200,
              (total == 0) == points.isEmpty else { return false }
        var previousFrame: Int64 = -1
        for point in points {
            guard point.frame > previousFrame, point.frame >= 0, point.frame <= frames,
                  point.cents?.isFinite ?? true, point.evidence.isFinite, (0...1).contains(point.evidence),
                  point.segment >= -1, point.segment < max(1, segments) else { return false }
            previousFrame = point.frame
        }
        return true
    }
}

nonisolated struct RecordingAnalysisStore {
    let source: URL
    var cache: URL {
        source.deletingLastPathComponent().appendingPathComponent("Analysis", isDirectory: true)
            .appendingPathComponent(source.deletingPathExtension().lastPathComponent + ".json")
    }

    func resolve(a4: Double, progress: (Double) -> Void) throws -> RecordingAnalysisResult {
        let config = RecordingAnalysisConfig(a4: a4)
        let file = try AVAudioFile(forReading: source, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        let rate = Int(format.sampleRate.rounded())
        guard (8000...192000).contains(rate), (1...2).contains(format.channelCount),
              file.length > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let hash = try fingerprint { progress($0 * 0.1) }
        try Task.checkCancellation()
        let cacheBytes = (try? cache.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if cacheBytes > 0, cacheBytes <= 2_000_000,
           let data = try? Data(contentsOf: cache),
           let result = try? JSONDecoder().decode(RecordingAnalysisResult.self, from: data),
           result.matches(hash: hash, config: config, rate: rate, channels: Int(format.channelCount), frames: file.length) {
            progress(1)
            return result
        }
        let projection = RecordingAnalysisProjection(frames: file.length, rate: rate, config: config)
        let analyzer = try RecordingPitchAnalysis(rate: rate, config: config, emit: projection.add)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384) else {
            throw CocoaError(.fileReadTooLarge)
        }
        while file.framePosition < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: 16384)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let count = Int(buffer.frameLength)
            let left = UnsafeBufferPointer(start: channels[0], count: count)
            let right = format.channelCount == 2 ? UnsafeBufferPointer(start: channels[1], count: count) : nil
            try analyzer.accept(left: left, right: right)
            progress(0.1 + 0.9 * Double(file.framePosition) / Double(file.length))
        }
        analyzer.finish()
        projection.flush()
        try Task.checkCancellation()
        // Guard publication against a changed source while decoding.
        let finalHash = try fingerprint { _ in }
        guard hash == finalHash else { throw CocoaError(.fileReadCorruptFile) }
        let result = RecordingAnalysisResult(version: RecordingPitchAnalysis.version, sourceHash: hash,
            config: config, rate: rate, channels: Int(format.channelCount), frames: file.length,
            total: projection.total, valid: projection.valid, segments: projection.segments, points: projection.points)
        try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(result)
        try Task.checkCancellation()
        try data.write(to: cache, options: .atomic)
        progress(1)
        return result
    }

    private func fingerprint(progress: (Double) -> Void) throws -> String {
        let handle = try FileHandle(forReadingFrom: source)
        defer { try? handle.close() }
        let length = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        var digest = SHA256()
        var count: UInt64 = 0
        while true {
            try Task.checkCancellation()
            guard let data = try handle.read(upToCount: 65536), !data.isEmpty else { break }
            digest.update(data: data)
            count += UInt64(data.count)
            progress(Double(count) / Double(max(1, length)))
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

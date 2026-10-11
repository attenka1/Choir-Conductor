import Foundation

nonisolated struct PianoSampleMetadata: Decodable {
    let midi: Int
    let filename: String
    let fundamentalHz: Double
    let sampleRate: Int
    let channels: Int
    let frames: Int
    let loopEndFrame: Int
    let loopLengthFrames: Double
    let crossfadeFrames: Int

    static func load(from url: URL) throws -> [PianoSampleMetadata] {
        let items = try JSONDecoder().decode([PianoSampleMetadata].self, from: Data(contentsOf: url))
        guard items.map(\.midi) == Array(55...79), items.allSatisfy({
            $0.filename == "note_\($0.midi).wav" && $0.fundamentalHz.isFinite && $0.fundamentalHz > 0 &&
            $0.sampleRate == 44100 && $0.channels > 0 && $0.frames > 2 &&
            $0.loopEndFrame > 0 && $0.loopEndFrame <= $0.frames - 2 &&
            $0.loopLengthFrames.isFinite && $0.loopLengthFrames > 0 && $0.loopLengthFrames < Double($0.loopEndFrame) &&
            $0.crossfadeFrames > 0 && Double($0.crossfadeFrames) <= $0.loopLengthFrames &&
            Double($0.loopEndFrame - $0.crossfadeFrames) >= $0.loopLengthFrames
        }) else { throw CocoaError(.fileReadCorruptFile) }
        return items
    }
}

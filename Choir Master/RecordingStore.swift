import Foundation

nonisolated struct RehearsalRecording: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    let date: Date
    var duration: Double
    var fileExtension: String = "m4a"
    static let supportedExtensions: Set<String> = ["m4a", "wav", "mp3", "aiff", "aif", "caf", "flac", "aac", "mp4"]
    var filename: String { id.uuidString + "." + fileExtension }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100 &&
        duration.isFinite && duration >= 0 && date.timeIntervalSince1970.isFinite &&
        Self.supportedExtensions.contains(fileExtension)
    }
}

nonisolated struct RecordingStore {
    let directory: URL
    var index: URL { directory.appendingPathComponent("index.json") }
    func url(_ item: RehearsalRecording) -> URL { directory.appendingPathComponent(item.filename) }
    func load() throws -> [RehearsalRecording] {
        guard FileManager.default.fileExists(atPath: index.path) else { return [] }
        let items = try JSONDecoder().decode([RehearsalRecording].self, from: Data(contentsOf: index))
        try validate(items)
        return items
    }
    func save(_ items: [RehearsalRecording]) throws {
        try validate(items)
        try JSONEncoder().encode(items).write(to: index, options: .atomic)
    }
    private func validate(_ items: [RehearsalRecording]) throws {
        guard items.allSatisfy(\.isValid), Set(items.map(\.id)).count == items.count else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
}

// Existing recording indexes contain no extension; preserve their original M4A paths.
extension RehearsalRecording {
    nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try values.decode(UUID.self, forKey: .id),
                  name: try values.decode(String.self, forKey: .name),
                  date: try values.decode(Date.self, forKey: .date),
                  duration: try values.decode(Double.self, forKey: .duration),
                  fileExtension: try values.decodeIfPresent(String.self, forKey: .fileExtension) ?? "m4a")
    }
}

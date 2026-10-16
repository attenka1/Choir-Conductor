import Foundation

struct RehearsalRecording: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let date: Date
    var duration: Double
    var filename: String { id.uuidString + ".m4a" }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100 &&
        duration.isFinite && duration >= 0 && date.timeIntervalSince1970.isFinite
    }
}

struct RecordingStore {
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

import Foundation

struct SavedChord: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var notes: [Double]
    var tuning: Double
    var temperament: Temperament
    var root: Int
    var divisions: Int

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80 &&
        !notes.isEmpty && notes.count <= 97 && Set(notes).count == notes.count &&
        notes.allSatisfy { $0.isFinite && (36...84).contains($0) && $0 * 2 == ($0 * 2).rounded() && (divisions == 24 || $0 == $0.rounded()) } &&
        tuning.isFinite && (300...500).contains(tuning) && (0..<12).contains(root) &&
        [12,24].contains(divisions) && (divisions == 12 || temperament == .equal)
    }
}

enum ChordStore {
    static let key = "savedChords.v1"
    static func load(from defaults: UserDefaults) throws -> [SavedChord] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let chords = try JSONDecoder().decode([SavedChord].self, from: data)
        try validate(chords)
        return chords
    }
    static func save(_ chords: [SavedChord], to defaults: UserDefaults) throws {
        try validate(chords)
        defaults.set(try JSONEncoder().encode(chords), forKey: key)
    }
    private static func validate(_ chords: [SavedChord]) throws {
        guard chords.allSatisfy(\.isValid), Set(chords.map(\.id)).count == chords.count else {
            throw NSError(domain: "ChoirChords", code: 1, userInfo: [NSLocalizedDescriptionKey: T("Soinnun nimi, sävelet tai viritysasetukset eivät kelpaa.")])
        }
    }
}

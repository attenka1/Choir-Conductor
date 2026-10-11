import Foundation

enum NoteNaming {
    static func pitchClasses(international: Bool, temperament: Temperament = .equal, root: Int = 0) -> [String] {
        var names = international ? ["C","C♯","D","E♭","E","F","F♯","G","G♯","A","B♭","B"] : ["C","C♯","D","Es","E","F","Fis","G","Gis","A","B","H"]
        if temperament == .just {
            // Spell the explicitly chosen 5-limit chromatic extension as scale intervals.
            let rootFifth = (-3...8).first { (($0 * 7) % 12 + 12) % 12 == root }!
            let rootLetter = (rootFifth * 4 % 7 + 7) % 7
            let letters = ["C", "D", "E", "F", "G", "A", international ? "B" : "H"]
            let natural = [0, 2, 4, 5, 7, 9, 11]
            let degrees = [0, 1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6]
            for relative in 0..<12 {
                let letterIndex = (rootLetter + degrees[relative]) % 7
                let pitchClass = (root + relative) % 12
                let accidental = (pitchClass - natural[letterIndex] + 18) % 12 - 6
                let letter = letters[letterIndex]
                let suffix = accidental >= 0 ? String(repeating: "♯", count: accidental) : String(repeating: "♭", count: -accidental)
                names[pitchClass] = !international && letter == "H" && accidental == -1 ? "B" : letter + suffix
            }
            return names
        }
        guard temperament.usesOpenChain else { return names }
        // Spelling follows the same transposed E-flat ... G-sharp fifth chain as the tuning.
        let rootFifth = (-3...8).first { (($0 * 7) % 12 + 12) % 12 == root }!
        let letters = ["C", "G", "D", "A", "E", international ? "B" : "H", "F"]
        for relative in -3...8 {
            let fifth = rootFifth + relative
            let letter = letters[(fifth % 7 + 7) % 7]
            let accidental = Int(floor(Double(fifth + 1) / 7))
            let suffix = accidental >= 0 ? String(repeating: "♯", count: accidental) : String(repeating: "♭", count: -accidental)
            let spelling = !international && letter == "H" && accidental == -1 ? "B" : letter + suffix
            names[(fifth * 7 % 12 + 12) % 12] = spelling
        }
        return names
    }
    static func label(_ note: Double, names: [String]) -> String {
        let midi = Int(note.rounded(.down))
        return names[midi % 12] + String(midi / 12 - 1) + (note == Double(midi) ? "" : "↑")
    }
}

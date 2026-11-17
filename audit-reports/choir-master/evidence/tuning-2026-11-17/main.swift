import Foundation

let tunings = [300.0, 415.0, 440.0, 442.0, 500.0]
for system in Temperament.allCases {
    for root in 0..<12 {
        for note in stride(from: 36.0, through: 84.0, by: 0.5) {
            let frequency = system.frequency(note: note, a4: 442, root: root)
            print(String(format: "F\t%@\t%d\t%.1f\t%.12f", system.rawValue, root, note, frequency))
        }
        for a4 in tunings {
            let anchor = system.frequency(note: 69, a4: a4, root: root)
            print(String(format: "A\t%@\t%d\t%.1f\t%.12f", system.rawValue, root, a4, anchor))
        }
    }
}
for international in [false, true] {
    for system in Temperament.allCases {
        for root in 0..<12 {
            let names = NoteNaming.pitchClasses(international: international, temperament: system, root: root)
            for pc in 0..<12 {
                print("N\t\(international)\t\(system.rawValue)\t\(root)\t\(pc)\t\(names[pc])")
            }
        }
    }
}
for midi in [36, 60, 69, 84] {
    let names = NoteNaming.pitchClasses(international: true)
    print("L\t\(midi)\t\(NoteNaming.label(Double(midi), names: names))")
    print("L\t\(midi).5\t\(NoteNaming.label(Double(midi) + 0.5, names: names))")
}

var worstFloat = 0.0
var worstReplay = 0.0
for system in Temperament.allCases {
    for root in 0..<12 {
        for note in stride(from: 36.0, through: 84.0, by: 0.5) {
            for a4 in tunings where system == .equal || note == note.rounded() {
                let cents = 1200 * log2(a4 / 440) + system.correction(note: note, root: root) + (note - note.rounded()) * 100
                let quantized = Double(Float(cents))
                worstFloat = max(worstFloat, abs(quantized - cents))
                let replay = 440 * pow(2, (note.rounded() - 69) / 12 + quantized / 1200)
                let target = system.frequency(note: note, a4: a4, root: root)
                worstReplay = max(worstReplay, abs(1200 * log2(replay / target)))
            }
        }
    }
}
print(String(format: "Q\t%.12f\t%.12f", worstFloat, worstReplay))

let detectorCases: [(Temperament, Int, Double)] = Temperament.allCases.flatMap { system in
    (0..<12).flatMap { root in [36.0, 60.0, 69.0, 70.0, 76.0, 84.0].map { (system, root, $0) } }
}
for item in detectorCases {
    let hz = item.0.frequency(note: item.2, a4: 442, root: item.1)
    let found = TunerPitch(hz: hz).target(a4: 442, temperament: item.0, root: item.1, divisions: 12)
    print(String(format: "T\t%@\t%d\t%.1f\t%.1f\t%.12f", item.0.rawValue, item.1, item.2, found.note, found.cents))
}
for note in stride(from: 48.0, through: 72.0, by: 0.5) {
    let hz = Temperament.equal.frequency(note: note, a4: 442, root: 0)
    let found = TunerPitch(hz: hz).target(a4: 442, temperament: .equal, root: 0, divisions: 24)
    print(String(format: "H\t%.1f\t%.1f\t%.12f", note, found.note, found.cents))
}
print("PASS")

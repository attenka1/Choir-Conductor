import Foundation
func near(_ actual: Double, _ expected: Double) { precondition(abs(actual - expected) < 0.0000001, "\(actual) != \(expected)") }
for root in 0..<12 {
    for system in Temperament.allCases {
        near(system.frequency(note: 69, a4: 442, root: root), 442)
        for note in 36...72 {
            near(system.frequency(note: Double(note + 12), a4: 415, root: root) / system.frequency(note: Double(note), a4: 415, root: root), 2)
        }
    }
    let tonic = Double(60 + root)
    for system in [Temperament.just, .kirnbergerIII] {
        near(system.frequency(note: tonic + 4, a4: 442, root: root) / system.frequency(note: tonic, a4: 442, root: root), 1.25)
    }
    near(Temperament.just.frequency(note: tonic + 3, a4: 442, root: root) / Temperament.just.frequency(note: tonic, a4: 442, root: root), 1.2)
    near(Temperament.just.frequency(note: tonic + 7, a4: 442, root: root) / Temperament.just.frequency(note: tonic, a4: 442, root: root), 1.5)
    // Published characteristic major-third sizes; independent of A4 normalization.
    func thirdCents(_ system: Temperament) -> Double {
        1200 * log2(system.frequency(note: tonic + 4, a4: 442, root: root) / system.frequency(note: tonic, a4: 442, root: root))
    }
    precondition(abs(thirdCents(.werckmeisterIII) - 390.225) < 0.001)
    precondition(abs(thirdCents(.vallotti) - 392.180) < 0.001)
    for system in [Temperament.werckmeisterIII, .kirnbergerIII, .vallotti] {
        // All twelve fifths, including the closing fifth, avoid the open-chain wolf.
        for degree in 0..<12 {
            let low = tonic + Double(degree)
            let cents = 1200 * log2(system.frequency(note: low + 7, a4: 442, root: root) / system.frequency(note: low, a4: 442, root: root))
            precondition((695...703).contains(cents))
        }
    }
    near(Temperament.pythagorean.frequency(note: tonic + 7, a4: 442, root: root) / Temperament.pythagorean.frequency(note: tonic, a4: 442, root: root), 1.5)
    near(Temperament.quarterComma.frequency(note: tonic + 4, a4: 442, root: root) / Temperament.quarterComma.frequency(note: tonic, a4: 442, root: root), 1.25)
}
near(Temperament.equal.frequency(note: 69.5, a4: 442, root: 0) / 442, pow(2, 1.0 / 24))
print("PASS: A4 anchor, octaves, pure fifths, meantone thirds, 24-EDO across all roots")

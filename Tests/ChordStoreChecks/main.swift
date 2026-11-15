import Foundation
let suite = "ChoirChordChecks-" + UUID().uuidString
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let chord = SavedChord(name: "C-duuri", notes: [60,64,67], tuning: 442, temperament: .just, root: 0, divisions: 12)
precondition(chord.isValid)
try ChordStore.save([chord], to: defaults)
let loadedFirst = try ChordStore.load(from: defaults)
precondition(loadedFirst == [chord])
let quarter = SavedChord(name: "Neljäsosasävelet", notes: [60,60.5,69.5], tuning: 415, temperament: .equal, root: 0, divisions: 24)
try ChordStore.save([chord,quarter], to: defaults)
let loadedBoth = try ChordStore.load(from: defaults)
precondition(loadedBoth == [chord,quarter])
var invalid = chord
for notes in [[35.0], [84.5], [60.25], [60.5], [60,60], []] {
    invalid.notes = notes
    do { try ChordStore.save([invalid], to: defaults); fatalError("Invalid notes were saved") } catch {}
}
let afterInvalid = try ChordStore.load(from: defaults)
precondition(afterInvalid == [chord,quarter], "Rejected write altered existing records")
invalid = chord; invalid.tuning = 600; precondition(!invalid.isValid)
invalid = chord; invalid.root = 12; precondition(!invalid.isValid)
invalid = chord; invalid.name = " "; precondition(!invalid.isValid)
defaults.set(Data("broken json".utf8), forKey: ChordStore.key)
do { _ = try ChordStore.load(from: defaults); fatalError("Corruption was accepted") } catch {}
let original = defaults.data(forKey: ChordStore.key)
do { try ChordStore.save([], to: defaults); fatalError("Corrupt store was overwritten") } catch {}
precondition(defaults.data(forKey: ChordStore.key) == original)
precondition(defaults.data(forKey: ChordStore.key + ".unreadableBackup") == original)
// Restore an explicitly recovered valid payload, then resume normal writes.
defaults.set(try JSONEncoder().encode([chord]), forKey: ChordStore.key)
try ChordStore.save([], to: defaults)
let empty = try ChordStore.load(from: defaults)
precondition(empty.isEmpty)
print("PASS: chord profiles and quarter tones persist; invalid writes preserve data; corruption detected")

import Foundation
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ChoirRecordingChecks-" + UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let store = RecordingStore(directory: directory)
let initial = try store.load(); precondition(initial.isEmpty)
let item = RehearsalRecording(id: UUID(), name: "Harjoitus / ../../nimi", date: Date(), duration: 123.5)
precondition(store.url(item).deletingLastPathComponent().path == directory.path, "User names must never become paths")
try store.save([item])
let loaded = try store.load(); precondition(loaded == [item])
var changed = item; changed.name = "Kyrie"; try store.save([changed])
let renamed = try store.load(); precondition(renamed.first?.name == "Kyrie")
for invalid in [-1.0, Double.infinity, Double.nan] {
    var bad = changed; bad.duration = invalid
    do { try store.save([bad]); fatalError("Invalid duration accepted") } catch {}
    let unchanged = try store.load(); precondition(unchanged == [changed])
}
do { try store.save([item, item]); fatalError("Duplicate IDs accepted") } catch {}
try Data("corrupt".utf8).write(to: store.index)
do { _ = try store.load(); fatalError("Corruption was accepted") } catch {}
print("PASS: recording metadata round-trips, rename preserves ID, filenames are safe, invalid writes preserve data, corruption detected")

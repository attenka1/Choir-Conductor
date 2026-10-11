import SwiftUI

struct ChordLibraryView: View {
    @ObservedObject var model: ConductorModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var renaming: SavedChord?
    @State private var renamed = ""
    @State private var deleting: SavedChord?

    private var canSave: Bool {
        model.soundMode == .piano && !model.sounding.isEmpty &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80
    }
    var body: some View {
        NavigationStack {
            List {
                Section(T("Aloitussoinnut")) {
                    if model.savedChords.isEmpty {
                        Text(T("Tallenna usein käyttämäsi aloitussoinnut. Soita koko sointu napauttamalla sen nimeä.")).foregroundStyle(.secondary)
                    }
                    ForEach(model.savedChords) { chord in
                        HStack {
                            Button {
                                if model.playChord(chord) { dismiss() }
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Label(chord.name, systemImage: "play.circle.fill").font(.headline)
                                    Text(chord.notes.map(model.noteLabel).joined(separator: " · ")).font(.subheadline)
                                    Text("\(chord.temperament.title) · \(model.rootNames[chord.root]) · A4 \(chord.tuning.formatted(.number.precision(.fractionLength(0...2)))) Hz").font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, minHeight: 60, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Menu {
                                Button(T("Nimeä uudelleen")) { renamed = chord.name; renaming = chord }
                                Button(T("Poista"), role: .destructive) { deleting = chord }
                            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel(T("Muokkaa sointua %@", chord.name))
                        }
                    }
                }
                Section(T("Tallenna uusi sointu")) {
                    Button(T("Valitse sävelet koskettimistolla")) {
                        model.prepareChordSelection()
                        dismiss()
                    }
                    Text(T("Pito kytkeytyy päälle. Valitse sävelet yksi kerrallaan tai soita usealla sormella, ja avaa sitten Soinnut uudelleen.")).font(.caption).foregroundStyle(.secondary)
                    if model.soundMode == .piano && !model.sounding.isEmpty {
                        Text(model.sounding.sorted().map(model.noteLabel).joined(separator: " · "))
                        TextField(T("Soinnun nimi"), text: $name)
                        Button(T("Tallenna soivat sävelet")) {
                            if model.saveCurrentChord(name: name) { name = "" }
                        }.disabled(!canSave)
                    }
                    Text(T("Sointu tallentaa sävelet, viritysjärjestelmän, pohjasävelen, A4-tason ja asteikon. Toisto palauttaa nämä asetukset ja soittaa pianolla Pidon kanssa. Metronomi jatkaa. Hiljennä kaikki pysäyttää soinnun.")).font(.caption).foregroundStyle(.secondary)
                }
                if !model.sounding.isEmpty { Button(T("Hiljennä kaikki")) { model.silencePiano() } }
            }
            .navigationTitle(T("Soinnut"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(T("Valmis")) { dismiss() } } }
            .alert(T("Nimeä sointu"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField(T("Nimi"), text: $renamed)
                Button(T("Tallenna")) { if let chord = renaming { model.renameChord(chord, to: renamed) } }
                    .disabled(renamed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || renamed.count > 80)
                Button(T("Peruuta"), role: .cancel) { renaming = nil }
            }
            .confirmationDialog(T("Poistetaanko sointu?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button(T("Poista sointu"), role: .destructive) { if let chord = deleting { model.deleteChord(chord) } }
                Button(T("Peruuta"), role: .cancel) { deleting = nil }
            }
        }
    }
}

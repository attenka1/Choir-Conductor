import SwiftUI

struct RecordingView: View {
    @ObservedObject var manager: RecordingManager
    let a4: Double
    @Environment(\.dismiss) private var dismiss
    @State private var renaming: RehearsalRecording?
    @State private var name = ""
    @State private var analyzing: RehearsalRecording?
    @State private var deleting: RehearsalRecording?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(Duration.seconds(manager.elapsed).formatted(.time(pattern: .minuteSecond))).font(.system(size: 44, weight: .semibold, design: .rounded)).monospacedDigit().frame(maxWidth: .infinity)
                    Button {
                        if manager.recording { manager.stop() } else { Task { await manager.start() } }
                    } label: {
                        Label(T(manager.recording ? "Lopeta äänitys" : "Aloita äänitys"), systemImage: manager.recording ? "stop.circle.fill" : "record.circle")
                            .font(.title3.bold()).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 52)
                    }.buttonStyle(.borderedProminent).tint(.red).disabled(manager.loading || manager.requestingPermission)
                    Text(analysisText("Yhden tallenteen enimmäiskesto on 2 tuntia. Bluetooth-kuulokkeilla käytetään iPhonen mikrofonia, jotta toisto säilyy laadukkaana."))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(T("Äänitys käyttää mikrofonia. Tallenteet säilyvät tässä iPhonessa. Taustalle siirtyminen lopettaa ja tallentaa äänityksen.")).font(.caption).foregroundStyle(.secondary)
                }
                Section(T("Tallenteet")) {
                    if manager.loading { ProgressView() }
                    if !manager.loading && manager.recordings.isEmpty { Text(T("Ei tallenteita vielä.")).foregroundStyle(.secondary) }
                    ForEach(manager.recordings) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name).font(.headline)
                            HStack {
                                Text(item.date, format: .dateTime.day().month().year().hour().minute())
                                Spacer()
                                Text(Duration.seconds(item.duration).formatted(.time(pattern: .minuteSecond)))
                            }.font(.caption).foregroundStyle(.secondary)
                            Button {
                                manager.stopPlayback()
                                analyzing = item
                            } label: {
                                Label(analysisText("Analysoi säveltaso"), systemImage: "chart.xyaxis.line")
                            }
                            .buttonStyle(.borderless)
                            .disabled(manager.recording || manager.requestingPermission)
                            HStack {
                                Button { manager.togglePlayback(item) } label: { Label(T(manager.playing == item.id ? "Pysäytä" : "Kuuntele"), systemImage: manager.playing == item.id ? "stop.fill" : "play.fill") }.disabled(manager.recording || manager.requestingPermission)
                                Spacer()
                                ShareLink(item: manager.url(item)) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }.accessibilityLabel(T("Jaa"))
                                Menu {
                                    Button(T("Nimeä uudelleen")) { name = item.name; renaming = item }
                                    Button(T("Poista"), role: .destructive) { deleting = item }
                                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel(T("Muokkaa"))
                            }.buttonStyle(.borderless)
                        }
                    }
                }
            }.navigationTitle(T("Äänitys"))
                .sheet(item: $analyzing) { item in
                    RecordingAnalysisView(manager: manager, item: item, a4: a4)
                }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(T("Valmis")) { dismiss() } } }
                .alert(T("Nimeä uudelleen"), isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                    TextField(T("Nimi"), text: $name)
                    Button(T("Tallenna")) { if let item = renaming { manager.rename(item, to: name) } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 100)
                    Button(T("Peruuta"), role: .cancel) { renaming = nil }
                }
                .confirmationDialog(T("Poistetaanko tallenne?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button(T("Poista"), role: .destructive) { if let item = deleting { manager.delete(item) } }
                    Button(T("Peruuta"), role: .cancel) { deleting = nil }
                }
                .alert(T("Toiminto ei onnistunut"), isPresented: Binding(get: { manager.error != nil }, set: { if !$0 { manager.error = nil } })) {
                    Button(T("OK")) { manager.error = nil }
                } message: { Text(manager.error ?? "") }
        }
    }
}

struct MeterSelection: Identifiable {
    let numerator: Bool
    var id: Bool { numerator }
}
struct MeterSelectionView: View {
    @ObservedObject var model: ConductorModel
    let selection: MeterSelection
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(selection.numerator ? Array(1...16) : [1, 2, 4, 8, 16], id: \.self) { value in
                Button {
                    if selection.numerator { model.meter = value } else { model.denominator = value }
                    dismiss()
                } label: {
                    HStack {
                        Text("\(value)").font(.title2.monospacedDigit())
                        Spacer()
                        if value == (selection.numerator ? model.meter : model.denominator) { Image(systemName: "checkmark") }
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }.navigationTitle(T(selection.numerator ? "Osoittaja" : "Nimittäjä"))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(T("Valmis")) { dismiss() } } }
        }
    }
}

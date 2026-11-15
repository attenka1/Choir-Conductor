import SwiftUI

struct TunerView: View {
    @ObservedObject var tuner: LiveTuner
    let a4: Double
    let international: Bool
    let temperament: Temperament
    let root: Int
    let divisions: Int
    let playReference: (Double) -> Void
    let stopReference: () -> Void
    let prepare: @MainActor () -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var startRequest: UUID?
    @State private var referenceEnabled = false
    @State private var referenceNote = 69.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("A4 = \(a4.formatted(.number.precision(.fractionLength(0...2)))) Hz · \(temperament.title) · \(divisions)")
                        .foregroundStyle(.secondary)
                    if temperament != .equal {
                        Text(T("Pohjasävel") + ": " + NoteNaming.pitchClasses(international: international)[root])
                            .foregroundStyle(.secondary)
                    }
                    if let pitch = tuner.pitch {
                        let note = pitch.target(a4: a4, temperament: temperament, root: root, divisions: divisions)
                        Text(NoteNaming.label(note.note, names: NoteNaming.pitchClasses(international: international, temperament: temperament, root: root)))
                            .font(.largeTitle.bold())
                        Text("\(pitch.hz.formatted(.number.precision(.fractionLength(1)))) Hz")
                            .monospacedDigit()
                        Text(tunerText("%@ senttiä", (note.cents >= 0 ? "+" : "") + note.cents.formatted(.number.precision(.fractionLength(1)))))
                            .monospacedDigit()
                        centsScale(note.cents)
                    } else {
                        Text(tunerText(tuner.active ? "Laula tai soita yksi sävel." : "Viritysmittari kuuntelee yhtä säveltä kerrallaan."))
                            .multilineTextAlignment(.center)
                    }
                    if tuner.active {
                        Picker(tunerText("Vertailusävel"), selection: $referenceNote) {
                            ForEach(0...(divisions == 24 ? 72 : 36), id: \.self) { index in
                                let note = 48.0 + Double(index) * (divisions == 24 ? 0.5 : 1)
                                Text(NoteNaming.label(note, names: NoteNaming.pitchClasses(international: international, temperament: temperament, root: root))).tag(note)
                            }
                        }
                        Toggle(tunerText("Soita vertailuääni"), isOn: $referenceEnabled)
                        Text(tunerText("Käytä kuulokkeita: kaiuttimen vertailuääni voi näkyä mittauksessa oman äänesi sijaan."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let inputName = tuner.inputName {
                        Label(inputName, systemImage: "mic").font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = tuner.error {
                        Text(error).foregroundStyle(.red)
                    }
                    Button(tuner.active ? tunerText("Lopeta kuuntelu") : tunerText("Aloita kuuntelu")) {
                        if tuner.active { startRequest = nil; tuner.stop() }
                        else { startRequest = UUID() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle(tunerText("Viritysmittari"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T("Valmis")) { startRequest = nil; tuner.stop(); dismiss() }
                }
            }
        }
        .task(id: startRequest) {
            if startRequest != nil { await tuner.start(prepare: prepare) }
        }
        .onChange(of: referenceEnabled) { _, enabled in
            if enabled { playReference(referenceNote) } else { stopReference() }
        }
        .onChange(of: referenceNote) { _, note in
            if referenceEnabled { playReference(note) }
        }
        .onChange(of: tuner.active) { _, active in
            if !active { referenceEnabled = false; stopReference() }
        }
        .onDisappear { stopReference(); tuner.stop() }
    }

    private func centsScale(_ cents: Double) -> some View {
        VStack {
            GeometryReader { geometry in
                let width = geometry.size.width
                let limit = divisions == 24 ? 25.0 : 50.0
                let fraction = min(1, max(0, (cents + limit) / (2 * limit)))
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.25)).frame(height: 4)
                    Rectangle().fill(.secondary).frame(width: 2, height: 16).offset(x: (width - 2) / 2)
                    Circle().fill(.teal).frame(width: 14, height: 14).offset(x: (width - 14) * fraction)
                }
            }
            .frame(height: 18)
            HStack {
                Text(divisions == 24 ? "−25" : "−50")
                Spacer()
                Text("0")
                Spacer()
                Text(divisions == 24 ? "+25" : "+50")
            }
            .font(.caption)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}

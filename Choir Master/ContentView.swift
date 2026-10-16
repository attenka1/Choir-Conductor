import SwiftUI

struct ContentView: View {
    @StateObject private var model = ConductorModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var editingTempo = false
    @State private var tempoText = ""
    @State private var settings = false
    @State private var chords = false
    @State private var recordingPanel = false
    @State private var meterSelection: MeterSelection?
    @AppStorage("appLanguage") private var appLanguage = "fi"
    @State private var customTuningVisible = false
    @State private var customTuningText = ""
    @FocusState private var tempoFocused: Bool
    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let compact = geometry.size.height < 700
            VStack(spacing: compact ? 8 : 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choir Master").font(.title2.bold())
                        if !landscape && !compact { Text(T("Kuoroharjoituksen työkalut")).font(.subheadline).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    RecordingButton(manager: model.recordings) { recordingPanel = true }
                    Button { settings = true } label: { Image(systemName: "gearshape").font(.title2).frame(width: 44, height: 44) }.accessibilityLabel(T("Asetukset"))
                }
                if landscape {
                    HStack(alignment: .top, spacing: 20) {
                        ScrollView { metronome(compact: true) }.frame(width: geometry.size.width * 0.36)
                        VStack(spacing: 8) { pianoControls(compact: true); PianoKeyboard(model: model).environment(\.layoutDirection, .leftToRight); volume(T("Äänenanto"), value: $model.pianoVolume) }
                    }
                } else {
                    ScrollView { VStack(spacing: 12) { metronome(compact: compact, includeStart: false); if !compact { volume(T("Metronomi"), value: $model.clickVolume) } } }
                    startButton(compact: true)
                    pianoControls(compact: compact)
                    PianoKeyboard(model: model).environment(\.layoutDirection, .leftToRight).frame(height: min(compact ? 140 : 210, geometry.size.height * 0.28))
                    if !compact { volume(T("Äänenanto"), value: $model.pianoVolume) }
                }
            }
            .padding(compact ? 12 : 16)
            .background(Color(red: 0.95, green: 0.97, blue: 0.97))
        }
        .id(appLanguage)
        .tint(.teal)
        .preferredColorScheme(.light)
        .sheet(isPresented: $editingTempo) { localized(tempoEditor) }
        .sheet(isPresented: $settings) { localized(settingsView) }
        .sheet(isPresented: $chords) { localized(ChordLibraryView(model: model)) }
        .sheet(isPresented: $recordingPanel) { localized(RecordingView(manager: model.recordings)) }
        .sheet(item: $meterSelection) { localized(MeterSelectionView(model: model, selection: $0)) }
        .environment(\.locale, Locale(identifier: appLanguage))
        .environment(\.layoutDirection, AppLanguage.isRTL(appLanguage) ? .rightToLeft : .leftToRight)
        .alert(T("Toiminto ei onnistunut"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button(T("OK")) { model.error = nil } } message: { Text(model.error ?? "") }
        .onChange(of: scenePhase) { _, phase in if phase == .background { model.stopAll() } }
    }
    private func localized<V: View>(_ view: V) -> some View {
        view.id(appLanguage)
            .environment(\.locale, Locale(identifier: appLanguage))
            .environment(\.layoutDirection, AppLanguage.isRTL(appLanguage) ? .rightToLeft : .leftToRight)
    }
    private func metronome(compact: Bool, includeStart: Bool = true) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            HStack {
                Text(T("Metronomi")).font(.headline)
                Spacer()
                Text(model.beatUnit).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 18) {
                TempoArrow(symbol: "chevron.down", label: T("Pienennä tempoa")) { model.setTempo(model.tempo - 1) }
                Button { tempoText = String(model.tempo); editingTempo = true } label: {
                    VStack(spacing: 0) { Text("\(model.tempo)").font(.system(size: compact ? 44 : 56, weight: .semibold, design: .rounded)).monospacedDigit(); Text(T("BPM · muokkaa")).font(.caption) }.frame(maxWidth: .infinity)
                }.accessibilityLabel(T("Tempo %@ BPM, muokkaa", String(model.tempo)))
                TempoArrow(symbol: "chevron.up", label: T("Suurenna tempoa")) { model.setTempo(model.tempo + 1) }
            }
            HStack(spacing: 8) {
                Text(T("Tahtilaji")).font(.subheadline)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                Button { meterSelection = MeterSelection(numerator: true) } label: {
                    Text("\(model.meter)").font(.title2.monospacedDigit()).frame(minWidth: 52, minHeight: 44)
                        .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }.accessibilityLabel(T("Osoittaja"))
                Text("/").font(.title2).foregroundStyle(.secondary)
                Button { meterSelection = MeterSelection(numerator: false) } label: {
                    Text("\(model.denominator)").font(.title2.monospacedDigit()).frame(minWidth: 52, minHeight: 44)
                        .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }.accessibilityLabel(T("Nimittäjä"))
                }.environment(\.layoutDirection, .leftToRight)
            }
            if model.isSixEight {
                Picker(T("6/8-iskut"), selection: $model.compound) { Text("2 × ♩.").tag(true); Text("6 × ♪").tag(false) }.pickerStyle(.segmented)
            }
            if !includeStart {
                beatIndicators(compact: compact)
            } else if compact && model.beatCount <= 4 {
                HStack { beatIndicators(compact: true); Spacer(minLength: 4); startButton(compact: true) }
            } else {
                beatIndicators(compact: false)
                startButton(compact: false)
            }
        }.padding(compact ? 10 : 14).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
    private func beatIndicators(compact: Bool) -> some View {
        let columns = min(model.beatCount, 8)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 6) {
            ForEach(0..<model.beatCount, id: \.self) { index in
                Text("\(index + 1)").font(compact ? .caption.bold() : .headline).frame(width: compact ? 22 : 32, height: compact ? 22 : 32)
                    .background(model.running && model.beat == index ? Color.teal : Color.gray.opacity(0.1), in: Circle())
                    .foregroundStyle(model.running && model.beat == index ? .white : .primary)
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel(model.running ? T("Isku %@ / %@", String(model.beat + 1), String(model.beatCount)) : T("Metronomi pysäytetty"))
    }

    private func startButton(compact: Bool) -> some View {
        Button { model.toggleMetronome() } label: {
            Label(model.running ? T("Pysäytä") : T("Käynnistä"), systemImage: model.running ? "stop.fill" : "play.fill")
                .font(compact ? .subheadline.bold() : .title3.bold()).frame(maxWidth: .infinity).frame(height: compact ? 44 : 52)
        }.buttonStyle(.borderedProminent)
    }

    private func pianoControls(compact: Bool) -> some View {
        VStack(spacing: 8) {
            Picker(T("Äänenannon tila"), selection: $model.soundMode) {
                ForEach(SoundMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            HStack {
                Button { chords = true } label: { Label(T("Soinnut"), systemImage: "music.note.list").font(.subheadline.bold()).frame(minHeight: 44) }
                Spacer(minLength: 4)
                Text(model.tuningSummary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if compact { Spacer() }
            }
            HStack(spacing: compact ? 4 : 8) {
                Button { model.octave = max(2, model.octave - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.disabled(model.octave == 2).accessibilityLabel(T("Oktaavi alas"))
                Text("C\(model.octave)–C\(model.octave + 2)").font(compact ? .caption.monospacedDigit() : .subheadline.monospacedDigit()).lineLimit(1)
                Button { model.octave = min(4, model.octave + 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(model.octave == 4).accessibilityLabel(T("Oktaavi ylös"))
                Spacer(minLength: 0)
                if model.soundMode == .piano { Button { model.sustain.toggle() } label: { Text(T("Pito")).bold().frame(width: compact ? 44 : 64, height: 44).background(model.sustain ? Color.teal : Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(model.sustain ? .white : .primary) }.buttonStyle(.plain).accessibilityValue(model.sustain ? T("Päällä") : T("Pois")) }
                Button { model.silencePiano() } label: { Text(T("Hiljennä kaikki")).font(.caption.bold()).multilineTextAlignment(.center).frame(width: compact ? 78 : 100, height: 44).background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain)
            }
        }
    }
    private func volume(_ title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 10) { Text(T(title)).font(.caption).frame(width: 76, alignment: .leading); Image(systemName: "speaker.fill").accessibilityHidden(true); Slider(value: value, in: 0...1).accessibilityLabel(T("%@ äänenvoimakkuus", T(title))); Image(systemName: "speaker.wave.2.fill").accessibilityHidden(true) }
    }
    private var tempoEditor: some View {
        NavigationStack {
            Form {
                TextField(T("Tempo 30–240"), text: $tempoText).keyboardType(.numberPad).focused($tempoFocused).font(.largeTitle).onSubmit { commitTempo() }
                Text(T("Sallittu alue on 30–240 BPM.")).foregroundStyle(.secondary)
            }.navigationTitle(T("Muuta tempoa"))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(T("Valmis")) { commitTempo() }.disabled(Int(tempoText) == nil) }; ToolbarItem(placement: .cancellationAction) { Button(T("Peruuta")) { editingTempo = false } } }
                .onAppear { tempoFocused = true }
        }.presentationDetents([.medium])
    }
    private func commitTempo() { if let value = Int(tempoText) { model.setTempo(value); editingTempo = false } }
    private var settingsView: some View {
        NavigationStack {
            Form {
                Section(T("Kieli")) {
                    Picker(T("Käyttöliittymän kieli"), selection: $appLanguage) {
                        ForEach(AppLanguage.all) { Text($0.name).tag($0.id) }
                    }.pickerStyle(.navigationLink)
                }
                Section(T("Viritys")) {
                    Picker("A4", selection: Binding<Double>(
                        get: { [415.0, 440.0, 442.0].contains(model.tuning) ? model.tuning : 0 },
                        set: { value in
                            if value == 0 { customTuningText = model.tuningLabel; customTuningVisible = true }
                            else { model.tuning = value }
                        }
                    )) {
                        Text("415 Hz").tag(415.0)
                        Text("440 Hz").tag(440.0)
                        Text("442 Hz").tag(442.0)
                        Text([415.0, 440.0, 442.0].contains(model.tuning) ? T("Oma arvo…") : T("Oma: %@ Hz", model.tuningLabel)).tag(0.0)
                    }.pickerStyle(.navigationLink)
                    Button(T("Syötä oma viritystaso")) { customTuningText = model.tuningLabel; customTuningVisible = true }
                    Picker(T("Viritysjärjestelmä"), selection: $model.temperament) {
                        ForEach(Temperament.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.navigationLink)
                    if model.temperament != .equal {
                        Picker(T("Pohjasävel"), selection: $model.tuningRoot) {
                            ForEach(0..<12, id: \.self) { Text(model.rootNames[$0]).tag($0) }
                        }.pickerStyle(.navigationLink)
                        Text(model.temperament.explanation)
                        Text(model.temperament == .just ? T("A4 säilyy valitussa taajuudessa. Pohjasävel määrää puhtaiden suhteiden lähtösävelen.") : T("A4 säilyy valitussa taajuudessa. C-pohja vastaa historiallisen järjestelmän tavanomaista sijoitusta; muu pohjasävel siirtää koko virityskaavion.")).font(.caption).foregroundStyle(.secondary)
                        if model.temperament.usesOpenChain {
                            Text(T("Enharmoniset sävelet eroavat. C-pohjalla mustat koskettimet ovat Cis, Es, Fis, Gis ja B. Susikvintti on Gis–Es.")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Picker(T("Tasavireinen asteikko"), selection: $model.divisions) {
                        Text(T("12 säveltä / oktaavi")).tag(12)
                        Text(T("24 säveltä / oktaavi")).tag(24)
                    }.pickerStyle(.navigationLink)
                    Text(T("24 sävelen asteikko käyttää tasavireistä viritystä. Sen valitseminen vaihtaa viritysjärjestelmän tasavireiseksi; muun viritysjärjestelmän valitseminen palauttaa 12 kosketinta oktaaviin.")).font(.caption).foregroundStyle(.secondary)
                    if model.divisions == 24 {
                        Text(T("Koskettimen vasen puoli soittaa nimetyn sävelen. Oikea, ↑-merkitty puoli soi 50 senttiä korkeammalta. Molemmat puolikkaat ovat erillisiä koskettimia."))
                    }
                }
                Section(T("Sävelnimet")) { Picker(T("Nimistö"), selection: $model.international) { Text(T("Suomalainen H / B")).tag(false); Text(T("Kansainvälinen B / B♭")).tag(true) } }
                Section(T("Äänenvoimakkuudet")) { volume(T("Metronomi"), value: $model.clickVolume); volume(T("Äänenanto"), value: $model.pianoVolume) }
                Section(T("Viritysääni")) {
                    Picker(T("Ääni"), selection: $model.referenceSound) {
                        ForEach(ReferenceSound.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.navigationLink)
                    Text(T("Tarkka viritysääni tuotetaan suoraan valittuun taajuuteen. SoundFont-urut käyttävät GeneralUser GS:n näytteitä, joiden korkeus voi hieman huojua. Käytä tarkkaa ääntä soittimen virittämiseen."))
                    Text(T("Napauta kosketinta: sävel jää soimaan. Seuraava kosketin vaihtaa sävelen. Hiljennä kaikki lopettaa äänen."))
                }
                Section(T("Pianokoskettimisto")) { Text(T("Paina useita koskettimia soittaaksesi soinnun. Pito jättää sävelet soimaan; paina samaa kosketinta uudelleen sammuttaaksesi sen. Keskimmäinen C on C4.")); Text(T("Siirrä koskettimistoa vetämällä sivusuunnassa. Oktaavinuolet vaihtavat soitettavaa aluetta. Käännä puhelin vaakaan saadaksesi lisää tilaa.")) }
                if AdsConsent.shared.privacyOptionsRequired {
                    Section {
                        Button(T("Mainosten tietosuoja-asetukset")) {
                            Task { await AdsConsent.shared.showPrivacyOptions() }
                        }
                    }
                }
                Section(T("Tietoa sovelluksesta")) {
                    LabeledContent(T("Versio"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.1")
                    LabeledContent(T("Build"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "2")
                }
            }
            .safeAreaInset(edge: .bottom) { SettingsBanner() }
            .navigationTitle(T("Asetukset")).toolbar { ToolbarItem(placement: .confirmationAction) { Button(T("Valmis")) { settings = false } } }
        }
        .alert(T("Oma viritystaso"), isPresented: $customTuningVisible) {
            TextField(T("A4 hertseinä"), text: $customTuningText).keyboardType(.decimalPad)
            Button(T("Valmis")) { if let value = parsedCustomTuning { model.tuning = value } }.disabled(parsedCustomTuning == nil)
            Button(T("Peruuta"), role: .cancel) { }
        } message: { Text(T("Anna A4:n taajuus väliltä 300–500 Hz. Voit käyttää desimaaleja.")) }
    }
    private var parsedCustomTuning: Double? {
        guard let value = Double(customTuningText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")), value.isFinite, (300...500).contains(value) else { return nil }
        return value
    }
}

private struct TempoArrow: View {
    let symbol: String
    let label: String
    let change: () -> Void
    @State private var task: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Image(systemName: symbol).font(.title2.bold()).frame(width: 48, height: 56)
            .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in
                guard task == nil else { return }
                change()
                task = Task { @MainActor in
                    do {
                        try await Task.sleep(for: .milliseconds(400))
                        while !Task.isCancelled { change(); try await Task.sleep(for: .milliseconds(85)) }
                    } catch { }
                }
            }.onEnded { _ in task?.cancel(); task = nil })
            .onDisappear { task?.cancel(); task = nil }
            .onChange(of: scenePhase) { _, phase in if phase != .active { task?.cancel(); task = nil } }
            .accessibilityLabel(T(label)).accessibilityAddTraits(.isButton).accessibilityAction { change() }
    }
}

private struct RecordingButton: View {
    @ObservedObject var manager: RecordingManager
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: manager.recording ? "record.circle.fill" : "mic")
                .font(.title2).frame(width: 44, height: 44).foregroundStyle(manager.recording ? Color.red : Color.teal)
        }.accessibilityLabel(manager.recording ? T("Äänitys käynnissä") : T("Äänitys"))
    }
}

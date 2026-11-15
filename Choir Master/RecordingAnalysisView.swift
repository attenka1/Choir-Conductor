import Charts
import SwiftUI
import Combine

@MainActor final class RecordingAnalysisModel: ObservableObject {
    @Published private(set) var result: RecordingAnalysisResult?
    @Published private(set) var progress = 0.0
    @Published private(set) var error: String?
    private var requestID = UUID()
    private var worker: Task<RecordingAnalysisResult, Error>?

    func load(source: URL, a4: Double) async {
        worker?.cancel()
        requestID = UUID()
        let request = requestID
        result = nil
        progress = 0
        error = nil
        let worker = Task.detached(priority: .utility) {
            var reported = -1
            return try RecordingAnalysisStore(source: source).resolve(a4: a4) { [weak self] fraction in
                let percent = Int(fraction * 100)
                guard percent != reported else { return }
                reported = percent
                Task { @MainActor [weak self] in
                    guard let self, self.requestID == request else { return }
                    self.progress = fraction
                }
            }
        }
        self.worker = worker
        defer { if requestID == request { self.worker = nil } }
        do {
            let result = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: {
                worker.cancel()
            }
            try Task.checkCancellation()
            guard requestID == request else { return }
            self.result = result
        } catch is CancellationError {
            return
        } catch {
            guard requestID == request else { return }
            self.error = error.localizedDescription
        }
    }

    nonisolated deinit {}

    func cancel() {
        requestID = UUID()
        worker?.cancel()
    }
}

struct RecordingAnalysisView: View {
    @ObservedObject var manager: RecordingManager
    let item: RehearsalRecording
    let a4: Double
    @StateObject private var model = RecordingAnalysisModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var position = 0.0
    @State private var dragging = false
    @State private var attempt = 0
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if let result = model.result {
                    chart(result)
                        .frame(minHeight: 140, maxHeight: .infinity)
                    Slider(value: $position, in: 0...max(1, result.duration)) { editing in
                        dragging = editing
                        if !editing { manager.seekPlayback(item, to: position) }
                    }
                    .accessibilityLabel(analysisText("Kuuntelukohta"))
                    HStack {
                        Text(Duration.seconds(position).formatted(.time(pattern: .minuteSecond)))
                        Spacer()
                        Text(Duration.seconds(result.duration).formatted(.time(pattern: .minuteSecond)))
                    }
                    .font(.caption.monospacedDigit())
                    Button {
                        if manager.playing == item.id { manager.stopPlayback() }
                        else { manager.playRecording(item, at: position) }
                    } label: {
                        Label(T(manager.playing == item.id ? "Pysäytä" : "Kuuntele"),
                              systemImage: manager.playing == item.id ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manager.recording || manager.requestingPermission)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(analysisText("Havaintojen kattavuus %@ %% · jaksoja %@",
                                String(Int((result.coverage * 100).rounded())), String(result.segments)))
                            if result.total == 0 {
                                Text(analysisText("Analyysi tarvitsee vähintään 15 sekunnin tallenteen."))
                            } else if result.valid == 0 {
                                Text(analysisText("Tallenteesta ei löytynyt riittävän yhtenäistä säveltasoa."))
                            }
                            Text(analysisText("Käyrä yhdistää kaikki tallenteen äänet. Se ei erottele stemmoja eikä mittaa luonnonvireisen soinnun puhtautta. 100 sentin taitto ja tasoitus voivat peittää nopean tai suuren muutoksen."))
                            Text(analysisText("Vertailu A4 = %@ Hz, tasavireinen asteikko.",
                                a4.formatted(.number.precision(.fractionLength(0...2)))))
                            Text(analysisText("Kokeellinen arvio yhteisestä säveltasosta. Säveltasossa on 100 sentin monitulkintaisuus. Käyrä käyttää 15 sekunnin jaksoja ja kahden sekunnin askelta, ja muutos rajataan 12 senttiin pistettä kohti. Epävarmat kohdat näkyvät aukkoina."))
                            Text(analysisText("Tallenteiden piano- ja metronomiäänten ajankohtia ei ole kirjattu. Kaiuttimesta tallentuneet harjoitteluäänet voivat vaikuttaa tulokseen."))
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                } else if let error = model.error {
                    Text(error).foregroundStyle(.red)
                    Button(analysisText("Yritä uudelleen")) { attempt += 1 }
                } else {
                    ProgressView(value: model.progress) {
                        Text(analysisText("Analysoidaan säveltasoa…"))
                    }
                    Text("\(Int(model.progress * 100)) %").monospacedDigit()
                    Spacer()
                }
            }
            .padding()
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(T(model.result == nil ? "Peruuta" : "Valmis")) {
                        model.cancel()
                        manager.stopPlayback()
                        dismiss()
                    }
                }
            }
            .task(id: attempt) { await model.load(source: manager.url(item), a4: a4) }
            .onReceive(timer) { _ in
                if !dragging, manager.playing == item.id { position = manager.playbackPosition }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { model.cancel(); manager.stopPlayback(); dismiss() }
            }
            .onDisappear { model.cancel(); manager.stopPlayback() }
            .alert(T("Toiminto ei onnistunut"),
                   isPresented: Binding(get: { manager.error != nil }, set: { if !$0 { manager.error = nil } })) {
                Button(T("OK")) { manager.error = nil }
            } message: { Text(manager.error ?? "") }
        }
    }

    private func chart(_ result: RecordingAnalysisResult) -> some View {
        // Give each uninterrupted run its own series so Charts never bridges a missing observation.
        let runs = chartPoints(result.points)
        let values = result.points.compactMap(\.cents)
        let low = min(-250, floor((values.min() ?? 0) / 50) * 50)
        let high = max(50, ceil((values.max() ?? 0) / 50) * 50)
        return Chart {
            RuleMark(y: .value("0", 0)).foregroundStyle(.secondary)
            ForEach(runs, id: \.point.frame) { entry in
                if let cents = entry.point.cents {
                    LineMark(x: .value(analysisText("Aika (s)"), Double(entry.point.frame) / Double(result.rate)),
                             y: .value(analysisText("Senttiä"), cents),
                             series: .value("Run", entry.run))
                    .foregroundStyle(.teal)
                    PointMark(x: .value(analysisText("Aika (s)"), Double(entry.point.frame) / Double(result.rate)),
                              y: .value(analysisText("Senttiä"), cents))
                    .foregroundStyle(.teal).symbolSize(8)
                }
            }
            RuleMark(x: .value(analysisText("Kuuntelukohta"), position)).foregroundStyle(.orange)
        }
        .chartXScale(domain: 0...max(1, result.duration))
        .chartYScale(domain: low...high)
        .chartYAxisLabel(analysisText("Senttiä"))
        .chartXAxisLabel(analysisText("Aika (s)"))
        .environment(\.layoutDirection, .leftToRight)
    }

    private func chartPoints(_ points: [RecordingAnalysisPoint]) -> [(point: RecordingAnalysisPoint, run: Int)] {
        var run = 0
        var previous: RecordingAnalysisPoint?
        return points.map { point in
            if previous?.cents == nil || previous?.segment != point.segment { run += 1 }
            previous = point
            return (point, run)
        }
    }
}

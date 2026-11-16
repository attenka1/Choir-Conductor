import AVFoundation
import Foundation
let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let metadata = try PianoSampleMetadata.load(from:folder.appendingPathComponent("metadata.json"))
var samples:[[Float]] = []
for item in metadata {
    let file = try AVAudioFile(forReading:folder.appendingPathComponent(item.filename))
    let buffer = AVAudioPCMBuffer(pcmFormat:file.processingFormat, frameCapacity:AVAudioFrameCount(file.length))!
    try file.read(into:buffer)
    samples.append((0..<Int(buffer.frameLength)).map { (buffer.floatChannelData![0][$0] + buffer.floatChannelData![1][$0]) / 2 })
}
func configured(_ bpm:Double, click:Float) -> AudioRenderer {
    let renderer = AudioRenderer()
    renderer.samples = samples
    for (index,item) in metadata.enumerated() {
        renderer.loopEnds[index] = Double(item.loopEndFrame)
        renderer.loopLengths[index] = item.loopLengthFrames
        renderer.crossfades[index] = Double(item.crossfadeFrames)
    }
    let notes = (0..<97).map { Double($0) / 2 + 36 }
    let steps = notes.map { note -> Double in
        let source = min(79,max(55,Int(note.rounded())))
        return 442 * pow(2,(note-69)/12) / metadata[source-55].fundamentalHz
    }
    renderer.configure(tempo:bpm,beats:4,piano:0.7,click:click,pitches:steps)
    renderer.startNotes(notes)
    renderer.setMetronome(running:true,reset:true)
    return renderer
}
let format = AVAudioFormat(standardFormatWithSampleRate:44100,channels:2)!
let mixed = AVAudioPCMBuffer(pcmFormat:format,frameCapacity:512)!
let piano = AVAudioPCMBuffer(pcmFormat:format,frameCapacity:512)!
for bpm in [30.0,240.0] {
    let withClick = configured(bpm,click:0.6)
    let withoutClick = configured(bpm,click:0)
    var quiet = 1000
    var onsets:[Int] = []
    var offset = 0
    while offset < 44100 * 12 {
        let count = min(512,44100 * 12 - offset)
        withClick.render(count,mixed.mutableAudioBufferList)
        withoutClick.render(count,piano.mutableAudioBufferList)
        for i in 0..<count {
            let a = Double(mixed.floatChannelData![0][i]), b = Double(piano.floatChannelData![0][i])
            precondition(a.isFinite && b.isFinite && abs(a) < 1 && abs(b) < 1)
            // Invert the known output limiter; subtract identical piano DSP to isolate the click.
            let click = atanh(a) - atanh(b)
            if abs(click) > 1e-5 {
                if quiet > 200 { onsets.append(offset + i - 1) }
                quiet = 0
            } else { quiet += 1 }
        }
        offset += count
    }
    precondition(onsets.count == Int(bpm / 5), "Mix onset count \(bpm): \(onsets)")
    for (n,onset) in onsets.enumerated() {
        precondition(abs(Double(onset)-Double(n)*44100*60/bpm) <= 1, "Mix onset timing")
    }
    print("PASS: metronome \(Int(bpm)) BPM and 97 held quarter-tone voices, 12s, onsets \(onsets.count)")
}
